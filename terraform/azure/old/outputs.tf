output "tenant_id" {
  description = "Entra tenant ID — set azureAd.tenantId in the HelmRelease"
  value       = module.generate_app.tenant_id
}

output "client_id" {
  description = "App registration client ID — set azureAd.clientId in the HelmRelease"
  value       = module.generate_app.client_id
}

output "client_secret" {
  description = "Client secret — store as GENERATE_AAD_CLIENT_SECRET in Infisical"
  value       = module.generate_app.client_secret
  sensitive   = true
}

output "domain" {
  description = "Primary domain of the Entra tenant — set azureAd.domain in the HelmRelease"
  value       = module.generate_app.domain
}
