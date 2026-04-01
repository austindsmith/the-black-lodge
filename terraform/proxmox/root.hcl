remote_state {
  backend = "local"
  config = {
    path = "${get_parent_terragrunt_dir()}/${path_relative_to_include()}/terraform.tfstate"
  }
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

inputs = {
  description = ""
  tags        = ["gitops", "terraform", "packer"]
  template_id = 9000

  datastore_id = "local-lvm"

  username = "ansible"
  ssh_public_keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKJX0mh+BfWY7aSt9LccuFdMbJCXEebr6qbI/glX7A6V ansible@theblacklodge.org",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ87NZyVSmPPFAD2gzBlv3YJSMD+amqBHTIkb5rGDETd austin@theblacklodge.org"
  ]

  disk_size = 64
  cores     = 2
  cpu_type  = "host"
  ram       = 4096

  vlan_id                       = 5
  dns_servers                   = ["192.168.1.5"]
  gateway                       = "192.168.100.1"
  virtual_environment_node_name = "proxmox"

}

terraform {
  extra_arguments "secrets" {
    commands  = get_terraform_commands_that_need_vars()
    arguments = ["-var-file=${get_parent_terragrunt_dir()}/secrets.auto.tfvars"]
  }
}