#!/bin/bash
set -e

# ========================================
# Docker Build & Push to GHCR
# ========================================
# Builds and pushes images to GitHub Container Registry
# Usage: ./docker-push-ghcr.sh <service> <tag>
# ========================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_green() { echo -e "${GREEN}✅ $1${NC}"; }
print_yellow() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_red() { echo -e "${RED}❌ $1${NC}"; }

# Configuration
GHCR_REGISTRY="ghcr.io"
GHCR_NAMESPACE=${GHCR_NAMESPACE:-"vutd22uit"}
SERVICE=${1:-""}
TAG=${2:-"latest"}

# Validate arguments
if [ -z "$SERVICE" ]; then
    echo "Usage: $0 <service> [tag]"
    echo ""
    echo "Services: users, products, orders, frontend"
    echo "Example: $0 users v1.0.0"
    exit 1
fi

# Validate service
case $SERVICE in
    users|products|orders|frontend)
        ;;
    *)
        print_red "Invalid service: $SERVICE"
        echo "Valid services: users, products, orders, frontend"
        exit 1
        ;;
esac

SERVICE_DIR="services/${SERVICE}"
if [ ! -d "$SERVICE_DIR" ]; then
    print_red "Service directory not found: $SERVICE_DIR"
    exit 1
fi

# Full image name
IMAGE_NAME="${GHCR_REGISTRY}/${GHCR_NAMESPACE}/foodhub-${SERVICE}"

echo "=========================================="
echo "🐳 Building & Pushing to GHCR"
echo "=========================================="
echo ""
echo "Service:   ${SERVICE}"
echo "Tag:       ${TAG}"
echo "Image:     ${IMAGE_NAME}:${TAG}"
echo ""

# Step 1: Login to GHCR
echo "Step 1: Logging in to GHCR..."
if [ -z "$GHCR_TOKEN" ]; then
    print_yellow "GHCR_TOKEN not set, attempting to use gh CLI..."
    if command -v gh &> /dev/null; then
        GHCR_TOKEN=$(gh auth token)
    else
        print_red "Please set GHCR_TOKEN environment variable"
        echo "   export GHCR_TOKEN=your_github_personal_access_token"
        exit 1
    fi
fi

echo "$GHCR_TOKEN" | docker login ${GHCR_REGISTRY} -u ${GHCR_NAMESPACE} --password-stdin
print_green "Logged in to GHCR"

# Step 2: Build image
echo ""
echo "Step 2: Building Docker image..."
cd ${SERVICE_DIR}

# Build with cache and proper labels
docker build \
    --label "org.opencontainers.image.source=https://github.com/${GHCR_NAMESPACE}/DEVSECOPS-HYBRID-CLOUD" \
    --label "org.opencontainers.image.description=FoodHub ${SERVICE} service" \
    --label "org.opencontainers.image.version=${TAG}" \
    --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --cache-from ${IMAGE_NAME}:latest \
    -t ${IMAGE_NAME}:${TAG} \
    -t ${IMAGE_NAME}:latest \
    .

print_green "Image built successfully"

# Step 3: Push image
echo ""
echo "Step 3: Pushing image to GHCR..."
docker push ${IMAGE_NAME}:${TAG}
docker push ${IMAGE_NAME}:latest

print_green "Image pushed successfully"

# Step 4: Verify
echo ""
echo "Step 4: Verifying image..."
docker inspect ${IMAGE_NAME}:${TAG} --format='Image ID: {{.Id}}'

echo ""
echo "=========================================="
echo "🎉 Success!"
echo "=========================================="
echo ""
echo "Image URL: ${IMAGE_NAME}:${TAG}"
echo ""
echo "To pull this image:"
echo "   docker pull ${IMAGE_NAME}:${TAG}"
echo ""
echo "To use in Kubernetes:"
echo "   image: ${IMAGE_NAME}:${TAG}"
echo "=========================================="
