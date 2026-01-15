# ============================================================================
# GCP Cloud Run Outputs
# ============================================================================

output "artifact_registry_url" {
  description = "Artifact Registry repository URL"
  value       = "${var.ar_location}-docker.pkg.dev/${var.gcp_project}/${var.ar_repo_name}"
}

output "cloud_run_service_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_v2_service.prefect_worker.uri
}

output "cloud_run_service_name" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.prefect_worker.name
}

output "service_account_email" {
  description = "Service account email"
  value       = google_service_account.prefect_worker.email
}

output "docker_login_command" {
  description = "Command to configure Docker authentication"
  value       = "gcloud auth configure-docker ${var.ar_location}-docker.pkg.dev"
}

output "docker_build_push_commands" {
  description = "Commands to build and push Docker image"
  value = <<-EOT
    # Build image
    docker build -t prefect-worker:${var.image_tag} -f Dockerfile .
    
    # Tag image
    docker tag prefect-worker:${var.image_tag} ${var.ar_location}-docker.pkg.dev/${var.gcp_project}/${var.ar_repo_name}/prefect-worker:${var.image_tag}
    
    # Push image
    docker push ${var.ar_location}-docker.pkg.dev/${var.gcp_project}/${var.ar_repo_name}/prefect-worker:${var.image_tag}
  EOT
}
