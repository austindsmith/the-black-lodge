resource "cloudflare_zero_trust_access_identity_provider" "authentik" {
  account_id = var.cloudflare_account_id

  name = "Authentik"
  type = "oidc"

  config = {
    client_id     = var.authentik_client_id
    client_secret = var.authentik_client_secret

    auth_url  = "https://authentik.${var.domain}/application/o/cloudflare/authorize/"
    token_url = "https://authentik.${var.domain}/application/o/cloudflare/token/"
    certs_url = "https://authentik.${var.domain}/application/o/cloudflare/jwks/"

    scopes = ["openid", "email", "profile"]
  }
}
