data "azuread_client_config" "current" {}

data "azuread_domains" "initial" {
  only_initial = true
}

resource "random_uuid" "administrator" {}

resource "random_uuid" "reviewer" {}

resource "azuread_application" "generate" {
  display_name     = var.display_name
  sign_in_audience = "AzureADMyOrg"

  single_page_application {
    redirect_uris = ["https://${var.ingress_host}/"]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
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

resource "azuread_app_role_assignment" "administrators" {
  for_each            = toset(var.administrator_object_ids)
  app_role_id         = random_uuid.administrator.result
  principal_object_id = each.value
  resource_object_id  = azuread_service_principal.generate.object_id
}

resource "azuread_app_role_assignment" "reviewers" {
  for_each            = toset(var.reviewer_object_ids)
  app_role_id         = random_uuid.reviewer.result
  principal_object_id = each.value
  resource_object_id  = azuread_service_principal.generate.object_id
}
