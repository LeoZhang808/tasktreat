#!/usr/bin/env bash
# Triggers a visible canary rollout of one production service for demo
# purposes. Picks the named service (default: task-service), rewrites its
# image tag in the prod overlay to the user-supplied tag, applies, and then
# tails the Argo Rollouts progress so you can show 20% -> 50% -> 100% live.
#
# Usage:
#   scripts/canary-demo.sh <service> <image-tag>
#   scripts/canary-demo.sh task-service v1.0.1
#
# Pair with scripts/verify-zero-downtime.sh in another terminal to prove that
# no requests were dropped during the rollout.

set -euo pipefail

SERVICE="${1:-task-service}"
TAG="${2:-}"
NAMESPACE="${NAMESPACE:-tasktreat-prod}"
ECR_REGISTRY="${ECR_REGISTRY:-066263929068.dkr.ecr.us-west-2.amazonaws.com}"

if [[ -z "${TAG}" ]]; then
  echo "usage: $0 <service> <image-tag>" >&2
  echo "example: $0 task-service v1.0.1" >&2
  exit 2
fi

case "${SERVICE}" in
  task-service|wishlist-service|reward-service|frontend) ;;
  *)
    echo "unknown service '${SERVICE}' (expected one of: task-service, wishlist-service, reward-service, frontend)" >&2
    exit 2
    ;;
esac

repo="tasktreat-dev-${SERVICE}"
image="${ECR_REGISTRY}/${repo}:${TAG}"

echo "==> rewriting prod overlay: ${repo} -> ${TAG}"
( cd k8s/overlays/prod && kustomize edit set image "${repo}=${image}" )

echo "==> kubectl apply -k k8s/overlays/prod"
kubectl apply -k k8s/overlays/prod

echo "==> watching rollout/${SERVICE} in ${NAMESPACE} (Ctrl-C to detach)"
kubectl argo rollouts get rollout "${SERVICE}" -n "${NAMESPACE}" --watch
