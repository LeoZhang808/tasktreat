#!/usr/bin/env bash
# Installs the Argo Rollouts controller into the currently-targeted cluster.
# Idempotent: re-running just re-applies the upstream install manifest.
#
# Used for Step 7. The controller is what watches Rollout CRDs and progresses
# the canary steps (20% -> pause -> 50% -> pause -> 100%).

set -euo pipefail

NS="${NS:-argo-rollouts}"
ARGO_VER="${ARGO_VER:-latest}"

echo "==> ensuring namespace ${NS}"
kubectl get namespace "${NS}" >/dev/null 2>&1 || kubectl create namespace "${NS}"

if [[ "${ARGO_VER}" == "latest" ]]; then
  URL="https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml"
else
  URL="https://github.com/argoproj/argo-rollouts/releases/download/${ARGO_VER}/install.yaml"
fi

echo "==> applying ${URL}"
kubectl apply -n "${NS}" -f "${URL}"

echo "==> waiting for controller to become Ready"
kubectl rollout status -n "${NS}" deployment/argo-rollouts --timeout=180s

echo "==> Argo Rollouts is up:"
kubectl get pods -n "${NS}"
