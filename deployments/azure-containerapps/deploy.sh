#!/bin/bash
# Azure Container Apps Deployment Script for Prefect Worker
#
# Prerequisites:
#  - Azure CLI (az) installed and authenticated
#  - Azure subscription selected
#  - Docker installed
#
# Usage:
#   bash deployments/azure-containerapps/deploy.sh
#   (Uses .env file from current directory)

set -e

echo "=========================================="
echo "Prefect Worker - Azure Container Apps Deployment"
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
REQUIRED_VARS=("AZ_SUBSCRIPTION" "AZ_RESOURCE_GROUP" "AZ_LOCATION" "AZ_ACR_NAME" "AZ_CONTAINERAPPS_ENV" "PREFECT_API_URL" "PREFECT_API_KEY")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "ERROR: $var is not set in .env"
        exit 1
    fi
done

# Construct registry URL
ACR_REGISTRY="${AZ_ACR_NAME}.azurecr.io"
IMAGE_URI="${ACR_REGISTRY}/prefect-worker:latest"
CONTAINER_APP_NAME="prefect-worker"

echo ""
echo "Configuration:"
echo "  Subscription: $AZ_SUBSCRIPTION"
echo "  Resource Group: $AZ_RESOURCE_GROUP"
echo "  Location: $AZ_LOCATION"
echo "  ACR: $ACR_REGISTRY"
echo "  Image URI: $IMAGE_URI"
echo ""

# Step 1: Set subscription
echo "[1/6] Setting Azure subscription..."
az account set --subscription "$AZ_SUBSCRIPTION"

# Step 2: Create resource group if it doesn't exist
echo "[2/6] Ensuring resource group exists..."
az group create \
    --name "$AZ_RESOURCE_GROUP" \
    --location "$AZ_LOCATION" \
    2>/dev/null || true

# Step 3: Create ACR if it doesn't exist
echo "[3/6] Ensuring Azure Container Registry exists..."
az acr create \
    --resource-group "$AZ_RESOURCE_GROUP" \
    --name "$AZ_ACR_NAME" \
    --sku Basic \
    2>/dev/null || true

# Step 4: Login to ACR and push image
echo "[4/6] Logging in to ACR..."
az acr login --name "$AZ_ACR_NAME"

echo "[4.5/6] Building and pushing Docker image..."
az acr build \
    --registry "$AZ_ACR_NAME" \
    --image "prefect-worker:latest" \
    --file Dockerfile .

# Step 5: Create Container Apps Environment if it doesn't exist
echo "[5/6] Ensuring Container Apps Environment exists..."
az containerapp env create \
    --name "$AZ_CONTAINERAPPS_ENV" \
    --resource-group "$AZ_RESOURCE_GROUP" \
    --location "$AZ_LOCATION" \
    2>/dev/null || true

# Step 6: Deploy Container App
echo "[6/6] Deploying to Azure Container Apps..."

az containerapp create \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$AZ_RESOURCE_GROUP" \
    --environment "$AZ_CONTAINERAPPS_ENV" \
    --image "$IMAGE_URI" \
    --cpu 1.0 \
    --memory 2.0Gi \
    --registry-server "$ACR_REGISTRY" \
    --registry-username "$AZ_ACR_NAME" \
    --registry-password "$(az acr credential show --name "$AZ_ACR_NAME" --query passwords[0].value -o tsv)" \
    --env-vars \
        PREFECT_API_URL="$PREFECT_API_URL" \
        PREFECT_LOGGING_LEVEL="INFO" \
        PREFECT_API_KEY="$PREFECT_API_KEY" \
    --min-replicas 1 \
    --max-replicas 2 \
    2>/dev/null || \
az containerapp update \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$AZ_RESOURCE_GROUP" \
    --image "$IMAGE_URI" \
    --set-env-vars \
        PREFECT_API_URL="$PREFECT_API_URL" \
        PREFECT_LOGGING_LEVEL="INFO" \
        PREFECT_API_KEY="$PREFECT_API_KEY"

echo ""
echo "=========================================="
echo "Deployment Successful!"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Create a Managed Identity (if not exists):"
echo "   az identity create --name prefect-worker-identity \\"
echo "       --resource-group ${AZ_RESOURCE_GROUP}"
echo ""
echo "2. Grant ACR pull permissions:"
echo "   IDENTITY_ID=\$(az identity show --name prefect-worker-identity \\"
echo "       --resource-group ${AZ_RESOURCE_GROUP} --query id -o tsv)"
echo "   ACR_ID=\$(az acr show --name ${AZ_ACR_NAME} \\"
echo "       --resource-group ${AZ_RESOURCE_GROUP} --query id -o tsv)"
echo "   az role assignment create --assignee \$IDENTITY_ID --role acrpull --scope \$ACR_ID"
echo ""
echo "3. In Prefect Cloud, create a work pool:"
echo "   prefect work-pool create --type azure-container-instances azure-aca-pool"
echo ""
echo "4. Deploy flows:"
echo "   prefect deploy --deployment hello-flow-azure-aca"
echo ""
echo "View Container App:"
echo "   az containerapp show --name ${CONTAINER_APP_NAME} --resource-group ${AZ_RESOURCE_GROUP}"
echo ""
echo "View logs:"
echo "   az containerapp logs show --name ${CONTAINER_APP_NAME} --resource-group ${AZ_RESOURCE_GROUP}"
echo ""
