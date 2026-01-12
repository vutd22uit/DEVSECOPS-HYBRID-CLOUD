#!/bin/bash
set -e

echo "=========================================="
echo "Setup Harbor <-> ECR Image Synchronization"
echo "=========================================="

# Configuration
HARBOR_URL="${1:-http://HARBOR_IP}"
HARBOR_USER="${2:-admin}"
HARBOR_PASSWORD="${3:-FoodHub@2025}"
AWS_REGION="${4:-ap-southeast-1}"
AWS_ACCOUNT_ID="${5:-257394468168}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "📋 Configuration:"
echo "  Harbor URL: ${HARBOR_URL}"
echo "  Harbor User: ${HARBOR_USER}"
echo "  AWS Region: ${AWS_REGION}"
echo "  ECR Registry: ${ECR_REGISTRY}"
echo ""

# Check Harbor is accessible
echo "🔍 Checking Harbor accessibility..."
if curl -sf "${HARBOR_URL}/api/v2.0/health" > /dev/null; then
    echo "✅ Harbor is accessible"
else
    echo "❌ Harbor is not accessible at ${HARBOR_URL}"
    exit 1
fi

# Login to Harbor
echo "🔑 Logging into Harbor..."
docker login ${HARBOR_URL} -u ${HARBOR_USER} -p ${HARBOR_PASSWORD}

# Create Harbor project
echo "📦 Creating Harbor project 'foodhub'..."
curl -X POST "${HARBOR_URL}/api/v2.0/projects" \
  -H "Content-Type: application/json" \
  -u "${HARBOR_USER}:${HARBOR_PASSWORD}" \
  -d '{
    "project_name": "foodhub",
    "public": false,
    "metadata": {
      "auto_scan": "true",
      "severity": "high"
    }
  }' || echo "Project may already exist"

# Get AWS ECR credentials
echo "🔑 Getting AWS ECR credentials..."
AWS_ECR_PASSWORD=$(aws ecr get-login-password --region ${AWS_REGION})

# Create ECR registry endpoint in Harbor
echo "🔗 Creating ECR registry endpoint in Harbor..."
curl -X POST "${HARBOR_URL}/api/v2.0/registries" \
  -H "Content-Type: application/json" \
  -u "${HARBOR_USER}:${HARBOR_PASSWORD}" \
  -d "{
    \"name\": \"AWS-ECR\",
    \"type\": \"aws-ecr\",
    \"url\": \"https://${ECR_REGISTRY}\",
    \"credential\": {
      \"access_key\": \"AWS\",
      \"access_secret\": \"${AWS_ECR_PASSWORD}\",
      \"type\": \"basic\"
    },
    \"insecure\": false
  }" || echo "Registry endpoint may already exist"

# Get registry ID
REGISTRY_ID=$(curl -s "${HARBOR_URL}/api/v2.0/registries" \
  -u "${HARBOR_USER}:${HARBOR_PASSWORD}" | \
  jq -r '.[] | select(.name=="AWS-ECR") | .id')

echo "📋 Registry ID: ${REGISTRY_ID}"

# Create replication rules for each service
SERVICES=("users" "products" "orders" "frontend")

for SERVICE in "${SERVICES[@]}"; do
  echo ""
  echo "🔄 Creating replication rule for ${SERVICE}..."

  # Harbor -> ECR (Push)
  curl -X POST "${HARBOR_URL}/api/v2.0/replication/policies" \
    -H "Content-Type: application/json" \
    -u "${HARBOR_USER}:${HARBOR_PASSWORD}" \
    -d "{
      \"name\": \"harbor-to-ecr-${SERVICE}\",
      \"description\": \"Replicate ${SERVICE} images from Harbor to AWS ECR\",
      \"src_registry\": null,
      \"dest_registry\": {
        \"id\": ${REGISTRY_ID}
      },
      \"dest_namespace\": \"foodhub-${SERVICE}\",
      \"dest_namespace_replace_count\": -1,
      \"trigger\": {
        \"type\": \"event_based\"
      },
      \"filters\": [
        {
          \"type\": \"name\",
          \"value\": \"foodhub/foodhub-${SERVICE}\"
        },
        {
          \"type\": \"tag\",
          \"value\": \"**\"
        }
      ],
      \"deletion\": false,
      \"override\": true,
      \"enabled\": true,
      \"speed\": -1
    }" || echo "Replication policy may already exist"

  # ECR -> Harbor (Pull) - Optional for backup
  curl -X POST "${HARBOR_URL}/api/v2.0/replication/policies" \
    -H "Content-Type: application/json" \
    -u "${HARBOR_USER}:${HARBOR_PASSWORD}" \
    -d "{
      \"name\": \"ecr-to-harbor-${SERVICE}\",
      \"description\": \"Replicate ${SERVICE} images from AWS ECR to Harbor\",
      \"src_registry\": {
        \"id\": ${REGISTRY_ID}
      },
      \"dest_registry\": null,
      \"dest_namespace\": \"foodhub\",
      \"trigger\": {
        \"type\": \"manual\"
      },
      \"filters\": [
        {
          \"type\": \"name\",
          \"value\": \"foodhub-${SERVICE}\"
        },
        {
          \"type\": \"tag\",
          \"value\": \"**\"
        }
      ],
      \"deletion\": false,
      \"override\": true,
      \"enabled\": true,
      \"speed\": -1
    }" || echo "Replication policy may already exist"
done

echo ""
echo "=========================================="
echo "✅ Harbor <-> ECR Sync Setup Complete!"
echo "=========================================="
echo ""
echo "📋 Summary:"
echo "  - Harbor Project: foodhub"
echo "  - ECR Registry Endpoint: AWS-ECR"
echo "  - Replication Rules: ${#SERVICES[@]} services (bidirectional)"
echo ""
echo "🔄 Replication Triggers:"
echo "  - Harbor -> ECR: Automatic (on push to Harbor)"
echo "  - ECR -> Harbor: Manual (for backup/disaster recovery)"
echo ""
echo "🌐 Access Harbor UI:"
echo "  URL: ${HARBOR_URL}"
echo "  User: ${HARBOR_USER}"
echo "  Password: ${HARBOR_PASSWORD}"
echo ""
echo "  Navigate to: Administration -> Replications"
echo "  to view and manage replication policies"
echo "=========================================="
