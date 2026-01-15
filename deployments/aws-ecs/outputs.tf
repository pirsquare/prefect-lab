# ============================================================================
# AWS ECS Outputs
# ============================================================================

output "ecr_repository_url" {
  description = "ECR repository URL for pushing images"
  value       = aws_ecr_repository.prefect_worker.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.prefect_worker.arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.prefect.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.prefect.arn
}

output "task_definition_arn" {
  description = "ECS task definition ARN"
  value       = aws_ecs_task_definition.prefect_worker.arn
}

output "task_execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  description = "IAM role ARN for ECS task"
  value       = aws_iam_role.ecs_task.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.prefect_worker.name
}

output "service_name" {
  description = "ECS service name (if enabled)"
  value       = var.enable_service ? aws_ecs_service.prefect_worker[0].name : null
}

output "docker_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.prefect_worker.repository_url}"
}

output "docker_build_push_commands" {
  description = "Commands to build and push Docker image"
  value = <<-EOT
    # Build image
    docker build -t ${var.ecr_repo_name}:${var.image_tag} -f Dockerfile .
    
    # Tag image
    docker tag ${var.ecr_repo_name}:${var.image_tag} ${aws_ecr_repository.prefect_worker.repository_url}:${var.image_tag}
    
    # Push image
    docker push ${aws_ecr_repository.prefect_worker.repository_url}:${var.image_tag}
  EOT
}
