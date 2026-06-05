download_dir = "${get_repo_root()}/.terragrunt-cache"

remote_state {
  backend = "local"
  config = {
    path = "${get_repo_root()}/.tfstate/${path_relative_to_include()}/terraform.tfstate"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
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
      user     = "admin"
      password = "your-password"
    }

  EOF
}
