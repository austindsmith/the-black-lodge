download_dir = "${get_repo_root()}/.terragrunt-cache"

include "remote_state" {
  path = find_in_parent_folders("remote_state.hcl")
}

locals {
  secrets = yamldecode(sops_decrypt_file("${get_repo_root()}/terraform/synology/secret.yaml"))
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        synology = {
          source  = "synology-community/synology"
          version = "0.6.11"
        }
      }
    }
    provider "synology" {
      host     = var.nas_url
      user     = var.username
      password = var.password
    }

  EOF
}
