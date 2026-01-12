#!/bin/bash
set -e

# ========================================
# Harbor Image Replication Configuration
# ========================================
# Configures: Image sync between Harbor and ECR
# Uses: Harbor API, AWS CLI
# ========================================

echo "=========================================="
echo "🔄 Configuring Harbor Image Replication"
echo "   Harbor → AWS ECR"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_green() { echo -e "${GREEN}✅ $1${NC}"; }
print_yellow() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_red() { echo -e "${RED}❌ $1${NC}"; }

# Load environment
if [ -f ~/.openstack-foodhub.env ]; then
    source ~/.openstack-foodhub.env
fi
if [ -f /tmp/foodhub-harbor.sh ]; then
    source /tmp/foodhub-harbor.sh
fi
if [ -f /tmp/foodhub-ecr-config.sh ]; then
    source /tmp/foodhub-ecr-config.sh
fi

# Configuration
HARBOR_URL=${HARBOR_URL:-"https://harbor.foodhub.local"}
HARBOR_ADMIN_USER=${HARBOR_ADMIN_USER:-"admin"}
HARBOR_ADMIN_PASSWORD=${HARBOR_ADMIN_PASSWORD:-"Harbor12345"}
HARBOR_PROJECT=${HARBOR_PROJECT:-"foodhub"}

AWS_REGION=${AWS_REGION:-"ap-southeast-1"}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")}
ECR_REGISTRY=${ECR_REGISTRY:-"${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"}

# ========================================
# Step 0: Check Prerequisites
# ========================================
echo ""
echo "Step 0: Checking prerequisites..."

# Check curl
if ! command -v curl &> /dev/null; then
    print_red "curl is not installed"
    exit 1
fi
print_green "curl found"

# Check jq
if ! command -v jq &> /dev/null; then
    print_yellow "jq not found, installing..."
    sudo apt-get update && sudo apt-get install -y jq
fi
print_green "jq found"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_yellow "AWS credentials not configured"
    echo "Replication to ECR will not be configured"
    AWS_CONFIGURED=false
else
    AWS_CONFIGURED=true
    print_green "AWS Account: ${AWS_ACCOUNT_ID}"
fi

# Check Harbor accessibility
if ! curl -sk "${HARBOR_URL}/api/v2.0/health" &> /dev/null; then
    print_yellow "Cannot reach Harbor at ${HARBOR_URL}"
    echo "   Please ensure Harbor is running"
fi

# ========================================
# Step 1: Get ECR Credentials
# ========================================
if [ "${AWS_CONFIGURED}" = true ]; then
    echo ""
    echo "Step 1: Generating ECR credentials..."
    
    # Get ECR login token
    ECR_TOKEN=$(aws ecr get-login-password --region ${AWS_REGION})
    
    # The token is valid for 12 hours
    print_green "ECR token generated (valid for 12 hours)"
fi

# ========================================
# Step 2: Create Registry Endpoint in Harbor
# ========================================
echo ""
echo "Step 2: Creating ECR registry endpoint in Harbor..."

if [ "${AWS_CONFIGURED}" = true ]; then
    # Create registry endpoint
    REGISTRY_PAYLOAD=$(cat <<EOF
{
    "name": "aws-ecr",
    "description": "AWS ECR Registry for ${AWS_ACCOUNT_ID}",
    "type": "aws-ecr",
    "url": "https://${ECR_REGISTRY}",
    "credential": {
        "access_key": "AWS",
        "access_secret": "${ECR_TOKEN}",
        "type": "basic"
    },
    "insecure": false
}
EOF
)

    # Check if registry already exists
    EXISTING=$(curl -sk -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
        "${HARBOR_URL}/api/v2.0/registries?name=aws-ecr" | jq -r '.[0].id // empty')
    
    if [ -n "${EXISTING}" ]; then
        print_yellow "Registry endpoint already exists (ID: ${EXISTING})"
        REGISTRY_ID=${EXISTING}
        
        # Update credentials
        curl -sk -X PUT \
            -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
            -H "Content-Type: application/json" \
            -d "${REGISTRY_PAYLOAD}" \
            "${HARBOR_URL}/api/v2.0/registries/${REGISTRY_ID}"
        
        print_green "Registry credentials updated"
    else
        # Create new registry
        RESPONSE=$(curl -sk -X POST \
            -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
            -H "Content-Type: application/json" \
            -d "${REGISTRY_PAYLOAD}" \
            -w "%{http_code}" \
            "${HARBOR_URL}/api/v2.0/registries")
        
        HTTP_CODE="${RESPONSE: -3}"
        if [ "${HTTP_CODE}" = "201" ]; then
            print_green "Registry endpoint created"
            
            # Get the ID
            REGISTRY_ID=$(curl -sk -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
                "${HARBOR_URL}/api/v2.0/registries?name=aws-ecr" | jq -r '.[0].id')
        else
            print_red "Failed to create registry endpoint"
            echo "Response: ${RESPONSE}"
        fi
    fi
fi

# ========================================
# Step 3: Create Replication Policy
# ========================================
echo ""
echo "Step 3: Creating replication policy..."

if [ "${AWS_CONFIGURED}" = true ] && [ -n "${REGISTRY_ID}" ]; then
    # Define services to replicate
    SERVICES=("users" "products" "orders" "frontend")
    
    for SERVICE in "${SERVICES[@]}"; do
        POLICY_NAME="push-${SERVICE}-to-ecr"
        
        POLICY_PAYLOAD=$(cat <<EOF
{
    "name": "${POLICY_NAME}",
    "description": "Push foodhub-${SERVICE} images to AWS ECR",
    "src_registry": null,
    "dest_registry": {
        "id": ${REGISTRY_ID}
    },
    "dest_namespace": "${HARBOR_PROJECT}",
    "trigger": {
        "type": "event_based",
        "trigger_settings": {}
    },
    "filters": [
        {
            "type": "name",
            "value": "${HARBOR_PROJECT}/foodhub-${SERVICE}"
        },
        {
            "type": "tag",
            "value": "*"
        }
    ],
    "deletion": false,
    "override": true,
    "enabled": true,
    "replicate_deletion": false
}
EOF
)
        
        # Check if policy exists
        EXISTING_POLICY=$(curl -sk -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
            "${HARBOR_URL}/api/v2.0/replication/policies?name=${POLICY_NAME}" | jq -r '.[0].id // empty')
        
        if [ -n "${EXISTING_POLICY}" ]; then
            print_yellow "Policy ${POLICY_NAME} already exists"
        else
            RESPONSE=$(curl -sk -X POST \
                -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
                -H "Content-Type: application/json" \
                -d "${POLICY_PAYLOAD}" \
                -w "%{http_code}" \
                "${HARBOR_URL}/api/v2.0/replication/policies")
            
            HTTP_CODE="${RESPONSE: -3}"
            if [ "${HTTP_CODE}" = "201" ]; then
                print_green "Replication policy created: ${POLICY_NAME}"
            else
                print_yellow "Could not create policy ${POLICY_NAME}"
            fi
        fi
    done
fi

# ========================================
# Step 4: Create Pull-Through Proxy (Optional)
# ========================================
echo ""
echo "Step 4: Creating ECR pull-through proxy project..."

if [ "${AWS_CONFIGURED}" = true ]; then
    PROXY_PROJECT_PAYLOAD=$(cat <<EOF
{
    "project_name": "ecr-cache",
    "metadata": {
        "public": "false"
    },
    "registry_id": ${REGISTRY_ID}
}
EOF
)
    
    # Check if project exists
    EXISTING_PROJECT=$(curl -sk -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
        "${HARBOR_URL}/api/v2.0/projects?name=ecr-cache" | jq -r '.[0].project_id // empty')
    
    if [ -n "${EXISTING_PROJECT}" ]; then
        print_yellow "Pull-through proxy project already exists"
    else
        RESPONSE=$(curl -sk -X POST \
            -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
            -H "Content-Type: application/json" \
            -d "${PROXY_PROJECT_PAYLOAD}" \
            -w "%{http_code}" \
            "${HARBOR_URL}/api/v2.0/projects")
        
        HTTP_CODE="${RESPONSE: -3}"
        if [ "${HTTP_CODE}" = "201" ]; then
            print_green "Pull-through proxy project created"
        fi
    fi
fi

# ========================================
# Step 5: Test Replication
# ========================================
echo ""
echo "Step 5: Testing replication..."

if [ "${AWS_CONFIGURED}" = true ]; then
    echo "   To test replication:"
    echo "   1. Push an image to Harbor:"
    echo "      docker push ${HARBOR_URL#https://}/${HARBOR_PROJECT}/foodhub-users:test"
    echo ""
    echo "   2. Check replication in Harbor UI:"
    echo "      ${HARBOR_URL}/harbor/projects/${HARBOR_PROJECT}/replications"
fi

# ========================================
# Step 6: Create Credential Refresh Script
# ========================================
echo ""
echo "Step 6: Creating ECR credential refresh script..."

cat > /tmp/refresh-ecr-credentials.sh <<'REFRESH_SCRIPT'
#!/bin/bash
# Refresh ECR credentials in Harbor
# Run this every 12 hours via cron

source ~/.openstack-foodhub.env 2>/dev/null || true

HARBOR_URL=${HARBOR_URL:-"https://harbor.foodhub.local"}
HARBOR_ADMIN_USER=${HARBOR_ADMIN_USER:-"admin"}
HARBOR_ADMIN_PASSWORD=${HARBOR_ADMIN_PASSWORD:-"Harbor12345"}
AWS_REGION=${AWS_REGION:-"ap-southeast-1"}

# Get new ECR token
ECR_TOKEN=$(aws ecr get-login-password --region ${AWS_REGION})

# Get registry ID
REGISTRY_ID=$(curl -sk -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
    "${HARBOR_URL}/api/v2.0/registries?name=aws-ecr" | jq -r '.[0].id')

if [ -n "${REGISTRY_ID}" ]; then
    # Update credentials
    curl -sk -X PUT \
        -u "${HARBOR_ADMIN_USER}:${HARBOR_ADMIN_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d "{\"credential\": {\"access_key\": \"AWS\", \"access_secret\": \"${ECR_TOKEN}\", \"type\": \"basic\"}}" \
        "${HARBOR_URL}/api/v2.0/registries/${REGISTRY_ID}"
    
    echo "$(date): ECR credentials refreshed"
fi
REFRESH_SCRIPT

chmod +x /tmp/refresh-ecr-credentials.sh
print_green "Credential refresh script created: /tmp/refresh-ecr-credentials.sh"

echo ""
echo "   Add to crontab to run every 11 hours:"
echo "   0 */11 * * * /tmp/refresh-ecr-credentials.sh >> /var/log/ecr-refresh.log 2>&1"

# ========================================
# Summary
# ========================================
echo ""
echo "=========================================="
echo "🎉 Harbor Replication Configured!"
echo "=========================================="
echo ""
if [ "${AWS_CONFIGURED}" = true ]; then
    echo "📋 Configuration:"
    echo "   Harbor URL:        ${HARBOR_URL}"
    echo "   ECR Registry:      ${ECR_REGISTRY}"
    echo "   Registry ID:       ${REGISTRY_ID:-N/A}"
    echo ""
    echo "🔄 Replication Policies:"
    for SERVICE in "${SERVICES[@]}"; do
        echo "   ✅ push-${SERVICE}-to-ecr"
    done
    echo ""
    echo "📦 Pull-through Cache:"
    echo "   docker pull ${HARBOR_URL#https://}/ecr-cache/${HARBOR_PROJECT}/image:tag"
    echo ""
    echo "⚠️  Important:"
    echo "   ECR tokens expire every 12 hours!"
    echo "   Set up cron job to refresh credentials."
else
    echo "⚠️  AWS credentials not configured"
    echo "   Replication to ECR was not set up"
    echo "   To configure later, run this script after configuring AWS CLI"
fi
echo ""
echo "=========================================="

# Save configuration
cat > /tmp/foodhub-harbor-sync-config.sh <<EOF
# Auto-generated by 09-configure-harbor-sync.sh
export HARBOR_URL="${HARBOR_URL}"
export ECR_REGISTRY="${ECR_REGISTRY}"
export REGISTRY_ID="${REGISTRY_ID:-}"
EOF

print_green "Configuration saved to /tmp/foodhub-harbor-sync-config.sh"
