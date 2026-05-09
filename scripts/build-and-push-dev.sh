#!/usr/bin/env bash
# Build all four TaskTreat images from the repo root and push them to ECR
# with the `dev-latest` tag.
#
# The Docker build context MUST be the repo root because every Dockerfile
# copies the root `package.json` / `package-lock.json` and runs npm workspace
# installs. Building from a service subfolder will silently miss the lockfile
# and produce non-deterministic dependency trees.
#
# Usage:
#   ./scripts/ecr-login.sh              # one-time auth
#   ./scripts/build-and-push-dev.sh     # build + push all 4 images

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-west-2}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-066263929068}"
IMAGE_TAG="${IMAGE_TAG:-dev-latest}"
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Always run from the repo root so the Docker build context is consistent
# no matter where the caller invokes the script from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# image_name=<dockerfile_path> pairs. Frontend lives at frontend/Dockerfile,
# every backend lives at services/<name>/Dockerfile.
build_and_push() {
  local repo_name="$1"      # ECR repo short name, e.g. tasktreat-dev-task-service
  local dockerfile="$2"     # path to the service's Dockerfile from repo root
  local image="${REGISTRY}/${repo_name}:${IMAGE_TAG}"

  echo
  echo "============================================================"
  echo "  Building ${repo_name}"
  echo "  Dockerfile: ${dockerfile}"
  echo "  Tag:        ${image}"
  echo "============================================================"

  # `--platform linux/amd64` matches the EKS managed node group (Amazon Linux 2
  # on x86_64). Without it, Apple Silicon builds produce arm64 images that
  # CrashLoopBackOff on the cluster with "exec format error".
  docker build \
    --platform linux/amd64 \
    -f "${dockerfile}" \
    -t "${image}" \
    .

  echo "==> Pushing ${image}"
  docker push "${image}"
}

build_and_push "tasktreat-dev-task-service"     "services/task-service/Dockerfile"
build_and_push "tasktreat-dev-wishlist-service" "services/wishlist-service/Dockerfile"
build_and_push "tasktreat-dev-reward-service"   "services/reward-service/Dockerfile"
build_and_push "tasktreat-dev-frontend"         "frontend/Dockerfile"

echo
echo "==> All four images built and pushed with tag '${IMAGE_TAG}'"
