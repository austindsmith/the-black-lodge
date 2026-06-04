output "tenant_id" {
  description = "Entra tenant ID for azureAd.tenantId"
  value       = data.azuread_client_config.current.tenant_id
}

output "client_id" {
  description = "Application (client) ID for azureAd.clientId"
  value       = azuread_application.generate.client_id
}

output "domain" {
  description = "Initial tenant domain for azureAd.domain"
  value       = data.azuread_domains.initial.domains[0].domain_name
}

output "client_secret" {
  description = "Client secret value; store as GENERATE_AAD_CLIENT_SECRET"
  value       = azuread_application_password.generate.value
  sensitive   = true
}
