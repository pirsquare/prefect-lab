# ============================================================================
# Azure Container Apps Outputs
# ============================================================================

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.prefect.name
}

output "acr_login_server" {
  description = "ACR login server URL"
  value       = azurerm_container_registry.prefect.login_server
}

output "acr_admin_username" {
  description = "ACR admin username"
  value       = azurerm_container_registry.prefect.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "ACR admin password"
  value       = azurerm_container_registry.prefect.admin_password
  sensitive   = true
}

output "container_app_name" {
  description = "Container App name"
  value       = azurerm_container_app.prefect_worker.name
}

output "container_app_fqdn" {
  description = "Container App FQDN"
  value       = azurerm_container_app.prefect_worker.latest_revision_fqdn
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = azurerm_log_analytics_workspace.prefect.id
}

output "docker_login_command" {
  description = "Command to login to ACR"
  value       = "az acr login --name ${azurerm_container_registry.prefect.name}"
}

output "docker_build_push_commands" {
  description = "Commands to build and push Docker image using ACR build"
  value = <<-EOT
    # Build and push using ACR (recommended)
    az acr build --registry ${azurerm_container_registry.prefect.name} --image prefect-worker:${var.image_tag} --file Dockerfile .
    
    # Or build locally and push
    docker build -t prefect-worker:${var.image_tag} -f Dockerfile .
    docker tag prefect-worker:${var.image_tag} ${azurerm_container_registry.prefect.login_server}/prefect-worker:${var.image_tag}
    docker push ${azurerm_container_registry.prefect.login_server}/prefect-worker:${var.image_tag}
  EOT
}
