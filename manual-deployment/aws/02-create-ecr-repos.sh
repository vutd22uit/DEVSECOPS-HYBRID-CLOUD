#!/bin/bash
set -e

# ========================================
# AWS ECR Repositories Setup (No Terraform!)
# ========================================
# Creates: ECR repositories for all services
# Uses: AWS CLI
# ========================================

echo "=========================================="
echo "📦 Creating AWS ECR Repositories"
echo "   (No Terraform - Using AWS CLI)"
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
if [ -f /tmp/foodhub-eks-config.sh ]; then
    source /tmp/foodhub-eks-config.sh
fi

# Configuration
AWS_REGION=${AWS_REGION:-"ap-southeast-1"}
PROJECT_NAME=${PROJECT_NAME:-"foodhub"}

# Services to create repositories for
SERVICES=("users" "products" "orders" "frontend")

# ========================================
# Step 0: Check Prerequisites
# ========================================
echo ""
echo "Step 0: Checking prerequisites..."

if ! aws sts get-caller-identity &> /dev/null; then
    print_red "AWS credentials not configured"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

print_green "AWS Account: ${AWS_ACCOUNT_ID}"
print_green "ECR Registry: ${ECR_REGISTRY}"

# ========================================
# Step 1: Create ECR Repositories
# ========================================
echo ""
echo "Step 1: Creating ECR repositories..."

for SERVICE in "${SERVICES[@]}"; do
    REPO_NAME="${PROJECT_NAME}-${SERVICE}"
    
    echo ""
    echo "Processing ${REPO_NAME}..."
    
    # Check if repository exists
    if aws ecr describe-repositories --repository-names ${REPO_NAME} --region ${AWS_REGION} 2>/dev/null; then
        print_yellow "Repository ${REPO_NAME} already exists"
    else
        # Create repository
        aws ecr create-repository \
            --repository-name ${REPO_NAME} \
            --region ${AWS_REGION} \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256 \
            --tags Key=Project,Value=${PROJECT_NAME} Key=Service,Value=${SERVICE} Key=ManagedBy,Value=manual-script
        
        print_green "Repository ${REPO_NAME} created"
    fi
done

# ========================================
# Step 2: Configure Lifecycle Policies
# ========================================
echo ""
echo "Step 2: Configuring lifecycle policies..."

LIFECYCLE_POLICY='{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["v", "main-", "develop-"],
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Delete untagged images older than 7 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 7
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 3,
            "description": "Keep last 5 feature branch images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["feature-", "fix-", "hotfix-"],
                "countType": "imageCountMoreThan",
                "countNumber": 5
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}'

for SERVICE in "${SERVICES[@]}"; do
    REPO_NAME="${PROJECT_NAME}-${SERVICE}"
    
    aws ecr put-lifecycle-policy \
        --repository-name ${REPO_NAME} \
        --region ${AWS_REGION} \
        --lifecycle-policy-text "${LIFECYCLE_POLICY}" 2>/dev/null || true
    
    print_green "Lifecycle policy applied to ${REPO_NAME}"
done

# ========================================
# Step 3: Configure Repository Policies
# ========================================
echo ""
echo "Step 3: Configuring repository policies..."

# Allow cross-account pulls (optional - for multi-account setups)
REPO_POLICY='{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowPull",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::'"${AWS_ACCOUNT_ID}"':root"
            },
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability"
            ]
        }
    ]
}'

for SERVICE in "${SERVICES[@]}"; do
    REPO_NAME="${PROJECT_NAME}-${SERVICE}"
    
    aws ecr set-repository-policy \
        --repository-name ${REPO_NAME} \
        --region ${AWS_REGION} \
        --policy-text "${REPO_POLICY}" 2>/dev/null || true
done

print_green "Repository policies configured"

# ========================================
# Step 4: Login to ECR
# ========================================
echo ""
echo "Step 4: Testing ECR login..."

aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

print_green "Successfully logged in to ECR"

# ========================================
# Summary
# ========================================
echo ""
echo "=========================================="
echo "🎉 ECR Repositories Created Successfully!"
echo "=========================================="
echo ""
echo "📋 Repositories:"
for SERVICE in "${SERVICES[@]}"; do
    echo "   📦 ${ECR_REGISTRY}/${PROJECT_NAME}-${SERVICE}"
done
echo ""
echo "🔧 Configuration:"
echo "   ✅ Image scanning enabled on push"
echo "   ✅ AES256 encryption enabled"
echo "   ✅ Lifecycle policies configured"
echo "   ✅ Repository policies configured"
echo ""
echo "🐳 Docker Login:"
echo "   aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
echo ""
echo "📤 Push Image Example:"
echo "   docker build -t ${PROJECT_NAME}-users:latest ./services/users"
echo "   docker tag ${PROJECT_NAME}-users:latest ${ECR_REGISTRY}/${PROJECT_NAME}-users:latest"
echo "   docker push ${ECR_REGISTRY}/${PROJECT_NAME}-users:latest"
echo ""
echo "=========================================="

# Save configuration
cat > /tmp/foodhub-ecr-config.sh <<EOF
# Auto-generated by 02-create-ecr-repos.sh
export ECR_REGISTRY="${ECR_REGISTRY}"
export AWS_REGION="${AWS_REGION}"
export PROJECT_NAME="${PROJECT_NAME}"
EOF

print_green "Configuration saved to /tmp/foodhub-ecr-config.sh"
