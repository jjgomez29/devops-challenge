#!/bin/bash
set -e

# ============================================
# Manual Deploy Script - DevOps Challenge
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Configuration
AWS_REGION="${AWS_REGION:-eu-west-1}"
PROJECT_NAME="devops-challenge"

log "Starting manual deployment..."

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log "AWS Account: $ACCOUNT_ID"

# Get ECR Repository URL
ECR_REPO="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME"
log "ECR Repository: $ECR_REPO"

# Login to ECR
log "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build Docker image
log "Building Docker image..."
cd "$(dirname "$0")/.."
docker build -f docker/Dockerfile -t $PROJECT_NAME:latest .

# Tag image
IMAGE_TAG=$(git rev-parse --short HEAD 2>/dev/null || echo "manual-$(date +%Y%m%d%H%M%S)")
log "Tagging image with: $IMAGE_TAG"
docker tag $PROJECT_NAME:latest $ECR_REPO:$IMAGE_TAG
docker tag $PROJECT_NAME:latest $ECR_REPO:latest

# Push to ECR
log "Pushing image to ECR..."
docker push $ECR_REPO:$IMAGE_TAG
docker push $ECR_REPO:latest

# Get ASG name
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[?contains(AutoScalingGroupName, '$PROJECT_NAME')].AutoScalingGroupName" \
  --output text | head -1)

if [ -z "$ASG_NAME" ]; then
  warn "ASG not found. Infrastructure may not be deployed yet."
  log "Image pushed successfully. Run 'terraform apply' to deploy infrastructure."
  exit 0
fi

log "Starting instance refresh for ASG: $ASG_NAME"

# Start instance refresh
REFRESH_ID=$(aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$ASG_NAME" \
  --preferences '{"MinHealthyPercentage": 50, "InstanceWarmup": 120}' \
  --query 'InstanceRefreshId' \
  --output text)

log "Instance refresh started: $REFRESH_ID"

# Monitor refresh
log "Monitoring instance refresh..."
while true; do
  STATUS=$(aws autoscaling describe-instance-refreshes \
    --auto-scaling-group-name "$ASG_NAME" \
    --instance-refresh-ids "$REFRESH_ID" \
    --query 'InstanceRefreshes[0].Status' \
    --output text)

  PERCENTAGE=$(aws autoscaling describe-instance-refreshes \
    --auto-scaling-group-name "$ASG_NAME" \
    --instance-refresh-ids "$REFRESH_ID" \
    --query 'InstanceRefreshes[0].PercentageComplete' \
    --output text)

  log "Status: $STATUS - Progress: ${PERCENTAGE}%"

  if [ "$STATUS" == "Successful" ]; then
    log "Deployment completed successfully!"
    break
  elif [ "$STATUS" == "Failed" ] || [ "$STATUS" == "Cancelled" ]; then
    error "Deployment failed with status: $STATUS"
  fi

  sleep 15
done

# Get ALB DNS
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName, '$PROJECT_NAME')].DNSName" \
  --output text | head -1)

if [ -n "$ALB_DNS" ]; then
  log "Application URL: http://$ALB_DNS"
  log "Health Check: http://$ALB_DNS/health"

  # Verify health
  sleep 10
  if curl -sf "http://$ALB_DNS/health" > /dev/null 2>&1; then
    log "Health check passed!"
  else
    warn "Health check not responding yet. Please wait a moment and check manually."
  fi
fi

log "Deployment completed!"
