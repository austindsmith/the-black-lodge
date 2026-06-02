resource "cloudflare_zero_trust_tunnel_cloudflared" "mgmt" {
  account_id = var.cloudflare_account_id
  name       = "the-black-lodge"
  config_src = "cloudflare"
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "mgmt" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.mgmt.id
}
