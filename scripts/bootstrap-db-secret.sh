#!/usr/bin/env bash
# Bootstrap `tasktreat-db-secret` in a target namespace by cloning the
# known-good copy from `tasktreat-dev`.
#
# Why this exists: every backend pod's container start runs
# `prisma migrate deploy && node dist/index.js`, which needs DATABASE_URL.
# That value lives in the cluster-side Secret `tasktreat-db-secret`, which
# is deliberately NOT committed to git. The Step 4 runbook only creates
# the secret in `tasktreat-dev`; qa/uat/prod start out without it (or with
# a stale placeholder), which makes every pod CrashLoopBackOff on
# Prisma P1000 "Authentication failed".
#
# Once the dev secret is correct, this script just copies it across.
#
# Idempotent: re-running re-applies the same content.
#
# Usage:
#   scripts/bootstrap-db-secret.sh tasktreat-uat
#   scripts/bootstrap-db-secret.sh tasktreat-qa
#   scripts/bootstrap-db-secret.sh tasktreat-prod
#
# Env knobs:
#   SOURCE_NS   namespace to read the secret FROM (default: tasktreat-dev)
#   SECRET_NAME secret to clone (default: tasktreat-db-secret)

set -euo pipefail

TARGET_NS="${1:-}"
SOURCE_NS="${SOURCE_NS:-tasktreat-dev}"
SECRET_NAME="${SECRET_NAME:-tasktreat-db-secret}"

if [[ -z "${TARGET_NS}" ]]; then
  echo "usage: $0 <target-namespace>" >&2
  echo "  e.g. $0 tasktreat-uat" >&2
  exit 2
fi

if [[ "${TARGET_NS}" == "${SOURCE_NS}" ]]; then
  echo "ERROR: target namespace must differ from source (${SOURCE_NS})" >&2
  exit 2
fi

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' is required on PATH." >&2
    exit 1
  }
}
require kubectl
require jq

if ! kubectl get namespace "${TARGET_NS}" >/dev/null 2>&1; then
  echo "ERROR: namespace ${TARGET_NS} does not exist. Create it first." >&2
  exit 1
fi

if ! kubectl -n "${SOURCE_NS}" get secret "${SECRET_NAME}" >/dev/null 2>&1; then
  echo "ERROR: source secret ${SOURCE_NS}/${SECRET_NAME} does not exist." >&2
  echo "       Create it first per k8s/README.md (Step 4)." >&2
  exit 1
fi

# Sanity-check the three keys exist on the source. Catches the case where
# someone has a half-populated secret and we'd silently propagate it.
for key in DATABASE_URL_TASK DATABASE_URL_WISHLIST DATABASE_URL_REWARD; do
  val=$(kubectl -n "${SOURCE_NS}" get secret "${SECRET_NAME}" \
    -o jsonpath="{.data.${key}}" 2>/dev/null || true)
  if [[ -z "${val}" ]]; then
    echo "ERROR: source secret ${SOURCE_NS}/${SECRET_NAME} is missing key ${key}" >&2
    exit 1
  fi
done

echo "==> Cloning ${SECRET_NAME} from ${SOURCE_NS} to ${TARGET_NS}"
kubectl -n "${SOURCE_NS}" get secret "${SECRET_NAME}" -o json \
  | jq --arg ns "${TARGET_NS}" '
      del(
        .metadata.creationTimestamp,
        .metadata.resourceVersion,
        .metadata.uid,
        .metadata.namespace,
        .metadata.managedFields,
        .metadata.annotations,
        .metadata.ownerReferences
      ) | .metadata.namespace = $ns
    ' \
  | kubectl apply -f -

# Confirm the target now has the three required keys.
echo
echo "==> Verifying ${TARGET_NS}/${SECRET_NAME}"
missing=0
for key in DATABASE_URL_TASK DATABASE_URL_WISHLIST DATABASE_URL_REWARD; do
  if [[ -z "$(kubectl -n "${TARGET_NS}" get secret "${SECRET_NAME}" \
      -o jsonpath="{.data.${key}}" 2>/dev/null)" ]]; then
    echo "  MISSING: ${key}" >&2
    missing=1
  else
    echo "  OK:      ${key}"
  fi
done
[[ "${missing}" == "0" ]] || exit 1

cat <<EOF

Done. If the target namespace already had pods crashlooping on the old
password, kick them so they pick up the new secret value:

  kubectl -n ${TARGET_NS} rollout restart deployment

(Or, for tasktreat-prod after Step 7, the equivalent for Rollouts:)

  kubectl -n ${TARGET_NS} argo rollouts restart task-service
  kubectl -n ${TARGET_NS} argo rollouts restart wishlist-service
  kubectl -n ${TARGET_NS} argo rollouts restart reward-service
EOF
