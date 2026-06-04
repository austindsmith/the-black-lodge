include "root" {
  path           = find_in_parent_folders("root.hcl")
  merge_strategy = "deep"
}

locals {
  env  = read_terragrunt_config("${get_terragrunt_dir()}/prod.hcl")
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = merge(local.env.inputs, {
  azure_admin_id = local.root.locals.secrets.azure_admin_id
})

terraform {
  source = "${get_parent_terragrunt_dir()}/modules/generate-azure"
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azuread" {}
EOF
}

generate "secrets" {
  path      = "secrets.auto.tfvars"
  if_exists = "overwrite"
  contents  = ""
}
