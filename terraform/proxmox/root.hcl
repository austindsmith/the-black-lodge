download_dir = "${get_repo_root()}/.terragrunt-cache"

include "remote_state" {
  path = find_in_parent_folders("remote_state.hcl")
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.98.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_url
  api_token = var.proxmox_token
  ssh {
    agent    = true
    username = "ansible"
  }
}
EOF
}

locals {
  secrets = yamldecode(sops_decrypt_file("${get_parent_terragrunt_dir()}/secret.yaml"))
}

generate "secrets" {
  path      = "secrets.auto.tfvars"
  if_exists = "overwrite"
  contents  = <<-EOT
    proxmox_url   = "${local.secrets.proxmox_url}"
    proxmox_token = "${local.secrets.proxmox_token}"
    ssh_password  = "${local.secrets.ssh_password}"
  EOT
}

#inputs = {
#  ansible_inventory_path = "${get_repo_root()}/ansible/inventory/terraform.yml"
#}
