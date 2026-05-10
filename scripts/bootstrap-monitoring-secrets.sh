#!/usr/bin/env bash
# Bootstrap the two out-of-band Secrets the monitoring stack depends on.
#
# These are kept OUT of the Helm values files and the Kustomize tree so
# real credentials never end up in Git. The Helm values reference these
# Secret names directly (envFromSecret + alertmanagerSpec.secrets).
#
# Pass credentials via environment variables, NOT command-line arguments,
# so they don't show up in `ps`/shell history. Both secrets are
# idempotently re-created (kubectl apply -f with the printed manifest) so
# this script can be re-run to rotate keys.
#
# Required env vars:
#   GH_OAUTH_CLIENT_ID         GitHub OAuth App client ID
#   GH_OAUTH_CLIENT_SECRET     GitHub OAuth App client secret
#   SLACK_WEBHOOK_URL          Slack Incoming Webhook URL (https://hooks.slack.com/services/...)
#
# Optional:
#   NAMESPACE  (default: monitoring)

set -euo pipefail

NAMESPACE="${NAMESPACE:-monitoring}"

require_var() {
  if [[ -z "${!1:-}" ]]; then
    echo "ERROR: env var \$$1 is required." >&2
    exit 1
  fi
}

require_var GH_OAUTH_CLIENT_ID
require_var GH_OAUTH_CLIENT_SECRET
require_var SLACK_WEBHOOK_URL

command -v kubectl >/dev/null || {
  echo "ERROR: kubectl is required on PATH." >&2
  exit 1
}

# Ensure the namespace exists. The Namespace manifest is committed but
# applying it from this script makes the bootstrap self-contained.
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Grafana GitHub OAuth.
#
# The chart's `envFromSecret: grafana-github-oauth` mounts every key in this
# Secret as an env var on the Grafana pod with the key name unchanged.
# Grafana reads GF_AUTH_GITHUB_CLIENT_ID / _SECRET at startup, so the keys
# MUST be exactly:
#   GF_AUTH_GITHUB_CLIENT_ID
#   GF_AUTH_GITHUB_CLIENT_SECRET
kubectl -n "${NAMESPACE}" create secret generic grafana-github-oauth \
  --from-literal=GF_AUTH_GITHUB_CLIENT_ID="${GH_OAUTH_CLIENT_ID}" \
  --from-literal=GF_AUTH_GITHUB_CLIENT_SECRET="${GH_OAUTH_CLIENT_SECRET}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Alertmanager Slack webhook.
#
# Mounted into the Alertmanager pod at
# /etc/alertmanager/secrets/alertmanager-slack-webhook/webhook-url
# (see `alertmanagerSpec.secrets` in kube-prometheus-stack-values.yaml).
# alertmanager.yml reads it via api_url_file so the URL never appears in
# the rendered config.
kubectl -n "${NAMESPACE}" create secret generic alertmanager-slack-webhook \
  --from-literal=webhook-url="${SLACK_WEBHOOK_URL}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo
echo "Created/updated Secrets in namespace ${NAMESPACE}:"
echo "  - grafana-github-oauth (GF_AUTH_GITHUB_CLIENT_ID, GF_AUTH_GITHUB_CLIENT_SECRET)"
echo "  - alertmanager-slack-webhook (webhook-url)"
echo
echo "If the stack is already running, restart Grafana / Alertmanager to pick up rotated creds:"
echo "  kubectl -n ${NAMESPACE} rollout restart deploy/kube-prometheus-stack-grafana"
echo "  kubectl -n ${NAMESPACE} rollout restart sts/alertmanager-kube-prometheus-stack-alertmanager"
