# ============================================
# Outputs
# ============================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.app.name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.app.id
}

output "target_group_arn" {
  description = "Target Group ARN"
  value       = aws_lb_target_group.app.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.app.name
}

# ============================================
# Deployment Info
# ============================================

output "deployment_info" {
  description = "Deployment information"
  value = {
    app_url           = "http://${aws_lb.main.dns_name}"
    health_check_url  = "http://${aws_lb.main.dns_name}/health"
    ecr_repository    = aws_ecr_repository.app.repository_url
    asg_name          = aws_autoscaling_group.app.name
    launch_template   = aws_launch_template.app.id
    aws_region        = var.aws_region
    account_id        = data.aws_caller_identity.current.account_id
  }
}

# ============================================
# CI/CD Variables (for GitHub Actions)
# ============================================

output "github_actions_vars" {
  description = "Variables for GitHub Actions"
  value = {
    AWS_REGION        = var.aws_region
    ECR_REPOSITORY    = aws_ecr_repository.app.repository_url
    ASG_NAME          = aws_autoscaling_group.app.name
    LAUNCH_TEMPLATE_ID = aws_launch_template.app.id
  }
}
