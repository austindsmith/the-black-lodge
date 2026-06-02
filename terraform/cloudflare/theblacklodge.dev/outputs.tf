output "mgmt_tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.mgmt.id
}

output "mgmt_tunnel_token" {
  value     = data.cloudflare_zero_trust_tunnel_cloudflared_token.mgmt.token
  sensitive = true
}
