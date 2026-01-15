#!/bin/bash
# AWS ECS Fargate Deployment Script for Prefect Worker
# 
# Prerequisites:
#  - AWS CLI configured with credentials
#  - Docker and docker-compose installed
#  - ECR repository created
#  - ECS cluster and service or launch template configured
#
# Usage:
#   bash deployments/aws-ecs/deploy.sh
#   (Uses .env file from current directory)

set -e

echo "=========================================="
echo "Prefect Worker - AWS ECS Fargate Deployment"
echo "=========================================="

# Load environment variables
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
else
    echo "ERROR: .env file not found. Copy from .env.example and fill in values."
    exit 1
fi

# Validate required variables
REQUIRED_VARS=("AWS_REGION" "AWS_ACCOUNT_ID" "AWS_ECR_REPO" "AWS_ECS_CLUSTER" "AWS_ECS_TASK_FAMILY" "PREFECT_API_URL" "PREFECT_API_KEY")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "ERROR: $var is not set in .env"
        exit 1
    fi
done

AWS_ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_IMAGE_URI="${AWS_ECR_REGISTRY}/${AWS_ECR_REPO}:latest"

echo ""
echo "Configuration:"
echo "  AWS Region: $AWS_REGION"
echo "  ECR Registry: $AWS_ECR_REGISTRY"
echo "  ECR Repository: $AWS_ECR_REPO"
echo "  ECS Cluster: $AWS_ECS_CLUSTER"
echo "  Image URI: $ECR_IMAGE_URI"
echo ""

# Step 1: Login to ECR
echo "[1/5] Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$AWS_ECR_REGISTRY"

# Step 2: Create ECR repository if it doesn't exist
echo "[2/5] Ensuring ECR repository exists..."
aws ecr describe-repositories \
    --repository-names "$AWS_ECR_REPO" \
    --region "$AWS_REGION" \
    2>/dev/null || \
aws ecr create-repository \
    --repository-name "$AWS_ECR_REPO" \
    --region "$AWS_REGION" \
    --image-tag-mutability MUTABLE \
    --image-scanning-configuration scanOnPush=true

# Step 3: Build Docker image
echo "[3/5] Building Docker image..."
docker build -t "${AWS_ECR_REPO}:latest" \
             -t "$ECR_IMAGE_URI" \
             -f Dockerfile .

# Step 4: Push image to ECR
echo "[4/5] Pushing image to ECR..."
docker push "$ECR_IMAGE_URI"

echo "[5/5] Creating/Updating ECS Task Definition..."

# Step 5: Register ECS Task Definition
# NOTE: Customize this JSON based on your actual task requirements
# Adjust CPU, memory, subnets, security groups as needed

TASK_DEFINITION=$(cat <<EOF
{
  "family": "${AWS_ECS_TASK_FAMILY}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "prefect-worker",
      "image": "${ECR_IMAGE_URI}",
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/${AWS_ECS_TASK_FAMILY}",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "environment": [
        {
          "name": "PREFECT_API_URL",
          "value": "${PREFECT_API_URL}"
        },
        {
          "name": "PREFECT_LOGGING_LEVEL",
          "value": "INFO"
        }
      ],
      "secrets": [
        {
          "name": "PREFECT_API_KEY",
          "valueFrom": "arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:prefect/api-key"
        }
      ]
    }
  ]
}
EOF
)

# Register the task definition
aws ecs register-task-definition \
    --region "$AWS_REGION" \
    --cli-input-json "$TASK_DEFINITION"

echo ""
echo "=========================================="
echo "Deployment Successful!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Create CloudWatch log group (if not exists):"
echo "   aws logs create-log-group --log-group-name /ecs/${AWS_ECS_TASK_FAMILY} --region ${AWS_REGION}"
echo ""
echo "2. Store Prefect API key in AWS Secrets Manager:"
echo "   aws secretsmanager create-secret --name prefect/api-key --secret-string '${PREFECT_API_KEY}' --region ${AWS_REGION}"
echo ""
echo "3. Create ECS Service or run one-off task:"
echo "   aws ecs run-task --cluster ${AWS_ECS_CLUSTER} --task-definition ${AWS_ECS_TASK_FAMILY}:1 \\"
echo "       --launch-type FARGATE \\"
echo "       --network-configuration \"awsvpcConfiguration={subnets=[${AWS_SUBNETS}],securityGroups=[${AWS_SECURITY_GROUPS}],assignPublicIp=ENABLED}\" \\"
echo "       --region ${AWS_REGION}"
echo ""
echo "4. In Prefect Cloud, create a work pool:"
echo "   prefect work-pool create --type ecs --set-as-default aws-ecs-pool"
echo ""
echo "5. Deploy flows:"
echo "   prefect deploy --deployment hello-flow-aws-ecs"
echo ""
