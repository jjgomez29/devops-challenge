#!/bin/bash
set -ex

# ============================================
# EC2 User Data Script - DevOps Challenge
# ============================================

# Variables from Terraform template
AWS_REGION="${aws_region}"
ECR_REPO="${ecr_repo}"
APP_PORT="${app_port}"
PROJECT_NAME="${project_name}"
LOG_GROUP="${log_group_name}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting EC2 bootstrap..."

# ============================================
# Install Docker
# ============================================
log "Installing Docker..."
dnf update -y
dnf install -y docker

systemctl start docker
systemctl enable docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# ============================================
# Install CloudWatch Agent
# ============================================
log "Installing CloudWatch Agent..."
dnf install -y amazon-cloudwatch-agent

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWCONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/docker-app.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CWCONFIG

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# ============================================
# Login to ECR
# ============================================
log "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(echo $ECR_REPO | cut -d'/' -f1)

# ============================================
# Pull and Run Docker Container
# ============================================
log "Pulling Docker image..."
docker pull $ECR_REPO:latest || {
    log "Warning: Could not pull image, may not exist yet"
    exit 0
}

log "Stopping existing container if running..."
docker stop $PROJECT_NAME 2>/dev/null || true
docker rm $PROJECT_NAME 2>/dev/null || true

log "Starting Docker container..."
docker run -d \
    --name $PROJECT_NAME \
    --restart unless-stopped \
    -p $APP_PORT:$APP_PORT \
    -e NODE_ENV=production \
    -e PORT=$APP_PORT \
    --log-driver=awslogs \
    --log-opt awslogs-region=$AWS_REGION \
    --log-opt awslogs-group=$LOG_GROUP \
    --log-opt awslogs-stream=$(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
    $ECR_REPO:latest

# ============================================
# Health Check
# ============================================
log "Waiting for application to start..."
sleep 10

for i in {1..30}; do
    if curl -sf http://localhost:$APP_PORT/health > /dev/null 2>&1; then
        log "Application is healthy!"
        break
    fi
    log "Waiting for health check... attempt $i/30"
    sleep 5
done

# ============================================
# Create update script for deployments
# ============================================
cat > /usr/local/bin/update-app.sh << 'UPDATESCRIPT'
#!/bin/bash
set -e

AWS_REGION="${aws_region}"
ECR_REPO="${ecr_repo}"
PROJECT_NAME="${project_name}"
APP_PORT="${app_port}"
LOG_GROUP="${log_group_name}"

echo "Updating application..."

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(echo $ECR_REPO | cut -d'/' -f1)

# Pull latest image
docker pull $ECR_REPO:latest

# Stop and remove old container
docker stop $PROJECT_NAME 2>/dev/null || true
docker rm $PROJECT_NAME 2>/dev/null || true

# Start new container
docker run -d \
    --name $PROJECT_NAME \
    --restart unless-stopped \
    -p $APP_PORT:$APP_PORT \
    -e NODE_ENV=production \
    -e PORT=$APP_PORT \
    --log-driver=awslogs \
    --log-opt awslogs-region=$AWS_REGION \
    --log-opt awslogs-group=$LOG_GROUP \
    --log-opt awslogs-stream=$(curl -s http://169.254.169.254/latest/meta-data/instance-id) \
    $ECR_REPO:latest

echo "Application updated successfully!"
UPDATESCRIPT

chmod +x /usr/local/bin/update-app.sh

log "EC2 bootstrap completed successfully!"
