#!/usr/bin/env bash
# Authenticate the local Docker client against the TaskTreat ECR registry.
#
# Usage: ./scripts/ecr-login.sh
#
# Requires the AWS CLI to be configured with credentials that can call
# `ecr:GetAuthorizationToken`. The Step 3 bootstrap user already has that.

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-west-2}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-066263929068}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "==> Logging Docker into ${ECR_REGISTRY}"

aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login \
      --username AWS \
      --password-stdin \
      "${ECR_REGISTRY}"

echo "==> ECR login OK"
