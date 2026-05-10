#!/usr/bin/env bash
# End-to-end deploy of the public Ingress: render the prod overlay's
# Ingress patch from Terraform outputs, then apply the prod overlay so
# the AWS Load Balancer Controller provisions an ALB serving
# app.tasktreat.dev.
#
# Prerequisites already in place:
#   * Terraform applied (route53, acm, alb_controller_irsa).
#   * Name.com nameservers point at Route 53 (so ACM is ISSUED).
#   * AWS Load Balancer Controller is installed
#     (scripts/install-aws-lb-controller.sh).
#   * The TaskTreat app is already deployed in tasktreat-prod
#     (release-prod workflow, or `kubectl apply -k k8s/overlays/prod`).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${NAMESPACE:-tasktreat-prod}"

echo "==> Rendering prod ingress overlay patch"
"${REPO_ROOT}/scripts/render-ingress-patch.sh"

echo
echo "==> Applying prod overlay"
kubectl apply -k "${REPO_ROOT}/k8s/overlays/prod"

echo
echo "==> Waiting up to 3m for the Ingress to acquire an ALB ADDRESS"
deadline=$(( $(date +%s) + 180 ))
ADDRESS=""
while [[ $(date +%s) -lt ${deadline} ]]; do
  ADDRESS=$(kubectl get ingress tasktreat-ingress -n "${NAMESPACE}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [[ -n "${ADDRESS}" ]]; then
    break
  fi
  printf "."
  sleep 5
done
echo

if [[ -z "${ADDRESS}" ]]; then
  echo "WARNING: Ingress still has no ADDRESS after 3 minutes."
  echo "Check controller logs:"
  echo "  kubectl logs -n kube-system deployment/aws-load-balancer-controller"
  echo "  kubectl describe ingress tasktreat-ingress -n ${NAMESPACE}"
  exit 1
fi

echo "ALB hostname: ${ADDRESS}"

# Pretty print the route table for the human running this.
echo
kubectl get ingress tasktreat-ingress -n "${NAMESPACE}"

cat <<EOF

==> Next step: point app.<your-domain> at this ALB.

Run:

  scripts/upsert-app-dns.sh

It reads the ALB hostname from this Ingress, looks up the ALB's
CanonicalHostedZoneId, and UPSERTs an A-alias record in the Route 53
hosted zone Terraform created.
EOF
