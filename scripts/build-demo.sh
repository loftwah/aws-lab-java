#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CONTAINER_REGISTRY_STACK="${REPO_ROOT}/infrastructure/terraform/stacks/development/container-registry"

REQUIRED_AWS_PROFILE="devops-sandbox"
REQUIRED_AWS_REGION="ap-southeast-2"

export AWS_PROFILE="$REQUIRED_AWS_PROFILE"
export AWS_REGION="$REQUIRED_AWS_REGION"
export AWS_DEFAULT_REGION="$REQUIRED_AWS_REGION"
export AWS_PAGER=""

IMAGE_REPO_NAME=${IMAGE_REPO_NAME:-aws-lab-java-demo}
PLATFORM=${PLATFORM:-linux/amd64}
CONTEXT_DIR=${CONTEXT_DIR:-application}
BUILDER_NAME=${BUILDER_NAME:-aws-lab-java-builder}
AUTO_LOGIN=${AUTO_LOGIN:-true}

infer_image_name() {
  if [[ -n "${IMAGE_NAME:-}" ]]; then
    return
  fi

  if command -v terraform >/dev/null 2>&1 && [[ -d "$CONTAINER_REGISTRY_STACK" ]]; then
    registry_url=$(terraform -chdir="$CONTAINER_REGISTRY_STACK" output -raw ecr_repository_url 2>/dev/null || true)
    if [[ -n "$registry_url" ]]; then
      IMAGE_NAME="$registry_url"
      return
    fi
  fi

  if command -v aws >/dev/null 2>&1; then
    account_id=$(aws --profile "$AWS_PROFILE" --region "$AWS_REGION" sts get-caller-identity --query Account --output text 2>/dev/null || true)
    if [[ -n "$account_id" && "$account_id" != "None" ]]; then
      IMAGE_NAME="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com/${IMAGE_REPO_NAME}"
      return
    fi
  fi

  IMAGE_NAME="aws-lab-java/demo-app"
}

infer_image_name

PUSH=${PUSH:-true}

if [[ ! -d "$CONTEXT_DIR" ]]; then
  echo "Expected build context directory '$CONTEXT_DIR' not found. Create the application scaffold before running this script." >&2
  exit 1
fi

git_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
latest_tag="latest"
sha_tag="sha-${git_sha}"

if [[ "$AUTO_LOGIN" == "true" && "$PUSH" == "true" && "$IMAGE_NAME" == *".dkr.ecr."* ]]; then
  if command -v aws >/dev/null 2>&1; then
    login_password=$(aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ecr get-login-password 2>/dev/null || true)
    if [[ -n "$login_password" ]]; then
      printf '%s' "$login_password" | docker login --username AWS --password-stdin "${IMAGE_NAME%%/*}" >/dev/null
    else
      echo "Warning: Unable to log in to ECR automatically. Continuing without login." >&2
    fi
  else
    echo "Warning: AWS CLI not found; skipping automatic ECR login." >&2
  fi
fi

if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  docker buildx create --name "$BUILDER_NAME" >/dev/null
fi

docker buildx use "$BUILDER_NAME"

build_cmd=(
  docker buildx build
  --platform "$PLATFORM"
  --tag "$IMAGE_NAME:$latest_tag"
  --tag "$IMAGE_NAME:$sha_tag"
  "$CONTEXT_DIR"
)

if [[ "$PUSH" == "true" ]]; then
  build_cmd+=(--push)
else
  build_cmd+=(--load)
fi

"${build_cmd[@]}"

if [[ "$PUSH" == "true" ]]; then
  echo "Docker image pushed to $IMAGE_NAME:$latest_tag and $IMAGE_NAME:$sha_tag (platform: $PLATFORM)"
else
  echo "Docker image available locally as $IMAGE_NAME:$latest_tag and $IMAGE_NAME:$sha_tag (platform: $PLATFORM)"
fi
