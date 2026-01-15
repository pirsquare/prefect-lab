# Prefect Lab: Production-Ready Workflow Orchestration

A minimal, copy-pasteable Prefect v3 setup with local Docker development and multi-cloud deployment templates (AWS ECS, GCP Cloud Run, Azure Container Apps).

**Key Features:**
- ✅ Self-hosted Prefect Server by default (local, no cloud account required)
- ✅ Optional Prefect Cloud integration (for remote orchestration)
- ✅ Example flow with schedules, retries, and structured logging
- ✅ Ready-to-use cloud deployment scripts (AWS, GCP, Azure)
- ✅ Windows-friendly (Docker Desktop + PowerShell/Bash support)
- ✅ No Kubernetes required

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

# Deploy the example flow
prefect deploy --deployment hello-flow-local
```

Expected output:
```
Created work pool 'default' (type: docker)
Deployment 'hello-flow-local' deployed successfully
```

### 4. Trigger a Flow Run

```bash
# Via CLI
prefect deployment run hello-flow-local

# Or via Prefect UI at http://localhost:4200
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
│   │   └── deploy.sh             # AWS ECS deployment script
│   ├── gcp-cloudrun/
│   │   └── deploy.sh             # GCP Cloud Run deployment script
│   └── azure-containerapps/
│       └── deploy.sh             # Azure Container Apps deployment script
├── Dockerfile                    # Container image for flows & workers
├── docker-compose.yml            # Local dev environment
├── requirements.txt              # Python dependencies
├── .env.example                  # Environment variable template
└── README.md                     # This file
```

---

## Deploy to AWS ECS (Fargate)

### Prerequisites

- AWS account with ECR, ECS, and Secrets Manager access
- AWS CLI configured locally (`aws configure`)
- Prefect Cloud account (with API key) OR use self-hosted server for cloud deployments

### Steps

1. **Update `.env` with AWS details:**

```env
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012
AWS_ECR_REPO=prefect-lab
AWS_ECS_CLUSTER=prefect-cluster
AWS_ECS_TASK_FAMILY=prefect-worker
AWS_SUBNETS=subnet-abc123,subnet-def456
AWS_SECURITY_GROUPS=sg-abc123
```

2. **Run deployment script:**

```bash
bash deployments/aws-ecs/deploy.sh
```

The script will:
- ✅ Login to ECR
- ✅ Build and push Docker image
- ✅ Register ECS task definition
- ✅ Output instructions for next steps

3. **Complete manual setup:**

```bash
# 1. Create CloudWatch log group
aws logs create-log-group \
  --log-group-name /ecs/prefect-worker \
  --region us-east-1

# 2. Store API key in Secrets Manager
aws secretsmanager create-secret \
  --name prefect/api-key \
  --secret-string 'your-prefect-api-key' \
  --region us-east-1

# 3. Create ECS service or one-off task
aws ecs run-task \
  --cluster prefect-cluster \
  --task-definition prefect-worker:1 \
  --launch-type FARGATE \
  --network-configuration \
    "awsvpcConfiguration={subnets=[subnet-abc123],securityGroups=[sg-abc123],assignPublicIp=ENABLED}" \
  --region us-east-1
```

4. **In Prefect Cloud:**

```bash
# Create work pool for ECS
prefect work-pool create --type ecs aws-ecs-pool

# Deploy hello-flow to AWS
prefect deploy --deployment hello-flow-aws-ecs
```

5. **Verify:**

```bash
# Check task status in AWS
aws ecs describe-tasks \
  --cluster prefect-cluster \
  --tasks <TASK_ARN> \
  --region us-east-1
```

---

## Deploy to GCP Cloud Run

### Prerequisites

- Google Cloud project created
- `gcloud` CLI installed and authenticated (`gcloud auth login`)
- Artifact Registry API enabled
- Prefect Cloud account OR use self-hosted server

### Steps

1. **Update `.env` with GCP details:**

```env
GCP_PROJECT=my-project-id
GCP_REGION=us-central1
GCP_AR_REPO=prefect-lab
GCP_AR_LOCATION=us-central1
```

2. **Run deployment script:**

```bash
bash deployments/gcp-cloudrun/deploy.sh
```

The script will:
- ✅ Create Artifact Registry repository
- ✅ Build and push image
- ✅ Deploy Cloud Run service
- ✅ Output instructions for next steps

3. **Complete manual setup:**

```bash
# 1. Create Cloud Secret
gcloud secrets create prefect-api-key \
  --data-file=- <<< 'your-prefect-api-key' \
  --project my-project-id

# 2. Grant Cloud Run service account secret access
gcloud secrets add-iam-policy-binding prefect-api-key \
  --member=serviceAccount:prefect-worker@my-project-id.iam.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor \
  --project my-project-id

# 3. (Optional) Create service account if not exists
gcloud iam service-accounts create prefect-worker \
  --display-name='Prefect Worker' \
  --project my-project-id
```

4. **In Prefect Cloud:**

```bash
# Create work pool for Cloud Run
prefect work-pool create --type cloud-run gcp-cloudrun-pool

# Deploy flow
prefect deploy --deployment hello-flow-gcp-cloudrun
```

5. **Verify:**

```bash
gcloud run services describe prefect-worker --region us-central1
```

---

## Deploy to Azure Container Apps

### Prerequisites

- Azure subscription (free account works)
- `az` CLI installed and authenticated (`az login`)
- Prefect Cloud account OR use self-hosted server

### Steps

1. **Update `.env` with Azure details:**

```env
AZ_SUBSCRIPTION=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
AZ_RESOURCE_GROUP=prefect-rg
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
