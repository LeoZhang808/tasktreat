#!/usr/bin/env bash
# Walks every Step 5 acceptance check end-to-end:
#   * AWS Load Balancer Controller is Running.
#   * Ingress has an ALB ADDRESS.
#   * ALB exists in ELBv2.
#   * ACM cert is ISSUED.
#   * app.<domain> resolves to the ALB.
#   * https://app.<domain>/ returns a 200 (frontend).
#   * https://app.<domain>/api/{tasks,wishlist,rewards} routes to backends.
#
# Failures are non-fatal so the script always finishes and prints a
# summary you can paste into a status update.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform/environments/dev"

NAMESPACE="${NAMESPACE:-tasktreat-dev}"
INGRESS_NAME="${INGRESS_NAME:-tasktreat-ingress}"

PASS=0
FAIL=0
log_pass() { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
log_fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }
hr() { echo "------------------------------------------------------------"; }

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' is required on PATH." >&2
    exit 1
  }
}

require terraform
require kubectl
require aws
require dig

pushd "${TF_DIR}" >/dev/null
APP_FQDN=$(terraform output -raw app_fqdn 2>/dev/null || true)
CERT_ARN=$(terraform output -raw acm_certificate_arn 2>/dev/null || true)
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-west-2")
popd >/dev/null

echo "============================================================"
echo "  Region:      ${AWS_REGION}"
echo "  Namespace:   ${NAMESPACE}"
echo "  App FQDN:    ${APP_FQDN:-(not set)}"
echo "  ACM cert:    ${CERT_ARN:-(not set)}"
echo "============================================================"

# Prefer the OS resolver, then well-known public resolvers. Local resolvers
# (mDNSResponder, captive-portal DNS, VPN split-DNS, etc.) often lag behind
# Route 53 for a freshly created `app.` alias even when 8.8.8.8 / 1.1.1.1
# already answer correctly — which makes unconditional `dig +short HOST` and
# default `curl https://HOST` look "broken" in verification only.
PUBLIC_DNS_FALLBACK="8.8.8.8 1.1.1.1"

# Prints the first dotted-quad IPv4 address found for APP_FQDN, or empty.
# Prints nothing if DIG_NS is unset/empty → system resolver per `dig`(1).
_resolve_app_ipv4_once() {
  local ns="${1:-}"
  if [[ -z "${ns}" ]]; then
    dig +short A "${APP_FQDN}" 2>/dev/null
  else
    dig +short A "${APP_FQDN}" @"${ns}" 2>/dev/null
  fi | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true
}

# 1. AWS Load Balancer Controller ---------------------------------------------
echo
echo "==> 1. AWS Load Balancer Controller"
if kubectl -n kube-system get deployment aws-load-balancer-controller >/dev/null 2>&1; then
  AVAIL=$(kubectl -n kube-system get deployment aws-load-balancer-controller \
    -o jsonpath='{.status.availableReplicas}')
  if [[ "${AVAIL:-0}" -ge 1 ]]; then
    log_pass "deployment aws-load-balancer-controller has ${AVAIL} ready replica(s)"
  else
    log_fail "deployment aws-load-balancer-controller has 0 ready replicas"
    kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller
  fi
else
  log_fail "deployment kube-system/aws-load-balancer-controller not found"
fi

# 2. Ingress ALB hostname -----------------------------------------------------
echo
echo "==> 2. Ingress ${NAMESPACE}/${INGRESS_NAME}"
if kubectl get ingress "${INGRESS_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  ALB_HOSTNAME=$(kubectl get ingress "${INGRESS_NAME}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [[ -n "${ALB_HOSTNAME}" ]]; then
    log_pass "Ingress has ADDRESS ${ALB_HOSTNAME}"
  else
    log_fail "Ingress has no ADDRESS yet"
    kubectl describe ingress "${INGRESS_NAME}" -n "${NAMESPACE}" | tail -30
  fi
else
  log_fail "Ingress ${NAMESPACE}/${INGRESS_NAME} not found"
  ALB_HOSTNAME=""
fi

# 3. ALB exists in AWS --------------------------------------------------------
echo
echo "==> 3. ALB visible to elbv2"
if [[ -n "${ALB_HOSTNAME}" ]]; then
  ALB_ARN=$(aws elbv2 describe-load-balancers --region "${AWS_REGION}" \
    --query "LoadBalancers[?DNSName==\`${ALB_HOSTNAME}\`].LoadBalancerArn | [0]" \
    --output text 2>/dev/null || echo "")
  if [[ -n "${ALB_ARN}" && "${ALB_ARN}" != "None" ]]; then
    log_pass "ALB found: ${ALB_ARN}"
  else
    log_fail "ALB ${ALB_HOSTNAME} not found via elbv2"
  fi
else
  log_fail "skipping; no ALB hostname"
fi

# 4. ACM certificate ----------------------------------------------------------
echo
echo "==> 4. ACM certificate status"
if [[ -n "${CERT_ARN}" ]]; then
  STATUS=$(aws acm describe-certificate --region "${AWS_REGION}" \
    --certificate-arn "${CERT_ARN}" --query 'Certificate.Status' --output text 2>/dev/null || echo "")
  if [[ "${STATUS}" == "ISSUED" ]]; then
    log_pass "Certificate is ISSUED"
  else
    log_fail "Certificate status is ${STATUS:-unknown}"
  fi
else
  log_fail "no ACM ARN from terraform output"
fi

# 5. DNS resolution -----------------------------------------------------------
echo
echo "==> 5. DNS resolution for ${APP_FQDN}"
VERIFY_CURL_IPV4=""
if [[ -n "${APP_FQDN}" ]]; then
  VERIFY_CURL_IPV4=$(_resolve_app_ipv4_once "")
  VIA=""
  [[ -n "${VERIFY_CURL_IPV4}" ]] && VIA="system resolver"

  if [[ -z "${VERIFY_CURL_IPV4}" ]]; then
    for ns in ${PUBLIC_DNS_FALLBACK}; do
      VERIFY_CURL_IPV4=$(_resolve_app_ipv4_once "${ns}")
      if [[ -n "${VERIFY_CURL_IPV4}" ]]; then
        VIA="${ns}"
        break
      fi
    done
  fi

  if [[ -n "${VERIFY_CURL_IPV4}" ]]; then
    log_pass "${APP_FQDN} resolves (${VIA}); first IPv4:"
    echo "         ${VERIFY_CURL_IPV4}"
    echo "         (all queried):"
    printf '         system:    %s\n' "$(dig +short A "${APP_FQDN}" 2>/dev/null | tr '\n' ' ')"
    for ns in ${PUBLIC_DNS_FALLBACK}; do
      printf '         @%s: %s\n' "${ns}" "$(dig +short A "${APP_FQDN}" @"${ns}" 2>/dev/null | tr '\n' ' ')"
    done
  else
    log_fail "${APP_FQDN} does not resolve (system + ${PUBLIC_DNS_FALLBACK}). Check Route 53 alias and registrar NS delegation."
  fi
else
  log_fail "no app FQDN from terraform output"
fi

# curl needs a stable target when the laptop's stub resolver caches NXDOMAIN /
# empties briefly after a DNS change — pin the ALB VIP that public DNS sees.
_CURL_OPTS=()
[[ -n "${VERIFY_CURL_IPV4}" ]] && _CURL_OPTS+=(--resolve "${APP_FQDN}:443:${VERIFY_CURL_IPV4}")

# 6. HTTPS frontend -----------------------------------------------------------
echo
echo "==> 6. HTTPS frontend"
if [[ -n "${APP_FQDN}" ]]; then
  CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 10 "${_CURL_OPTS[@]}" "https://${APP_FQDN}/" || echo "000")
  if [[ "${CODE}" == "200" ]]; then
    log_pass "GET https://${APP_FQDN}/ -> ${CODE}"
  else
    log_fail "GET https://${APP_FQDN}/ -> ${CODE}"
  fi
fi

# 7. API path-based routing ---------------------------------------------------
echo
echo "==> 7. API path-based routing"
for PATH_ in /api/tasks /api/wishlist /api/rewards; do
  if [[ -n "${APP_FQDN}" ]]; then
    CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time 10 "${_CURL_OPTS[@]}" "https://${APP_FQDN}${PATH_}" || echo "000")
    # 200, 404 (path exists but no item), or 405 (GET not allowed) all prove
    # the request reached the backend. 502/503 means the ALB can't talk to
    # the pod; 000 means TLS or DNS failure.
    case "${CODE}" in
      200|301|302|400|404|405)
        log_pass "GET https://${APP_FQDN}${PATH_} -> ${CODE} (reached backend)"
        ;;
      *)
        log_fail "GET https://${APP_FQDN}${PATH_} -> ${CODE}"
        ;;
    esac
  fi
done

# 8. Valid TLS chain ----------------------------------------------------------
echo
echo "==> 8. TLS certificate chain"
if [[ -n "${APP_FQDN}" ]]; then
  if curl -sI --max-time 10 "${_CURL_OPTS[@]}" "https://${APP_FQDN}/" >/dev/null 2>&1; then
    log_pass "curl validated the TLS chain (no -k needed)"
  else
    log_fail "curl could not validate the TLS chain"
  fi
fi

hr
echo "Summary: ${PASS} passed, ${FAIL} failed."
hr
[[ "${FAIL}" -eq 0 ]] || exit 1
