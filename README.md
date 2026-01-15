# Prefect Lab: Production-Ready Workflow Orchestration

A minimal, copy-pasteable Prefect v3 setup with local Docker development and multi-cloud deployment templates (AWS ECS, GCP Cloud Run, Azure Container Apps).

**Key Features:**
- ✅ Self-hosted Prefect Server by default (local, no cloud account required)
- ✅ Optional Prefect Cloud integration (for remote orchestration)
- ✅ **Secure secret management** (no API keys in Terraform files or Git)
- ✅ Example flow with schedules, retries, and structured logging
- ✅ Multi-cloud deployment with Terraform (AWS, GCP, Azure)
- ✅ Windows-friendly (Docker Desktop + PowerShell/Bash support)
- ✅ No Kubernetes required

---

## Security Best Practices

**🔒 This project follows security-first principles:**

1. **No API Keys in Code or Config Files**
   - API keys are NEVER stored in `terraform.tfvars` or committed to Git
   - All cloud deployments use native secret management services
   
2. **Cloud-Native Secret Managers**
   - **AWS**: Secrets Manager (referenced, not created by Terraform)
   - **GCP**: Secret Manager (created manually, referenced by Terraform)
   - **Azure**: Container App secrets (set via CLI after deployment)
   
3. **Local Development**
   - Self-hosted server by default (no API keys needed)
   - `.env` file excluded from Git via `.gitignore`
   
4. **Terraform State Security**
   - Always use remote state (S3, GCS, Azure Blob) for production
   - Never commit `terraform.tfstate` files (excluded in `.gitignore`)

---

## Quick Start: Local Development (Windows)

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop) installed and running
- Windows PowerShell or Git Bash
- No external cloud account required (self-hosted by default)

### 1. Clone & Setup Environment

```powershell
# Clone the repository
git clone https://github.com/pirsquare/prefect-lab.git
cd prefect-lab

# Copy example environment file
Copy-Item .env.example .env
```

The `.env` file is pre-configured for self-hosted Prefect Server (no secrets needed for local dev).

### 2. Start Local Stack (Server + Worker via Docker Compose)

```powershell
# Start both Prefect Server and Worker
docker-compose up -d

# Verify both are running
docker-compose ps
```

You should see both containers running:
```
NAME                    STATUS
prefect-server          Up (healthy)
prefect-worker-dev      Up
```

Access the Prefect UI at **http://localhost:4200** (no login required for local dev)

### 3. Create Work Pool & Deploy Flow

In PowerShell or Bash (not in container):

```bash
# Install Prefect CLI locally (if not already)
pip install prefect>=3.0.0

# Create a local work pool (for development)
prefect work-pool create --type docker default

# Deploy using prefect.yaml configuration
prefect deploy
```

Expected output:
```
Created work pool 'default' (type: docker)
Deployment 'hello-flow-local' deployed successfully
```

This reads the deployment configuration from `deployments/prefect.yaml` and deploys all defined deployments to their respective work pools.

### Trigger a Flow Run

```bash
# Via CLI
prefect deployment run hello-flow-local

# Or via Prefect UI at http://localhost:4200
```

### Redeploy After Changes

If you modify `flows/hello_flow.py` or `deployments/prefect.yaml`:

```bash
# Redeploy using updated configuration
prefect deploy
```

### 5. View Logs & Results

**In Prefect UI (http://localhost:4200):**
- Navigate to **Deployments** → **hello-flow-local**
- Click a run to see logs, tasks, and retry details

**In Docker logs:**
```powershell
docker-compose logs prefect-worker -f
```

---

## Switch to Prefect Cloud (Optional)

To use Prefect Cloud instead of self-hosted:

1. **Create Prefect Cloud account** at [app.prefect.cloud](https://app.prefect.cloud)
2. **Get API key** from https://app.prefect.cloud/my/profile/api-keys
3. **Update `.env`:**

```env
# Comment out self-hosted settings
# PREFECT_API_URL=http://prefect-server:4200/api
# PREFECT_PROFILE=self-hosted

# Uncomment and add Cloud settings
PREFECT_API_URL=https://api.prefect.cloud/api
PREFECT_PROFILE=cloud
PREFECT_API_KEY=your-prefect-cloud-api-key-here
```

4. **Restart worker:**

```powershell
docker-compose down
docker-compose up -d prefect-worker  # Skip server container
```

---

## File Structure

```
prefect-lab/
├── flows/
│   └── hello_flow.py             # Example ETL flow (retries, logging)
├── deployments/
│   ├── prefect.yaml              # Deployment configurations (all targets)
│   ├── aws-ecs/
│   │   ├── main.tf               # Terraform: AWS ECS infrastructure
│   │   ├── variables.tf          # Terraform: variable definitions
│   │   ├── outputs.tf            # Terraform: outputs
│   │   └── terraform.tfvars.example  # Example variables
│   ├── gcp-cloudrun/
│   │   ├── main.tf               # Terraform: GCP Cloud Run infrastructure
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   └── azure-containerapps/
│       ├── main.tf               # Terraform: Azure Container Apps infrastructure
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
├── Dockerfile                    # Container image for flows & workers
├── docker-compose.yml            # Local dev environment
├── requirements.txt              # Python dependencies
├── .env.example                  # Environment variable template
└── README.md                     # This file
```

---

## Deploy to AWS ECS (Fargate)

All cloud deployments now use **Terraform** for infrastructure-as-code management.

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0 installed
- AWS account with ECR, ECS, and Secrets Manager access
- AWS CLI configured locally (`aws configure`)
- Prefect Cloud account (with API key) OR use self-hosted server for cloud deployments

### Steps

1. **Create secret in AWS Secrets Manager (BEFORE running Terraform):**

```bash
# Store Prefect API key securely in Secrets Manager
aws secretsmanager create-secret \
  --name prefect/api-key \
  --description "Prefect Cloud API key" \
  --secret-string "your-prefect-cloud-api-key-here" \
  --region ap-southeast-1
```

2. **Navigate to AWS deployment directory:**

```bash
cd deployments/aws-ecs
```

3. **Create `terraform.tfvars` from example:**

```bash
# Windows
Copy-Item terraform.tfvars.example terraform.tfvars

# Linux/Mac
cp terraform.tfvars.example terraform.tfvars
```

4. **Edit `terraform.tfvars` with your values:**

```hcl
aws_region = "ap-southeast-1"  # Singapore

# Reference to existing secret (created in step 1)
prefect_secret_name = "prefect/api-key"

subnets = [
  "subnet-abc123",
  "subnet-def456"
]

security_groups = [
  "sg-abc123"
]
```

5. **Initialize and apply Terraform:**

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply
```

5. **Build and push Docker image:**

```bash
# Get ECR login command from Terraform output
terraform output -raw docker_login_command | Invoke-Expression  # PowerShell
# or
$(terraform output -raw docker_login_command)  # Bash

# Build and push (commands shown in output)
cd ../..
terraform output -raw docker_build_push_commands | sh
```

7. **Create Prefect work pool and deploy:**

```bash
# Create work pool for ECS
prefect work-pool create --type ecs aws-ecs-pool

# Deploy using prefect.yaml
prefect deploy
```

8. **Verify deployment:**

```bash
cd deployments/aws-ecs

# Check ECS service status
terraform output

# View logs
aws logs tail $(terraform output -raw cloudwatch_log_group) --follow
```

### Cleanup

```bash
cd deployments/aws-ecs
terraform destroy
```

---

## Deploy to GCP Cloud Run

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0 installed
- Google Cloud project created
- `gcloud` CLI installed and authenticated (`gcloud auth login`, `gcloud auth application-default login`)
- Prefect Cloud account OR use self-hosted server

### Steps

1. **Create secret in GCP Secret Manager (BEFORE running Terraform):**

```bash
# Enable Secret Manager API
gcloud services enable secretmanager.googleapis.com --project=my-project-id

3 Store Prefect API key securely
echo -n "your-prefect-cloud-api-key-here" | \
  gcloud secrets create prefect-api-key \
    --data-file=- \
    --replication-policy=automatic \
    --project=my-project-id
```

2. **Navigate to GCP deployment directory:**

4. **Edit `terraform.tfvars`:**

```hcl
gcp_project = "my-project-id"
gcp_region  = "asia-southeast1"  # Singapore

# Reference to existing secret (created in step 1)
prefect_secret_name = "prefect-api-key"
```

5
# Linux/Mac
cp terraform.tfvars.example terraform.tfvars
```

3. **Edit `terraform.tfvars`:**

```hcl
gcp_project = "my-project-id"
gcp_region  = "us-central1"

prefect_api_key = "your-prefect-api-key-here"
```

4. **Initialize and apply Terraform:**

```bash
terraform init
terraform plan
terraform apply
5. **Add Prefect API key as Container App secret (AFTER Terraform deployment):**

```bash
# Set API key securely via Azure CLI
az containerapp secret set \
  --name prefect-worker \
  --resource-group prefect-rg \
  --secrets prefect-api-key="your-prefect-cloud-api-key-here"

# Update container to use the secret
az containerapp update \
  --name prefect-worker \
  --resource-group prefect-rg \
  --set-env-vars "PREFECT_API_KEY=secretref:prefect-api-key"
```

5. **Build and push Docker image:**

```bash
# Configure Docker authentication
terraform output -raw docker_login_command | Invoke-Expression  # PowerShell
# or
$(terraform output -raw docker_login_command)  # Bash

# Build and push
cd ../..
terraform output -raw docker_build_push_commands | sh
```
7. **Create Prefect work pool and deploy:**

```bash
prefect work-pool create --type cloud-run gcp-cloudrun-pool
prefect deploy
```

8. **Verify:**

```bash
cd deployments/gcp-cloudrun
terraform output
gcloud run services describe prefect-worker --region asia-southeast1
```

### Cleanup

```bash
cd deployments/gcp-cloudrun
terraform destroy
```

---

## Deploy to Azure Container Apps

### Prerequisites

- 
``[Terraform](https://www.terraform.io/downloads) >= 1.0 installed
- Azure subscription (free account works)
- `az` CLI installed and authenticated (`az login`)
- Prefect Cloud account OR use self-hosted server

### Steps

1. **Navigate to Azure deployment directory:**

```bash
cd deployments/azure-containerapps
```

2. **Create `terraform.tfvars` from example:**

```bash
# Windows
Copy-Item terraform.tfvars.example terraform.tfvars

# Linux/Mac
cp terraform.tfvars.example terraform.tfvars
```

3. **Edit `terraform.tfvars`:**

```hcl
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

prefect_api_key = "your-prefect-api-key-here"

# Note: acr_name must be globally unique, alphanumeric only
acr_name = "prefectacr12345"
```

4. **Initialize and apply Terraform:**

```bash
terraform init
terraform plan
terraform apply
```

5. **Build and push Docker image:**

```bash
# Login to ACR
terraform output -raw docker_login_command | Invoke-Expression  # PowerShell
# or
$(terraform output -raw docker_login_command)  # Bash

# Build and push using ACR
cd ../..
az acr build --registry $(terraform output -raw acr_login_server | cut -d. -f1) --image prefect-worker:latest --file Dockerfile .
```

7. **Create Prefect work pool and deploy:**

```bash
prefect work-pool create --type azure-container-instances azure-aca-pool
prefect deploy
```

8. **Verify:**

```bash
cd deployments/azure-containerapps
terraform output
az containerapp show --name prefect-worker --resource-group prefect-rg
```

### Cleanup

```bash
cd deployments/azure-containerapps
terraform destroy
AZ_LOCATION=eastus
AZ_ACR_NAME=prefectacr
AZ_CONTAINERAPPS_ENV=prefect-env
```

2. **Run deployment script:**

```bash
bash deployments/azure-containerapps/deploy.sh
```

The script will:
- ✅ Create resource group
- ✅ Create ACR (Azure Container Registry)
- ✅ Build and push image
- ✅ Create Container Apps environment
- ✅ Deploy Container App

3. **In Prefect Cloud:**

```bash
# Create work pool for Azure
prefect work-pool create --type azure-container-instances azure-aca-pool

# Deploy flow
prefect deploy --deployment hello-flow-azure-aca
```

4. **Verify:**

```bash
az containerapp show \
  --name prefect-worker \
  --resource-group prefect-rg
```

---

## Understanding the Example Flow

`flows/hello_flow.py` demonstrates key Prefect patterns:

```python
@task(retries=2, retry_delay_seconds=5)
def fetch_data(data_source: str) -> dict:
    """Task with automatic retry on failure."""
    logger = get_run_logger()
    logger.info(f"Fetching data from {data_source}")
    # ... logic ...
    return raw_data

@flow
def hello_flow(data_source: str = "api.example.com") -> str:
    """Main orchestration flow with task dependencies."""
    raw_data = fetch_data(data_source)
    processed_data = process_data(raw_data)
    result_id = store_result(processed_data)
    return result_id
```

**Features:**
- **Retries:** `@task(retries=2)` automatically retries failed tasks
- **Logging:** `get_run_logger()` integrates with Prefect's log stream
- **Task Dependencies:** Flow orchestrates task execution order
- **Parameters:** Flow accepts inputs, configurable per deployment
- **Scheduling:** Each deployment has a cron schedule (see `deployments/prefect.yaml`)

---

## Common Tasks

### Run a Flow Manually

```bash
# Via Prefect UI at http://localhost:4200
# Navigate to Deployments > hello-flow-local > Run

# Or via CLI
prefect deployment run hello-flow-local --param data_source="custom-api.com"
```

### View Flow Logs

```bash
# Prefect UI (local: http://localhost:4200 or Prefect Cloud)
# Navigate to Flow Runs to see logs

# Or tail worker logs
docker-compose logs -f prefect-worker
```

### Update Flow Code

```bash
# 1. Edit flows/hello_flow.py
# 2. Redeploy
prefect deploy --deployment hello-flow-local

# 3. Next scheduled run uses new code
```

### Create a New Work Pool

```bash
# Local Docker pool (for development)
prefect work-pool create --type docker local-docker

# AWS ECS pool
prefect work-pool create --type ecs aws-pool

# GCP Cloud Run pool
prefect work-pool create --type cloud-run gcp-pool

# Azure Container Instances pool
prefect work-pool create --type azure-container-instances azure-pool
```

### Pause/Resume a Deployment

```bash
# Pause (stop scheduling new runs)
prefect deployment pause hello-flow-local

# Resume
prefect deployment resume hello-flow-local
```

### Stop a Running Flow

```bash
# Via Prefect UI > Flow Runs > [Select Run] > Cancel

# Or via CLI
prefect flow-run cancel <RUN_ID>
```

---

## Troubleshooting on Windows

### Docker Socket & Container Flows

To run container flows (flows that spawn Docker containers), you need Docker socket access:

```yaml
# docker-compose.override.yml (create this file for local dev)
version: "3.9"
services:
  prefect-worker:
    volumes:
      # Windows (Docker Desktop): Use named pipe
      - //./pipe/docker_engine://./pipe/docker_engine
      # Linux/Mac: Use Unix socket
      # - /var/run/docker.sock:/var/run/docker.sock
```

Then use `docker-compose up` as normal.

A template is provided at `docker-compose.override.yml.example` — copy and customize as needed.

### Docker Desktop Not Running

```powershell
# Check status
docker ps

# Start Docker Desktop manually or:
Start-Service Docker  # Requires admin
```

### Worker Not Connecting to Prefect Server

```powershell
# Check worker logs
docker-compose logs prefect-worker

# Verify connection to server
docker-compose exec prefect-worker prefect cloud login --token http://prefect-server:4200/api

# Or check server health
docker-compose exec prefect-server prefect version
```

### Flow Not Showing in Prefect UI

```bash
# Ensure deployment is registered
prefect deployment ls

# If missing, redeploy
prefect deploy --deployment hello-flow-local

# Check if work pool exists
prefect work-pool ls
```

### Port Conflict (4200 for self-hosted server)

```powershell
# Find process using port 4200
Get-NetTCPConnection -LocalPort 4200

# If needed, stop existing container
docker-compose down
```

### Docker Image Build Fails

```powershell
# Clear Docker cache and retry
docker system prune -a

# Then redeploy
prefect deploy --deployment hello-flow-local
```

### Cloud Deployment Errors

**AWS:**
```bash
# Check ECR login
aws ecr describe-repositories --region us-east-1

# Check task definition
aws ecs describe-task-definition --task-definition prefect-worker --region us-east-1
```

**GCP:**
```bash
# Check Artifact Registry
gcloud artifacts repositories list --location=us-central1

# Check Cloud Run service
gcloud run services describe prefect-worker --region us-central1
```

**Azure:**
```bash
# Check Container Registry
az acr list --resource-group prefect-rg

# Check Container App
az containerapp show --name prefect-worker --resource-group prefect-rg
```

---

## Next Steps

1. **Add more flows** in `flows/` directory
2. **Create deployments** in `prefect.yaml` for each flow/environment
3. **Set up CI/CD** to auto-deploy on git push (GitHub Actions, GitLab CI, etc.)
4. **Monitor costs** in cloud provider dashboards
5. **Implement custom work pools** for specific infrastructure needs
6. **Add flow notifications** (Slack, email, webhooks) via Prefect blocks

---

## Resources

- **Prefect Docs:** https://docs.prefect.io/latest/
- **Work Pools:** https://docs.prefect.io/latest/concepts/work-pools/
- **Deployments:** https://docs.prefect.io/latest/concepts/deployments/
- **Cloud Login:** https://docs.prefect.io/latest/cloud/cloud-login/

---

## License

MIT (or your preferred license)
