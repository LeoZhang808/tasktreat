#!/usr/bin/env bash
# Install (or upgrade) the AWS Load Balancer Controller in the EKS cluster.
#
# The IAM role/policy and OIDC trust were created by Terraform
# (`module.alb_controller_irsa`); this script:
#   1. Reads the role ARN, cluster name, region, and VPC ID from
#      `terraform output` in environments/dev.
#   2. Creates the kube-system service account annotated with that role
#      (so the controller pod can call AWS APIs via IRSA).
#   3. Adds the eks-charts Helm repo and runs `helm upgrade --install`
#      with `serviceAccount.create=false` so it reuses the SA we just made.
#   4. Waits for the deployment to roll out.
#
# Re-running is safe; everything is idempotent.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform/environments/dev"

NAMESPACE="${NAMESPACE:-kube-system}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-aws-load-balancer-controller}"
CHART_VERSION="${CHART_VERSION:-1.10.1}" # AWS LBC v2.11.0

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' is required on PATH." >&2
    exit 1
  }
}

require terraform
require kubectl
require helm
require aws

echo "==> Reading Terraform outputs from ${TF_DIR}"
pushd "${TF_DIR}" >/dev/null
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw aws_region)
VPC_ID=$(terraform output -raw vpc_id)
ROLE_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn)
popd >/dev/null

echo "    Cluster:    ${CLUSTER_NAME}"
echo "    Region:     ${AWS_REGION}"
echo "    VPC ID:     ${VPC_ID}"
echo "    Role ARN:   ${ROLE_ARN}"
echo "    Namespace:  ${NAMESPACE}"
echo "    SA name:    ${SERVICE_ACCOUNT}"

echo
echo "==> Updating kubeconfig"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}" >/dev/null
echo "    current-context: $(kubectl config current-context)"

echo
echo "==> Creating/annotating service account ${NAMESPACE}/${SERVICE_ACCOUNT}"
# Use a server-side apply so re-runs converge cleanly.
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${SERVICE_ACCOUNT}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: aws-load-balancer-controller
    app.kubernetes.io/component: controller
    app.kubernetes.io/managed-by: tasktreat-bootstrap
  annotations:
    eks.amazonaws.com/role-arn: ${ROLE_ARN}
EOF

echo
echo "==> Adding/updating eks-charts Helm repo"
helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update eks >/dev/null

echo
echo "==> Installing/upgrading aws-load-balancer-controller (chart ${CHART_VERSION})"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace "${NAMESPACE}" \
  --version "${CHART_VERSION}" \
  --set "clusterName=${CLUSTER_NAME}" \
  --set "region=${AWS_REGION}" \
  --set "vpcId=${VPC_ID}" \
  --set "serviceAccount.create=false" \
  --set "serviceAccount.name=${SERVICE_ACCOUNT}" \
  --wait

echo
echo "==> Verifying deployment"
kubectl -n "${NAMESPACE}" rollout status deployment/aws-load-balancer-controller --timeout=180s
kubectl -n "${NAMESPACE}" get deployment aws-load-balancer-controller
kubectl -n "${NAMESPACE}" get pods -l app.kubernetes.io/name=aws-load-balancer-controller

echo
echo "==> AWS Load Balancer Controller is installed."
