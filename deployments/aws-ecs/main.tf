# ============================================================================
# AWS ECS Fargate Infrastructure for Prefect Worker
# ============================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================================
# ECR Repository
# ============================================================================

resource "aws_ecr_repository" "prefect_worker" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# ============================================================================
# CloudWatch Log Group
# ============================================================================

resource "aws_cloudwatch_log_group" "prefect_worker" {
  name              = "/ecs/${var.task_family}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ============================================================================
# Reference existing Secrets Manager secret for Prefect API Key
# Create the secret manually before running terraform:
#   aws secretsmanager create-secret --name prefect/api-key \
#     --secret-string "your-api-key" --region us-east-1
# ============================================================================

data "aws_secretsmanager_secret" "prefect_api_key" {
  name = var.prefect_secret_name
}

data "aws_secretsmanager_secret_version" "prefect_api_key" {
  secret_id = data.aws_secretsmanager_secret.prefect_api_key.id
}

# ============================================================================
# IAM Roles
# ============================================================================

# ECS Task Execution Role (pulls image, reads secrets, writes logs)
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.task_family}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow reading secrets
resource "aws_iam_role_policy" "ecs_secrets_access" {
  name = "secrets-access"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        data.aws_secretsmanager_secret.prefect_api_key.arn
      ]
    }]
  })
}

# ECS Task Role (permissions for running container)
resource "aws_iam_role" "ecs_task" {
  name = "${var.task_family}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

# ============================================================================
# ECS Cluster
# ============================================================================

resource "aws_ecs_cluster" "prefect" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

# ============================================================================
# ECS Task Definition
# ============================================================================

resource "aws_ecs_task_definition" "prefect_worker" {
  family                   = var.task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "prefect-worker"
    image = "${aws_ecr_repository.prefect_worker.repository_url}:${var.image_tag}"

    essential = true

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.prefect_worker.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    environment = [
      {
        name  = "PREFECT_API_URL"
        value = var.prefect_api_url
      },
      {
        name  = "PREFECT_LOGGING_LEVEL"
        value = "INFO"
      }
    ]

    secrets = [
      {
        name      = "PREFECT_API_KEY"
        valueFrom = data.aws_secretsmanager_secret.prefect_api_key.arn
      }
    ]

    healthCheck = {
      command     = ["CMD-SHELL", "prefect version || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])

  tags = var.tags
}

# ============================================================================
# ECS Service (optional - runs worker as persistent service)
# ============================================================================

resource "aws_ecs_service" "prefect_worker" {
  count = var.enable_service ? 1 : 0

  name            = "${var.task_family}-service"
  cluster         = aws_ecs_cluster.prefect.id
  task_definition = aws_ecs_task_definition.prefect_worker.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_groups
    assign_public_ip = var.assign_public_ip
  }

  tags = var.tags
}
