#!/bin/bash
set -e

SERVICE_NAME=$1
IMAGE_TAG=$2
shift 2
REGISTRIES=("$@")

echo "--> [DOCKER] Building $SERVICE_NAME..."

cd "services/$SERVICE_NAME"

# Build local image first
LOCAL_IMAGE="foodhub-$SERVICE_NAME:latest"
docker build -t "$LOCAL_IMAGE" .

for URI in "${REGISTRIES[@]}"; do
    echo "--> [DOCKER] Tagging and Pushing to: $URI"
    docker tag "$LOCAL_IMAGE" "$URI:$IMAGE_TAG"
    docker tag "$LOCAL_IMAGE" "$URI:latest"
    docker push "$URI:$IMAGE_TAG"
    docker push "$URI:latest"
done

echo "--> [DOCKER] Thành công! Dịch vụ $SERVICE_NAME đã được đẩy lên ${#REGISTRIES[@]} registries."