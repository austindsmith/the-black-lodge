resource "cloudflare_zero_trust_tunnel_cloudflared" "mgmt" {
  account_id = var.cloudflare_account_id
  name       = "the-black-lodge"
  secret     = var.mgmt_tunnel_secret
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "mgmt" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.mgmt.id

  config {
    ingress_rule {
      hostname = "${each.subdomain}.${var.domain}"
      service  = "ssh://${each.ip_address}:22"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}
