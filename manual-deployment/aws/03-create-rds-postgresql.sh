#!/bin/bash
set -e

# ========================================
# AWS RDS PostgreSQL Setup (No Terraform!)
# ========================================
# Creates: RDS PostgreSQL for microservices
# Uses: AWS CLI
# ========================================

echo "=========================================="
echo "🗄️  Creating AWS RDS PostgreSQL"
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
DB_INSTANCE_ID="${PROJECT_NAME}-postgresql"
DB_INSTANCE_CLASS=${DB_INSTANCE_CLASS:-"db.t3.micro"}
DB_ENGINE="postgres"
DB_ENGINE_VERSION="15.4"
DB_ALLOCATED_STORAGE=20
DB_MAX_STORAGE=100
DB_NAME="foodhub"
DB_USERNAME="foodhub_admin"
DB_PASSWORD=${DB_PASSWORD:-"FoodHub2024!Secure"}

# Get VPC ID from EKS cluster
if [ -z "${EKS_VPC_ID}" ]; then
    EKS_VPC_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME:-foodhub-eks} --region ${AWS_REGION} --query "cluster.resourcesVpcConfig.vpcId" --output text 2>/dev/null || echo "")
fi

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
print_green "AWS Account: ${AWS_ACCOUNT_ID}"

if [ -z "${EKS_VPC_ID}" ]; then
    print_red "VPC ID not found. Please run 01-create-eks-cluster.sh first or set EKS_VPC_ID"
    exit 1
fi
print_green "VPC ID: ${EKS_VPC_ID}"

# ========================================
# Step 1: Get Private Subnets
# ========================================
echo ""
echo "Step 1: Getting private subnets..."

PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=${EKS_VPC_ID}" \
    --query 'Subnets[?MapPublicIpOnLaunch==`false`].SubnetId' \
    --output text --region ${AWS_REGION})

if [ -z "${PRIVATE_SUBNETS}" ]; then
    print_yellow "No private subnets found, using all subnets"
    PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${EKS_VPC_ID}" \
        --query 'Subnets[].SubnetId' \
        --output text --region ${AWS_REGION})
fi

SUBNET_ARRAY=(${PRIVATE_SUBNETS})
print_green "Found ${#SUBNET_ARRAY[@]} subnets"

# ========================================
# Step 2: Create DB Subnet Group
# ========================================
echo ""
echo "Step 2: Creating DB subnet group..."

DB_SUBNET_GROUP="${PROJECT_NAME}-db-subnet-group"

if aws rds describe-db-subnet-groups --db-subnet-group-name ${DB_SUBNET_GROUP} --region ${AWS_REGION} 2>/dev/null; then
    print_yellow "DB Subnet Group already exists"
else
    aws rds create-db-subnet-group \
        --db-subnet-group-name ${DB_SUBNET_GROUP} \
        --db-subnet-group-description "Subnet group for ${PROJECT_NAME} RDS" \
        --subnet-ids ${PRIVATE_SUBNETS} \
        --region ${AWS_REGION} \
        --tags Key=Project,Value=${PROJECT_NAME}
    
    print_green "DB Subnet Group created"
fi

# ========================================
# Step 3: Create Security Group
# ========================================
echo ""
echo "Step 3: Creating security group for RDS..."

RDS_SG_NAME="${PROJECT_NAME}-rds-sg"

# Check if security group exists
RDS_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=${EKS_VPC_ID}" "Name=group-name,Values=${RDS_SG_NAME}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text --region ${AWS_REGION} 2>/dev/null || echo "None")

if [ "${RDS_SG_ID}" != "None" ] && [ -n "${RDS_SG_ID}" ]; then
    print_yellow "Security Group already exists: ${RDS_SG_ID}"
else
    # Create security group
    RDS_SG_ID=$(aws ec2 create-security-group \
        --group-name ${RDS_SG_NAME} \
        --description "Security group for ${PROJECT_NAME} RDS PostgreSQL" \
        --vpc-id ${EKS_VPC_ID} \
        --region ${AWS_REGION} \
        --query 'GroupId' \
        --output text)
    
    # Add ingress rule for PostgreSQL from VPC
    VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids ${EKS_VPC_ID} --query 'Vpcs[0].CidrBlock' --output text --region ${AWS_REGION})
    
    aws ec2 authorize-security-group-ingress \
        --group-id ${RDS_SG_ID} \
        --protocol tcp \
        --port 5432 \
        --cidr ${VPC_CIDR} \
        --region ${AWS_REGION}
    
    # Also allow from OpenStack network (for hybrid cloud)
    aws ec2 authorize-security-group-ingress \
        --group-id ${RDS_SG_ID} \
        --protocol tcp \
        --port 5432 \
        --cidr "10.0.0.0/16" \
        --region ${AWS_REGION} 2>/dev/null || true
    
    # Add tags
    aws ec2 create-tags \
        --resources ${RDS_SG_ID} \
        --tags Key=Name,Value=${RDS_SG_NAME} Key=Project,Value=${PROJECT_NAME} \
        --region ${AWS_REGION}
    
    print_green "Security Group created: ${RDS_SG_ID}"
fi

# ========================================
# Step 4: Create RDS Instance
# ========================================
echo ""
echo "Step 4: Creating RDS PostgreSQL instance..."

# Check if instance exists
if aws rds describe-db-instances --db-instance-identifier ${DB_INSTANCE_ID} --region ${AWS_REGION} 2>/dev/null; then
    print_yellow "RDS instance already exists"
    
    # Get endpoint
    DB_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier ${DB_INSTANCE_ID} \
        --region ${AWS_REGION} \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text)
else
    echo "   This will take 5-10 minutes..."
    
    aws rds create-db-instance \
        --db-instance-identifier ${DB_INSTANCE_ID} \
        --db-instance-class ${DB_INSTANCE_CLASS} \
        --engine ${DB_ENGINE} \
        --engine-version ${DB_ENGINE_VERSION} \
        --allocated-storage ${DB_ALLOCATED_STORAGE} \
        --max-allocated-storage ${DB_MAX_STORAGE} \
        --db-name ${DB_NAME} \
        --master-username ${DB_USERNAME} \
        --master-user-password ${DB_PASSWORD} \
        --vpc-security-group-ids ${RDS_SG_ID} \
        --db-subnet-group-name ${DB_SUBNET_GROUP} \
        --backup-retention-period 7 \
        --preferred-backup-window "03:00-04:00" \
        --preferred-maintenance-window "Mon:04:00-Mon:05:00" \
        --storage-type gp3 \
        --storage-encrypted \
        --no-publicly-accessible \
        --no-auto-minor-version-upgrade \
        --copy-tags-to-snapshot \
        --deletion-protection \
        --tags Key=Name,Value=${DB_INSTANCE_ID} Key=Project,Value=${PROJECT_NAME} Key=Environment,Value=production \
        --region ${AWS_REGION}
    
    print_green "RDS instance creation initiated"
    
    # Wait for instance to be available
    echo ""
    echo "⏳ Waiting for RDS instance to be available..."
    aws rds wait db-instance-available \
        --db-instance-identifier ${DB_INSTANCE_ID} \
        --region ${AWS_REGION}
    
    print_green "RDS instance is now available"
    
    # Get endpoint
    DB_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier ${DB_INSTANCE_ID} \
        --region ${AWS_REGION} \
        --query 'DBInstances[0].Endpoint.Address' \
        --output text)
fi

# ========================================
# Step 5: Create Additional Databases
# ========================================
echo ""
echo "Step 5: Creating additional databases..."
echo "   (You may need to run SQL commands manually)"

cat > /tmp/create-databases.sql <<EOF
-- FoodHub Microservices Databases
-- Run this script after RDS is ready

-- Create databases for each service
CREATE DATABASE IF NOT EXISTS foodhub_users;
CREATE DATABASE IF NOT EXISTS foodhub_products;
CREATE DATABASE IF NOT EXISTS foodhub_orders;

-- Create service users
CREATE USER IF NOT EXISTS 'users_svc'@'%' IDENTIFIED BY 'users_password_123';
CREATE USER IF NOT EXISTS 'products_svc'@'%' IDENTIFIED BY 'products_password_123';
CREATE USER IF NOT EXISTS 'orders_svc'@'%' IDENTIFIED BY 'orders_password_123';

-- Grant privileges
GRANT ALL PRIVILEGES ON foodhub_users.* TO 'users_svc'@'%';
GRANT ALL PRIVILEGES ON foodhub_products.* TO 'products_svc'@'%';
GRANT ALL PRIVILEGES ON foodhub_orders.* TO 'orders_svc'@'%';

FLUSH PRIVILEGES;
EOF

print_green "SQL script saved to /tmp/create-databases.sql"

# ========================================
# Summary
# ========================================
echo ""
echo "=========================================="
echo "🎉 RDS PostgreSQL Created Successfully!"
echo "=========================================="
echo ""
echo "📋 Instance Details:"
echo "   Instance ID:    ${DB_INSTANCE_ID}"
echo "   Engine:         PostgreSQL ${DB_ENGINE_VERSION}"
echo "   Instance Class: ${DB_INSTANCE_CLASS}"
echo "   Storage:        ${DB_ALLOCATED_STORAGE}GB (max: ${DB_MAX_STORAGE}GB)"
echo ""
echo "🔗 Connection Info:"
echo "   Endpoint:       ${DB_ENDPOINT}"
echo "   Port:           5432"
echo "   Database:       ${DB_NAME}"
echo "   Username:       ${DB_USERNAME}"
echo ""
echo "🔐 Security:"
echo "   ✅ Encrypted at rest"
echo "   ✅ Not publicly accessible"
echo "   ✅ Deletion protection enabled"
echo "   ✅ Daily backups (7 days retention)"
echo ""
echo "📖 Connection String (for services):"
echo "   jdbc:postgresql://${DB_ENDPOINT}:5432/${DB_NAME}"
echo ""
echo "🔑 Create Kubernetes Secret:"
cat <<EOF
kubectl create secret generic rds-credentials \\
    --from-literal=host=${DB_ENDPOINT} \\
    --from-literal=port=5432 \\
    --from-literal=database=${DB_NAME} \\
    --from-literal=username=${DB_USERNAME} \\
    --from-literal=password=${DB_PASSWORD} \\
    -n foodhub
EOF
echo ""
echo "=========================================="

# Save configuration
cat > /tmp/foodhub-rds-config.sh <<EOF
# Auto-generated by 03-create-rds-postgresql.sh
export DB_INSTANCE_ID="${DB_INSTANCE_ID}"
export DB_ENDPOINT="${DB_ENDPOINT}"
export DB_PORT="5432"
export DB_NAME="${DB_NAME}"
export DB_USERNAME="${DB_USERNAME}"
export RDS_SG_ID="${RDS_SG_ID}"
EOF

print_green "Configuration saved to /tmp/foodhub-rds-config.sh"
