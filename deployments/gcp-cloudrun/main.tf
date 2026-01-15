# ============================================================================
# GCP Cloud Run Infrastructure for Prefect Worker
# ============================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

# ============================================================================
# Enable Required APIs
# ============================================================================

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloudrun" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# ============================================================================
# Artifact Registry Repository
# ============================================================================

resource "google_artifact_registry_repository" "prefect_worker" {
  location      = var.ar_location
  repository_id = var.ar_repo_name
  description   = "Prefect worker Docker images"
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry]
}

# ============================================================================
# Reference existing Secret Manager secret for Prefect API Key
# Create the secret manually before running terraform:
#   gcloud secrets create prefect-api-key --data-file=- <<< 'your-api-key'
# ============================================================================

data "google_secret_manager_secret" "prefect_api_key" {
  secret_id = var.prefect_secret_name

  depends_on = [google_project_service.secretmanager]
}

data "google_secret_manager_secret_version" "prefect_api_key" {
  secret = data.google_secret_manager_secret.prefect_api_key.id
}

# ============================================================================
# Service Account
# ============================================================================

resource "google_service_account" "prefect_worker" {
  account_id   = "prefect-worker"
  display_name = "Prefect Worker Service Account"
  description  = "Service account for Prefect worker running on Cloud Run"
}

# Grant access to read secrets
resource "google_secret_manager_secret_iam_member" "prefect_worker_secret_access" {
  secret_id = data.google_secret_manager_secret.prefect_api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.prefect_worker.email}"
}

# ============================================================================
# Cloud Run Service
# ============================================================================

resource "google_cloud_run_v2_service" "prefect_worker" {
  name     = "prefect-worker"
  location = var.gcp_region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = google_service_account.prefect_worker.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = "${var.ar_location}-docker.pkg.dev/${var.gcp_project}/${var.ar_repo_name}/prefect-worker:${var.image_tag}"

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      env {
        name  = "PREFECT_API_URL"
        value = var.prefect_api_url
      }

      env {
        name  = "PREFECT_LOGGING_LEVEL"
        value = "INFO"
      }

      env {
        name = "PREFECT_API_KEY"
        value_source {
          secret_key_ref {
            secret  = data.google_secret_manager_secret.prefect_api_key.secret_id
            version = "latest"
          }
        }
      }
    }

    timeout = "3600s"  # 1 hour for long-running flows
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_project_service.cloudrun,
    google_secret_manager_secret_iam_member.prefect_worker_secret_access
  ]
}
