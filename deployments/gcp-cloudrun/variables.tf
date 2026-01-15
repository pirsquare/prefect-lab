# ============================================================================
# GCP Cloud Run Variables
# ============================================================================

variable "gcp_project" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for Cloud Run service"
  type        = string
  default     = "asia-southeast1"  # Singapore
}

variable "ar_location" {
  description = "Artifact Registry location"
  type        = string
  default     = "asia-southeast1"  # Singapore
}

variable "ar_repo_name" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "prefect-lab"
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
  description = "Name of existing Secret Manager secret containing Prefect API key. Create before running terraform."
  type        = string
  default     = "prefect-api-key"
}

variable "cpu_limit" {
  description = "CPU limit for Cloud Run service"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit for Cloud Run service"
  type        = string
  default     = "2Gi"
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 2
}
