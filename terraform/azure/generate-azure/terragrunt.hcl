include "root" {
  path           = find_in_parent_folders("root.hcl")
  merge_strategy = "deep"
}

include "remote_state" {
  path = find_in_parent_folders("remote_state.hcl")
}

locals {
  env = read_terragrunt_config("${get_terragrunt_dir()}/prod.hcl")
}

inputs = local.env.inputs

terraform {
  source = "${get_parent_terragrunt_dir()}/modules/generate-azure"
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<PROVIDER
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
PROVIDER
}
