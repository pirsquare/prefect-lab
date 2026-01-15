#!/bin/bash
# GCP Cloud Run Deployment Script for Prefect Worker
#
# Prerequisites:
#  - gcloud CLI installed and authenticated
#  - Google Cloud project set up
#  - Artifact Registry API enabled
#  - Docker installed
#
# Usage:
#   bash deployments/gcp-cloudrun/deploy.sh
#   (Uses .env file from current directory)

set -e

echo "=========================================="
echo "Prefect Worker - GCP Cloud Run Deployment"
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
REQUIRED_VARS=("GCP_PROJECT" "GCP_REGION" "GCP_AR_REPO" "GCP_AR_LOCATION" "PREFECT_API_URL" "PREFECT_API_KEY")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "ERROR: $var is not set in .env"
        exit 1
    fi
done

# Construct image URI
AR_REGISTRY="${GCP_AR_LOCATION}-docker.pkg.dev"
IMAGE_URI="${AR_REGISTRY}/${GCP_PROJECT}/${GCP_AR_REPO}/prefect-worker:latest"

echo ""
echo "Configuration:"
echo "  GCP Project: $GCP_PROJECT"
echo "  Region: $GCP_REGION"
echo "  AR Repository: $GCP_AR_REPO"
echo "  Image URI: $IMAGE_URI"
echo ""

# Step 1: Set GCP project
echo "[1/5] Setting GCP project..."
gcloud config set project "$GCP_PROJECT"

# Step 2: Authenticate Docker with Artifact Registry
echo "[2/5] Configuring Docker authentication..."
gcloud auth configure-docker "${AR_REGISTRY}"

# Step 3: Create Artifact Registry repository if it doesn't exist
echo "[3/5] Ensuring Artifact Registry repository exists..."
gcloud artifacts repositories create "$GCP_AR_REPO" \
    --repository-format=docker \
    --location="$GCP_AR_LOCATION" \
    --project="$GCP_PROJECT" \
    2>/dev/null || true

# Step 4: Build and push image
echo "[4/5] Building and pushing Docker image..."
docker build -t "$IMAGE_URI" \
             -f Dockerfile .

docker push "$IMAGE_URI"

# Step 5: Deploy to Cloud Run
echo "[5/5] Deploying to Cloud Run..."

gcloud run deploy prefect-worker \
    --image "$IMAGE_URI" \
    --region "$GCP_REGION" \
    --platform managed \
    --memory 1Gi \
    --cpu 1 \
    --timeout 3600 \
    --set-env-vars "PREFECT_API_URL=${PREFECT_API_URL},PREFECT_LOGGING_LEVEL=INFO" \
    --set-secrets "PREFECT_API_KEY=prefect-api-key:latest" \
    --no-allow-unauthenticated \
    --service-account "prefect-worker@${GCP_PROJECT}.iam.gserviceaccount.com"

echo ""
echo "=========================================="
echo "Deployment Successful!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Create a Cloud Secret (if not exists):"
echo "   gcloud secrets create prefect-api-key --data-file=- <<< '${PREFECT_API_KEY}' --project ${GCP_PROJECT}"
echo ""
echo "2. Grant Cloud Run service account access to the secret:"
echo "   gcloud secrets add-iam-policy-binding prefect-api-key \\"
echo "       --member=serviceAccount:prefect-worker@${GCP_PROJECT}.iam.gserviceaccount.com \\"
echo "       --role=roles/secretmanager.secretAccessor \\"
echo "       --project ${GCP_PROJECT}"
echo ""
echo "3. Create a service account (if not exists):"
echo "   gcloud iam service-accounts create prefect-worker \\"
echo "       --display-name='Prefect Worker Service Account' \\"
echo "       --project ${GCP_PROJECT}"
echo ""
echo "4. In Prefect Cloud, create a work pool:"
echo "   prefect work-pool create --type cloud-run gcp-cloudrun-pool"
echo ""
echo "5. Deploy flows:"
echo "   prefect deploy --deployment hello-flow-gcp-cloudrun"
echo ""
echo "View Cloud Run service:"
echo "   gcloud run services describe prefect-worker --region ${GCP_REGION} --project ${GCP_PROJECT}"
echo ""
