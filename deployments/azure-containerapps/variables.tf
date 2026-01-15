# ============================================================================
# Azure Container Apps Variables
# ============================================================================

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "prefect-rg"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "southeastasia"  # Singapore
}

variable "acr_name" {
  description = "Azure Container Registry name (must be globally unique)"
  type        = string
  default     = "prefectacr"
}

variable "acr_sku" {
  description = "ACR SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Basic"
}

variable "container_app_env_name" {
  description = "Container Apps Environment name"
  type        = string
  default     = "prefect-env"
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

variable "container_cpu" {
  description = "CPU allocation for container (e.g., 0.5, 1.0)"
  type        = number
  default     = 1.0
}

variable "container_memory" {
  description = "Memory allocation for container (e.g., 1Gi, 2Gi)"
  type        = string
  default     = "2Gi"
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 2
}

variable "log_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "prefect-lab"
    ManagedBy = "Terraform"
  }
}
