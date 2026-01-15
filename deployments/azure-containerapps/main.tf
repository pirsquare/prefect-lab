# ============================================================================
# Azure Container Apps Infrastructure for Prefect Worker
# ============================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# ============================================================================
# Resource Group
# ============================================================================

resource "azurerm_resource_group" "prefect" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# ============================================================================
# Container Registry
# ============================================================================

resource "azurerm_container_registry" "prefect" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.prefect.name
  location            = azurerm_resource_group.prefect.location
  sku                 = var.acr_sku
  admin_enabled       = true

  tags = var.tags
}

# ============================================================================
# Container Apps Environment
# ============================================================================

resource "azurerm_log_analytics_workspace" "prefect" {
  name                = "${var.resource_group_name}-logs"
  location            = azurerm_resource_group.prefect.location
  resource_group_name = azurerm_resource_group.prefect.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = var.tags
}

resource "azurerm_container_app_environment" "prefect" {
  name                       = var.container_app_env_name
  location                   = azurerm_resource_group.prefect.location
  resource_group_name        = azurerm_resource_group.prefect.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.prefect.id

  tags = var.tags
}

# ============================================================================
# User Assigned Managed Identity
# ============================================================================

resource "azurerm_user_assigned_identity" "prefect_worker" {
  name                = "prefect-worker-identity"
  resource_group_name = azurerm_resource_group.prefect.name
  location            = azurerm_resource_group.prefect.location

  tags = var.tags
}

# Grant ACR pull permissions to managed identity
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.prefect.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.prefect_worker.principal_id
}

# ============================================================================
# Container App
# ============================================================================

resource "azurerm_container_app" "prefect_worker" {
  name                         = "prefect-worker"
  container_app_environment_id = azurerm_container_app_environment.prefect.id
  resource_group_name          = azurerm_resource_group.prefect.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.prefect_worker.id]
  }

  registry {
    server   = azurerm_container_registry.prefect.login_server
    identity = azurerm_user_assigned_identity.prefect_worker.id
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "prefect-worker"
      image  = "${azurerm_container_registry.prefect.login_server}/prefect-worker:${var.image_tag}"
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "PREFECT_API_URL"
        value = var.prefect_api_url
      }

      env {
        name  = "PREFECT_LOGGING_LEVEL"
        value = "INFO"
      }

      # Note: For production, use Azure Key Vault instead of inline secrets
      # This is a simplified version - API key should be set via Azure Portal
      # or az containerapp secret set command after deployment
    }
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.acr_pull
  ]
}
