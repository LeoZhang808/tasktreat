#!/usr/bin/env bash
# Install / upgrade the self-hosted monitoring stack on EKS (Steps 11–14).
#
# This script is meant to be run from a CLUSTER-ADMIN local shell, NOT from
# CI. The Helm charts install CRDs (Prometheus, Alertmanager, ServiceMonitor,
# etc.) which are cluster-scoped; the GitHub Actions deploy role only has
# namespace-scoped admin and cannot create CRDs.
#
# Order matters:
#   1. Bootstrap namespace + secrets (one-time)
#   2. helm upgrade --install kube-prometheus-stack
#   3. helm upgrade --install loki
#   4. helm upgrade --install promtail
#   5. kubectl apply PrometheusRule
#   6. Render + apply Grafana Ingress (uses Terraform-output cert ARN/FQDN)
#
# Re-runs are safe (helm upgrade is idempotent; kubectl apply is declarative).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform/environments/dev"
HELM_DIR="${REPO_ROOT}/infra/helm/monitoring"
K8S_DIR="${REPO_ROOT}/k8s/monitoring"

NAMESPACE="${NAMESPACE:-monitoring}"
RELEASE_KPS="${RELEASE_KPS:-kube-prometheus-stack}"
RELEASE_LOKI="${RELEASE_LOKI:-loki}"
RELEASE_PROMTAIL="${RELEASE_PROMTAIL:-promtail}"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' is required on PATH." >&2
    exit 1
  }
}

require helm
require kubectl
require terraform
require sed

# -----------------------------------------------------------------------------
echo "==> Reading Terraform outputs (grafana FQDN + ACM cert ARN)"
# -----------------------------------------------------------------------------
pushd "${TF_DIR}" >/dev/null
GRAFANA_FQDN=$(terraform output -raw grafana_fqdn)
GRAFANA_ACM_ARN=$(terraform output -raw grafana_acm_certificate_arn)
popd >/dev/null

echo "    grafana_fqdn  = ${GRAFANA_FQDN}"
echo "    grafana_acm_arn = ${GRAFANA_ACM_ARN}"

# -----------------------------------------------------------------------------
echo
echo "==> Ensuring namespace ${NAMESPACE} exists"
# -----------------------------------------------------------------------------
kubectl apply -f "${K8S_DIR}/namespace.yaml"

# -----------------------------------------------------------------------------
echo
echo "==> Verifying required secrets exist in ${NAMESPACE}"
# -----------------------------------------------------------------------------
missing=()
for s in grafana-github-oauth alertmanager-slack-webhook; do
  if ! kubectl -n "${NAMESPACE}" get secret "${s}" >/dev/null 2>&1; then
    missing+=("${s}")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  cat >&2 <<EOF
ERROR: missing required secrets in namespace ${NAMESPACE}: ${missing[*]}

Run scripts/bootstrap-monitoring-secrets.sh first, or create them by hand:

  kubectl -n ${NAMESPACE} create secret generic grafana-github-oauth \\
    --from-literal=client_id=...   \\
    --from-literal=client_secret=...

  kubectl -n ${NAMESPACE} create secret generic alertmanager-slack-webhook \\
    --from-literal=webhook-url=https://hooks.slack.com/services/...

EOF
  exit 1
fi
echo "    OK: grafana-github-oauth, alertmanager-slack-webhook"

# -----------------------------------------------------------------------------
echo
echo "==> Adding Helm repos"
# -----------------------------------------------------------------------------
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo update >/dev/null

# -----------------------------------------------------------------------------
echo
echo "==> helm upgrade --install ${RELEASE_KPS}"
# -----------------------------------------------------------------------------
helm upgrade --install "${RELEASE_KPS}" prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --values "${HELM_DIR}/kube-prometheus-stack-values.yaml" \
  --wait \
  --timeout 10m

# -----------------------------------------------------------------------------
echo
echo "==> helm upgrade --install ${RELEASE_LOKI}"
# -----------------------------------------------------------------------------
helm upgrade --install "${RELEASE_LOKI}" grafana/loki \
  --namespace "${NAMESPACE}" \
  --values "${HELM_DIR}/loki-values.yaml" \
  --wait \
  --timeout 5m

# -----------------------------------------------------------------------------
echo
echo "==> helm upgrade --install ${RELEASE_PROMTAIL}"
# -----------------------------------------------------------------------------
helm upgrade --install "${RELEASE_PROMTAIL}" grafana/promtail \
  --namespace "${NAMESPACE}" \
  --values "${HELM_DIR}/promtail-values.yaml" \
  --wait \
  --timeout 5m

# -----------------------------------------------------------------------------
echo
echo "==> Applying PrometheusRule"
# -----------------------------------------------------------------------------
kubectl apply -f "${K8S_DIR}/prometheus-rules.yaml"

# -----------------------------------------------------------------------------
echo
echo "==> Rendering and applying Grafana Ingress"
# -----------------------------------------------------------------------------
RENDERED="${K8S_DIR}/grafana-ingress.yaml"
sed -e "s|__ACM_CERTIFICATE_ARN__|${GRAFANA_ACM_ARN}|g" \
    -e "s|__GRAFANA_FQDN__|${GRAFANA_FQDN}|g" \
    "${K8S_DIR}/grafana-ingress.yaml.template" \
  > "${RENDERED}"

kubectl apply -f "${RENDERED}"

# -----------------------------------------------------------------------------
echo
echo "==> Waiting for the Grafana ALB to be provisioned"
# -----------------------------------------------------------------------------
# Up to 3 minutes for the AWS LB controller to spin up the ALB and write
# the hostname into Ingress status.
for i in $(seq 1 36); do
  ALB_HOSTNAME=$(kubectl get ingress grafana-ingress -n "${NAMESPACE}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [[ -n "${ALB_HOSTNAME}" ]]; then
    break
  fi
  sleep 5
done

if [[ -z "${ALB_HOSTNAME}" ]]; then
  echo "WARN: Grafana ALB hostname not yet published. Re-run when the Ingress has an ADDRESS:" >&2
  echo "  kubectl get ingress grafana-ingress -n ${NAMESPACE}" >&2
else
  echo "    ALB hostname: ${ALB_HOSTNAME}"
fi

cat <<EOF

Monitoring stack installed.

Next steps:

  1. (One-time) Point grafana.<apex> at the ALB:
     - Easiest: set \`grafana_alb_provisioned = true\` in
       infra/terraform/environments/dev/terraform.tfvars and run:
         cd infra/terraform/environments/dev && terraform apply
       (Terraform now sees the ALB by tag and creates the alias.)

  2. Open https://${GRAFANA_FQDN}
     - You should be redirected to GitHub OAuth.
     - There is no username/password fallback.

  3. Check pods:
     kubectl get pods -n ${NAMESPACE}

  4. View alert rules:
     kubectl get prometheusrules -n ${NAMESPACE}

EOF
