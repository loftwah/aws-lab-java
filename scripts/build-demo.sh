#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=${IMAGE_NAME:-aws-lab-java/demo-app}
PUSH=${PUSH:-false}
PLATFORM=${PLATFORM:-linux/amd64}
CONTEXT_DIR=${CONTEXT_DIR:-application}
BUILDER_NAME=${BUILDER_NAME:-aws-lab-java-builder}

if [[ ! -d "$CONTEXT_DIR" ]]; then
  echo "Expected build context directory '$CONTEXT_DIR' not found. Create the application scaffold before running this script." >&2
  exit 1
fi

git_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
latest_tag="latest"
sha_tag="sha-${git_sha}"

if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  docker buildx create --name "$BUILDER_NAME" >/dev/null
fi

docker buildx use "$BUILDER_NAME"

build_cmd=(docker buildx build --platform "$PLATFORM" --tag "$IMAGE_NAME:$latest_tag" --tag "$IMAGE_NAME:$sha_tag" "$CONTEXT_DIR")

if [[ "$PUSH" == "true" ]]; then
  build_cmd+=(--push)
else
  build_cmd+=(--load)
fi

"${build_cmd[@]}"

echo "Docker image available as $IMAGE_NAME:$latest_tag and $IMAGE_NAME:$sha_tag (platform: $PLATFORM)"
