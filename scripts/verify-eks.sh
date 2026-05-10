#!/usr/bin/env bash
# Sanity-check that the local kubectl is pointed at the TaskTreat dev EKS
# cluster and that the Step 4 workload looks healthy.
#
# Usage: ./scripts/verify-eks.sh

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-west-2}"
CLUSTER_NAME="${CLUSTER_NAME:-tasktreat-dev-eks}"
NAMESPACE="${NAMESPACE:-tasktreat-dev}"

hr() { echo "============================================================"; }

hr
echo "  Region:     ${AWS_REGION}"
echo "  Cluster:    ${CLUSTER_NAME}"
echo "  Namespace:  ${NAMESPACE}"
hr

echo
echo "==> Updating kubeconfig"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}" >/dev/null
echo "current-context: $(kubectl config current-context)"

echo
echo "==> Nodes"
kubectl get nodes -o wide

echo
echo "==> Namespace"
kubectl get namespace "${NAMESPACE}" || {
  echo "Namespace ${NAMESPACE} not found. Apply k8s/overlays/dev first."
  exit 1
}

echo
echo "==> ConfigMap"
kubectl get configmap -n "${NAMESPACE}"

echo
echo "==> Secrets (names only)"
kubectl get secrets -n "${NAMESPACE}"

echo
echo "==> Deployments"
kubectl get deployments -n "${NAMESPACE}"

echo
echo "==> Pods"
kubectl get pods -n "${NAMESPACE}" -o wide

echo
echo "==> Services"
kubectl get svc -n "${NAMESPACE}"

echo
echo "==> Recent events (last 20)"
kubectl get events -n "${NAMESPACE}" --sort-by=.lastTimestamp | tail -n 20 || true

echo
echo "==> Done. Use 'kubectl port-forward' on each Service to test /health."
