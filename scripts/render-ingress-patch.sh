#!/usr/bin/env bash
# Render `k8s/overlays/dev/ingress-patch.yaml` from the committed
# `.template` file by substituting the ACM certificate ARN and the public
# app FQDN read out of `terraform output`.
#
# The rendered file is gitignored. Re-run after every `terraform apply`
# that changes the certificate or the domain.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform/environments/dev"
OVERLAY_DIR="${REPO_ROOT}/k8s/overlays/dev"
TEMPLATE="${OVERLAY_DIR}/ingress-patch.yaml.template"
OUTPUT="${OVERLAY_DIR}/ingress-patch.yaml"

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' is required on PATH." >&2
    exit 1
  }
}

require terraform

[[ -f "${TEMPLATE}" ]] || {
  echo "ERROR: template not found: ${TEMPLATE}" >&2
  exit 1
}

pushd "${TF_DIR}" >/dev/null
APP_FQDN=$(terraform output -raw app_fqdn)
CERT_ARN=$(terraform output -raw acm_certificate_arn)
popd >/dev/null

[[ -n "${APP_FQDN}" ]] || {
  echo "ERROR: terraform output 'app_fqdn' is empty." >&2
  exit 1
}
[[ -n "${CERT_ARN}" ]] || {
  echo "ERROR: terraform output 'acm_certificate_arn' is empty." >&2
  exit 1
}

# Use a delimiter that can't appear in the ARN/FQDN.
sed -e "s|__APP_FQDN__|${APP_FQDN}|g" \
    -e "s|__ACM_CERTIFICATE_ARN__|${CERT_ARN}|g" \
    "${TEMPLATE}" >"${OUTPUT}"

echo "Rendered: ${OUTPUT}"
echo "  host: ${APP_FQDN}"
echo "  cert: ${CERT_ARN}"
