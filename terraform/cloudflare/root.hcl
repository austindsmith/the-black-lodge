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
  secrets = yamldecode(sops_decrypt_file("${get_repo_root()}/terraform/cloudflare/secret.yaml"))
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        cloudflare = {
          source  = "cloudflare/cloudflare"
          version = "~> 5.0"
        }
      }
    }
    provider "cloudflare" {
      api_token = var.cloudflare_api_token
    }
  EOF
}
