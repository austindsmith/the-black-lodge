data "azuread_client_config" "current" {}

data "azuread_domains" "initial" {
  only_initial = true
}

resource "random_uuid" "administrator" {}

resource "random_uuid" "reviewer" {}

resource "azuread_application" "generate" {
  display_name     = var.display_name
  sign_in_audience = "AzureADMyOrg"

  web {
    redirect_uris = ["https://${var.ingress_host}/signin-oidc"]
    implicit_grant {
      id_token_issuance_enabled = true
    }
  }

  app_role {
    allowed_member_types = ["User"]
    description          = "Administrators manage Generate and submit reports"
    display_name         = "Administrator"
    enabled              = true
    id                   = random_uuid.administrator.result
    value                = "Administrator"
  }

  app_role {
    allowed_member_types = ["User"]
    description          = "Reviewers review district data"
    display_name         = "Reviewer"
    enabled              = true
    id                   = random_uuid.reviewer.result
    value                = "Reviewer"
  }
}

resource "azuread_service_principal" "generate" {
  client_id = azuread_application.generate.client_id
}

resource "azuread_application_password" "generate" {
  application_id = azuread_application.generate.id
  display_name   = "generate-helm"
}

resource "azuread_app_role_assignment" "admin" {
  count               = var.admin_user_id == "" ? 0 : 1
  app_role_id         = random_uuid.administrator.result
  principal_object_id = var.admin_user_id
  resource_object_id  = azuread_service_principal.generate.object_id
}
