# ============================================================================
# AWS ECS Variables
# ============================================================================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"  # Singapore
}

variable "ecr_repo_name" {
  description = "ECR repository name"
  type        = string
  default     = "prefect-lab"
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "prefect-cluster"
}

variable "task_family" {
  description = "ECS task definition family name"
  type        = string
  default     = "prefect-worker"
}

variable "task_cpu" {
  description = "CPU units for the task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "512"
}

variable "task_memory" {
  description = "Memory for the task in MB"
  type        = string
  default     = "1024"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "prefect_api_url" {
  description = "Prefect API URL (Cloud or self-hosted)"
  type        = string
  default     = "https://api.prefect.cloud/api"
}

variable "prefect_secret_name" {
  description = "Name of existing AWS Secrets Manager secret containing Prefect API key. Create before running terraform."
  type        = string
  default     = "prefect/api-key"
}

variable "subnets" {
  description = "VPC subnets for ECS tasks"
  type        = list(string)
}

variable "security_groups" {
  description = "Security groups for ECS tasks"
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks"
  type        = bool
  default     = true
}

variable "enable_service" {
  description = "Enable ECS service (persistent worker) vs one-off tasks"
  type        = bool
  default     = true
}

variable "desired_count" {
  description = "Number of worker tasks to run"
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "prefect-lab"
    ManagedBy = "Terraform"
  }
}
