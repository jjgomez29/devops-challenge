#!/bin/bash
set -e

# ============================================
# Cleanup Script - DevOps Challenge
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
AWS_REGION="${AWS_REGION:-eu-west-1}"
PROJECT_NAME="devops-challenge"

echo ""
echo "=========================================="
echo "  DevOps Challenge - Cleanup Script"
echo "=========================================="
echo ""

warn "This will destroy ALL resources created for $PROJECT_NAME"
warn "This action is IRREVERSIBLE!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  log "Cleanup cancelled."
  exit 0
fi

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [ -z "$ACCOUNT_ID" ]; then
  error "Could not get AWS Account ID. Check your credentials."
  exit 1
fi

log "AWS Account: $ACCOUNT_ID"
log "Region: $AWS_REGION"

# 1. Delete ECR images
log "Cleaning ECR images..."
ECR_REPO="$PROJECT_NAME"

# Get all image IDs
IMAGES=$(aws ecr list-images \
  --repository-name $ECR_REPO \
  --query 'imageIds[*]' \
  --output json 2>/dev/null || echo "[]")

if [ "$IMAGES" != "[]" ] && [ -n "$IMAGES" ]; then
  log "Deleting ECR images..."
  aws ecr batch-delete-image \
    --repository-name $ECR_REPO \
    --image-ids "$IMAGES" 2>/dev/null || warn "Could not delete ECR images"
else
  log "No ECR images to delete"
fi

# 2. Destroy Terraform infrastructure
log "Destroying Terraform infrastructure..."
cd "$(dirname "$0")/../terraform"

if [ -f "terraform.tfstate" ] || [ -d ".terraform" ]; then
  terraform init -input=false 2>/dev/null || true
  terraform destroy -auto-approve
else
  warn "Terraform state not found. Skipping terraform destroy."
fi

# 3. Clean local Docker images
log "Cleaning local Docker images..."
docker rmi $PROJECT_NAME:latest 2>/dev/null || true
docker rmi $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME:latest 2>/dev/null || true

# Remove dangling images
docker image prune -f 2>/dev/null || true

log ""
log "=========================================="
log "  Cleanup completed!"
log "=========================================="
log ""
log "Resources destroyed:"
log "  - ECR images"
log "  - VPC and networking"
log "  - ALB and Target Groups"
log "  - Auto Scaling Group and EC2 instances"
log "  - Security Groups"
log "  - IAM Roles"
log "  - CloudWatch Log Groups"
log "  - Local Docker images"
log ""
