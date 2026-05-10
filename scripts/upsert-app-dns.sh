#!/usr/bin/env bash
# UPSERT an A-alias record in the Route 53 hosted zone created by Terraform
# so that the public app FQDN (app.tasktreat.dev) points at the ALB the
# Kubernetes Ingress just created.
#
# This is the "manual record after ALB exists" path described in the Step 5
# spec, automated end-to-end:
#
#   1. Read the hosted zone ID and app FQDN from `terraform output`.
#   2. Read the ALB hostname from the Ingress status.
#   3. Look up the ALB's canonical hosted zone ID via the ELBv2 API
#      (this varies per ALB and is the right way to populate the alias
#      target — do NOT hardcode the regional ELB hosted zone ID).
#   4. Submit a single UPSERT change set so re-running is idempotent.
#
# Re-run after recreating the Ingress (the ALB hostname changes when the
# Ingress is deleted/recreated).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform/environments/dev"

NAMESPACE="${NAMESPACE:-tasktreat-dev}"
INGRESS_NAME="${INGRESS_NAME:-tasktreat-ingress}"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' is required on PATH." >&2
    exit 1
  }
}

require terraform
require kubectl
require aws
require jq

pushd "${TF_DIR}" >/dev/null
ZONE_ID=$(terraform output -raw route53_zone_id)
APP_FQDN=$(terraform output -raw app_fqdn)
AWS_REGION=$(terraform output -raw aws_region)
popd >/dev/null

echo "==> Resolving Ingress -> ALB hostname"
ALB_HOSTNAME=$(kubectl get ingress "${INGRESS_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [[ -z "${ALB_HOSTNAME}" ]]; then
  echo "ERROR: Ingress ${NAMESPACE}/${INGRESS_NAME} has no ADDRESS yet." >&2
  echo "  kubectl describe ingress ${INGRESS_NAME} -n ${NAMESPACE}" >&2
  exit 1
fi
echo "    Ingress hostname: ${ALB_HOSTNAME}"

echo
echo "==> Looking up ALB CanonicalHostedZoneId via ELBv2"
# Match the ALB by its DNSName instead of by name so we don't have to parse
# the AWS-generated `k8s-<ns>-<ing>-<hash>` name.
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --region "${AWS_REGION}" \
  --query "LoadBalancers[?DNSName==\`${ALB_HOSTNAME}\`].CanonicalHostedZoneId | [0]" \
  --output text)

if [[ -z "${ALB_ZONE_ID}" || "${ALB_ZONE_ID}" == "None" ]]; then
  echo "ERROR: Could not find ALB ${ALB_HOSTNAME} in region ${AWS_REGION}." >&2
  exit 1
fi
echo "    ALB hosted zone ID: ${ALB_ZONE_ID}"

CHANGE_BATCH=$(jq -nc \
  --arg name "${APP_FQDN}" \
  --arg dns "${ALB_HOSTNAME}" \
  --arg zid "${ALB_ZONE_ID}" \
  '{
    Comment: "tasktreat: app FQDN -> ALB alias",
    Changes: [
      {
        Action: "UPSERT",
        ResourceRecordSet: {
          Name: $name,
          Type: "A",
          AliasTarget: {
            HostedZoneId: $zid,
            DNSName: $dns,
            EvaluateTargetHealth: false
          }
        }
      }
    ]
  }')

echo
echo "==> UPSERTing Route 53 alias ${APP_FQDN} -> ${ALB_HOSTNAME}"
CHANGE_ID=$(aws route53 change-resource-record-sets \
  --hosted-zone-id "${ZONE_ID}" \
  --change-batch "${CHANGE_BATCH}" \
  --query 'ChangeInfo.Id' \
  --output text)

echo "    Change ID: ${CHANGE_ID}"

echo
echo "==> Waiting for the change to propagate to all Route 53 servers"
aws route53 wait resource-record-sets-changed --id "${CHANGE_ID}"
echo "    Synced."

echo
echo "==> dig ${APP_FQDN}"
dig +short "${APP_FQDN}" || true

cat <<EOF

App should now be reachable at https://${APP_FQDN}
(allow up to ~30s for DNS resolvers outside Route 53 to refresh.)
EOF
