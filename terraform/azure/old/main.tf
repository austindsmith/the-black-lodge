data "azuread_client_config" "current" {}

data "azuread_domains" "primary" {
  only_initial = true
}

locals {
  redirect_uri  = "https://${var.ingress_host}/signin-oidc"
  logout_uri    = "https://${var.ingress_host}/signout-oidc"
  identifier_uri = "api://${azuread_application.generate.client_id}"
}

resource "azuread_application" "generate" {
  display_name     = var.display_name
  sign_in_audience = "AzureADMyOrg"

  web {
    redirect_uris = [local.redirect_uri]
    logout_url    = local.logout_uri

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }

  app_role {
    id                   = "4a3e2e6a-1a2b-4c3d-9e8f-0a1b2c3d4e5f"
    allowed_member_types = ["User"]
    display_name         = "Administrator"
    description          = "Full access to Generate"
    value                = "Administrator"
    enabled              = true
  }

  app_role {
    id                   = "7b4f3c2d-5e6a-4b7c-8d9e-1f2a3b4c5d6e"
    display_name         = "Reviewer"
    description          = "Read-only access to Generate"
    value                = "Reviewer"
    allowed_member_types = ["User"]
    enabled              = true
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }

    resource_access {
      id   = "37f7f235-527c-4136-accd-4a02d197296e"
      type = "Scope"
    }
  }

  identifier_uris = ["api://${data.azuread_client_config.current.tenant_id}/${var.display_name}"]

  lifecycle {
    ignore_changes = [identifier_uris]
  }
}

resource "azuread_service_principal" "generate" {
  client_id = azuread_application.generate.client_id

  app_role_assignment_required = false
}

resource "azuread_application_password" "generate" {
  application_id = azuread_application.generate.id
  display_name   = "generate-k8s"
  end_date       = "2099-01-01T00:00:00Z"
}

resource "azuread_app_role_assignment" "admin" {
  count = var.admin_user_id != null ? 1 : 0

  app_role_id         = "4a3e2e6a-1a2b-4c3d-9e8f-0a1b2c3d4e5f"
  principal_object_id = var.admin_user_id
  resource_object_id  = azuread_service_principal.generate.object_id
}
