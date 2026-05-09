#!/usr/bin/env bash
# Apply a TaskTreat Kustomize overlay to the current kubectl context (expects
# AWS CLI EKS kubeconfig, e.g. after `aws eks update-kubeconfig`).
#
# Usage:
#   ./scripts/deploy-k8s.sh dev
#   IMAGE_TAG=dev-abc1234 ./scripts/deploy-k8s.sh dev
#
# Optional env:
#   ECR_REGISTRY   (default from AWS_ACCOUNT_ID + AWS_REGION)
#   AWS_REGION     default us-west-2
#   AWS_ACCOUNT_ID default 066263929068
#   IMAGE_TAG      if set, runs `kustomize edit set image` for all four services

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OVERLAY_NAME="${1:?Usage: $0 <dev|qa|uat|prod>}"

OVERLAY_DIR="${REPO_ROOT}/k8s/overlays/${OVERLAY_NAME}"
[[ -d "${OVERLAY_DIR}" ]] || {
  echo "ERROR: unknown overlay '${OVERLAY_NAME}' (missing ${OVERLAY_DIR})" >&2
  exit 1
}

AWS_REGION="${AWS_REGION:-us-west-2}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-066263929068}"
ECR_REGISTRY="${ECR_REGISTRY:-${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com}"

if [[ -n "${IMAGE_TAG:-}" ]]; then
  (
    cd "${OVERLAY_DIR}"
    kustomize edit set image \
      tasktreat-dev-task-service="${ECR_REGISTRY}/tasktreat-dev-task-service:${IMAGE_TAG}" \
      tasktreat-dev-wishlist-service="${ECR_REGISTRY}/tasktreat-dev-wishlist-service:${IMAGE_TAG}" \
      tasktreat-dev-reward-service="${ECR_REGISTRY}/tasktreat-dev-reward-service:${IMAGE_TAG}" \
      tasktreat-dev-frontend="${ECR_REGISTRY}/tasktreat-dev-frontend:${IMAGE_TAG}"
  )
fi

if [[ "${OVERLAY_NAME}" == "dev" ]]; then
  TEMPLATE="${OVERLAY_DIR}/ingress-patch.yaml.template"
  OUT="${OVERLAY_DIR}/ingress-patch.yaml"
  if [[ -f "${TEMPLATE}" ]]; then
    if [[ -z "${APP_FQDN:-}" || -z "${ACM_CERTIFICATE_ARN:-}" ]]; then
      echo "ERROR: dev overlay needs APP_FQDN and ACM_CERTIFICATE_ARN to render ingress-patch.yaml" >&2
      echo "  (or run scripts/render-ingress-patch.sh from a machine with Terraform outputs.)" >&2
      exit 1
    fi
    sed -e "s|__APP_FQDN__|${APP_FQDN}|g" \
      -e "s|__ACM_CERTIFICATE_ARN__|${ACM_CERTIFICATE_ARN}|g" \
      "${TEMPLATE}" >"${OUT}"
  fi
fi

kubectl apply -k "${OVERLAY_DIR}"

case "${OVERLAY_NAME}" in
  dev) NS=tasktreat-dev ;;
  qa) NS=tasktreat-qa ;;
  uat) NS=tasktreat-uat ;;
  prod) NS=tasktreat-prod ;;
  *)
    echo "ERROR: internal: bad overlay" >&2
    exit 1
    ;;
esac

kubectl rollout status deployment/frontend -n "${NS}" --timeout=180s
kubectl rollout status deployment/task-service -n "${NS}" --timeout=180s
kubectl rollout status deployment/wishlist-service -n "${NS}" --timeout=180s
kubectl rollout status deployment/reward-service -n "${NS}" --timeout=180s
