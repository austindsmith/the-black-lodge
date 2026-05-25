remote_state {
  backend = "local"
  config = {
    path = "${get_repo_root()}/.tfstate/${path_relative_to_include()}/terraform.tfstate"

  }
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  inventory = read_terragrunt_config("${get_repo_root()}/proxmox/inventory/vm_ids.hcl")
}

terraform {
  source = "${get_repo_root()}/terraform/modules/proxmox-vm"
}

inputs = {
  nodes = local.inventory.locals.vm_ids

  # shared config for all nodes
  ram = 8192
  tags = ["gitops", "terraform", "packer"]
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
  endpoint  = var.virtual_environment_endpoint
  api_token = var.virtual_environment_token
  ssh {
    agent    = true
    username = "ansible"
  }
}
EOF
}
