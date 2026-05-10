#!/usr/bin/env bash
# Continuously hits the public TaskTreat endpoints while a canary rollout is
# in progress and fails (nonzero exit) if any request returns non-2xx/3xx.
#
# This is the zero-downtime evidence for Step 7. Run it in one terminal,
# trigger a rollout in another, and watch the totals at the end.
#
# Env:
#   BASE_URL          Base URL to probe, e.g. https://app.tasktreat.dev
#                     (default: http://127.0.0.1:18080 via port-forward to
#                     svc/frontend in tasktreat-prod).
#   NAMESPACE         Namespace for the fallback port-forward (default:
#                     tasktreat-prod).
#   DURATION_SECONDS  How long to probe in seconds (default 180).
#   INTERVAL_SECONDS  Sleep between rounds in seconds (default 1).
#
# Exit code:
#   0 if no failures, 1 if any request returned non-2xx/3xx or curl errored.

set -euo pipefail

BASE_URL="${BASE_URL:-}"
NAMESPACE="${NAMESPACE:-tasktreat-prod}"
DURATION_SECONDS="${DURATION_SECONDS:-180}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-1}"

PFPID=""
cleanup() {
  if [[ -n "${PFPID}" ]]; then
    kill "${PFPID}" 2>/dev/null || true
    wait "${PFPID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [[ -z "${BASE_URL}" ]]; then
  LOCAL_PORT="${LOCAL_PORT:-18080}"
  echo "BASE_URL not set; opening port-forward to svc/frontend in ${NAMESPACE} on ${LOCAL_PORT}"
  kubectl port-forward -n "${NAMESPACE}" svc/frontend "${LOCAL_PORT}:80" >/dev/null 2>&1 &
  PFPID=$!
  sleep 3
  BASE_URL="http://127.0.0.1:${LOCAL_PORT}"
fi

BASE="${BASE_URL%/}"

PATHS=(
  "/"
  "/api/tasks/"
  "/api/wishlist/"
  "/api/rewards/eligibility"
)

total=0
failed=0
end_at=$(( $(date +%s) + DURATION_SECONDS ))

printf "==> probing %s for %ss (%s endpoints, every %ss)\n" \
  "${BASE}" "${DURATION_SECONDS}" "${#PATHS[@]}" "${INTERVAL_SECONDS}"

while (( $(date +%s) < end_at )); do
  for p in "${PATHS[@]}"; do
    total=$((total + 1))
    # -o /dev/null silences body; -w prints the HTTP status; -m 5 caps each
    # request so a hung backend can't stall the probe loop.
    code="$(curl -sS -o /dev/null -m 5 -w "%{http_code}" "${BASE}${p}" || echo "000")"
    if [[ ! "${code}" =~ ^[23][0-9][0-9]$ ]]; then
      failed=$((failed + 1))
      printf "  FAIL %s -> %s\n" "${BASE}${p}" "${code}"
    fi
  done
  sleep "${INTERVAL_SECONDS}"
done

printf "==> done: %d requests, %d failures\n" "${total}" "${failed}"
if (( failed > 0 )); then
  exit 1
fi
