resource "cloudflare_zero_trust_access_application" "rustdesk_bypass" {
  account_id                = var.cloudflare_account_id
  app_launcher_visible      = false
  auto_redirect_to_identity = false
  domain                    = "rustdesk.${var.domain}"
  name                      = "RustDesk Bypass"
  session_duration          = "24h"
  type                      = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "rustdesk.${var.domain}"
  }]
  policies = [{
    decision   = "bypass"
    name       = "RustDesk Bypass"
    include    = [{ everyone = {} }]
    precedence = 1
    require    = []
    reusable   = true
  }]
}

resource "cloudflare_zero_trust_access_application" "teleport_bypass" {
  account_id                = var.cloudflare_account_id
  app_launcher_visible      = false
  auto_redirect_to_identity = false
  domain                    = "teleport.${var.domain}"
  name                      = "Teleport Bypass"
  session_duration          = "24h"
  type                      = "self_hosted"

  destinations = [{
    type = "public"
    uri  = "teleport.${var.domain}"
  }]

  policies = [{
    decision   = "bypass"
    name       = "Teleport Bypass"
    include    = [{ everyone = {} }]
    precedence = 1
    require    = []
    reusable   = true
  }]
}

resource "cloudflare_zero_trust_access_application" "authentik_admin" {
  account_id                = var.cloudflare_account_id
  app_launcher_visible      = false
  auto_redirect_to_identity = false
  name                      = "Authentik Admin"
  session_duration          = "24h"
  type                      = "self_hosted"
  domain                    = "authentik.${var.domain}/if/admin/*"

  destinations = [{
    type = "public"
    uri  = "authentik.${var.domain}/if/admin/*"
  }]

  policies = [{
    decision = "allow"
    include = [{
      email = { email = var.email_address }
    }]
    exclude    = []
    name       = "Admin Only"
    precedence = 1
    require    = []
  }]
}

resource "cloudflare_zero_trust_access_application" "authentik-oidc" {
  account_id                 = var.cloudflare_account_id
  allowed_idps               = []
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "authentik.${var.domain}"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "Authentik"
  options_preflight_bypass   = false
  session_duration           = "24h"
  tags                       = []
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "authentik.${var.domain}"
  }]
  policies = [{
    decision   = "bypass"
    name       = "Authentik Bypass"
    include    = [{ everyone = {} }]
    precedence = 1
    require    = []
    reusable   = true
  }]
}

resource "cloudflare_zero_trust_access_application" "wildcard" {
  account_id                 = var.cloudflare_account_id
  allowed_idps               = []
  app_launcher_visible       = true
  auto_redirect_to_identity  = false
  domain                     = "*.${var.domain}"
  enable_binding_cookie      = false
  http_only_cookie_attribute = false
  name                       = "*"
  options_preflight_bypass   = false
  session_duration           = "24h"
  tags                       = []
  type                       = "self_hosted"
  destinations = [{
    type = "public"
    uri  = "*.${var.domain}"
  }]
  policies = [{
    decision = "allow"
    include = [{
      email = {
        email = var.email_address
      }
    }]
    exclude    = []
    name       = "Email access"
    precedence = 1
    require    = []
    reusable   = true
  }]
}
