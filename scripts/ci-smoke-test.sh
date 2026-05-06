#!/usr/bin/env bash
# Post-deploy smoke checks for any namespace (dev / qa / uat / prod).
#
# By default opens a temporary kubectl port-forward to svc/frontend and
# exercises the app through the frontend nginx /api routes.
#
# Env:
#   ENVIRONMENT   dev|qa|uat|prod (informational; affects default write behavior)
#   NAMESPACE     Kubernetes namespace (required)
#   BASE_URL      If set (e.g. https://app.example.com), skip port-forward
#   SMOKE_WRITE   0 = read-only checks only (recommended for prod)
#   KUBECONFIG    Standard kubeconfig for kubectl
#
# Example:
#   NAMESPACE=tasktreat-dev ./scripts/ci-smoke-test.sh

set -euo pipefail

ENVIRONMENT="${ENVIRONMENT:-dev}"
NAMESPACE="${NAMESPACE:?Set NAMESPACE (e.g. tasktreat-dev)}"
SMOKE_WRITE="${SMOKE_WRITE:-}"

if [[ "${SMOKE_WRITE}" == "" ]]; then
  if [[ "${ENVIRONMENT}" == "prod" ]]; then
    SMOKE_WRITE=0
  else
    SMOKE_WRITE=1
  fi
fi

PFPID=""
cleanup() {
  if [[ -n "${PFPID}" ]]; then
    kill "${PFPID}" 2>/dev/null || true
    wait "${PFPID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [[ -n "${BASE_URL:-}" ]]; then
  BASE="${BASE_URL%/}"
else
  LOCAL_PORT="${LOCAL_PORT:-18080}"
  kubectl port-forward -n "${NAMESPACE}" "svc/frontend" "${LOCAL_PORT}:80" >/dev/null 2>&1 &
  PFPID=$!
  sleep 3
  BASE="http://127.0.0.1:${LOCAL_PORT}"
fi

echo "==> Smoke ${ENVIRONMENT} namespace=${NAMESPACE} base=${BASE} write=${SMOKE_WRITE}"

curl -sfS "${BASE}/" >/dev/null
echo "    frontend static OK"

curl -sfS "${BASE}/api/tasks/" | grep -q '"count"' || {
  echo "ERROR: task-service list response unexpected" >&2
  exit 1
}
echo "    GET /api/tasks OK"

curl -sfS "${BASE}/api/wishlist/" | grep -q '"count"' || {
  echo "ERROR: wishlist list response unexpected" >&2
  exit 1
}
echo "    GET /api/wishlist OK"

curl -sfS "${BASE}/api/rewards/eligibility" | grep -q 'tasksCompleted' || {
  echo "ERROR: rewards eligibility response unexpected" >&2
  exit 1
}
echo "    GET /api/rewards/eligibility OK"

if [[ "${SMOKE_WRITE}" == "1" ]]; then
  TS="$(date -u +%Y%m%dT%H%M%SZ)"
  TASK_TITLE="CI Smoke Test - ${TS}"

  RESP="$(curl -sfS -X POST "${BASE}/api/tasks/" \
    -H 'Content-Type: application/json' \
    -d "{\"title\":\"${TASK_TITLE}\"}")"
  echo "${RESP}" | grep -q '"id"' || {
    echo "ERROR: create task failed: ${RESP}" >&2
    exit 1
  }
  echo "    POST /api/tasks OK"

  RESP="$(curl -sfS -X POST "${BASE}/api/wishlist/" \
    -H 'Content-Type: application/json' \
    -d "{\"name\":\"CI Smoke Wish - ${TS}\",\"price\":1.99}")"
  echo "${RESP}" | grep -q '"id"' || {
    echo "ERROR: create wishlist item failed: ${RESP}" >&2
    exit 1
  }
  echo "    POST /api/wishlist OK"
fi

echo "==> Smoke tests passed for ${NAMESPACE}"
