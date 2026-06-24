terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.98.1"
    }
  }
}

data "sops_file" "proxmox" {
  source_file = "${path.module}/secret.yaml"
}

provider "proxmox" {
  endpoint  = data.sops_file.proxmox.data["proxmox_url"]
  api_token = data.sops_file.proxmox.data["proxmox_token"]
  ssh {
    agent    = true
    username = "ansible"
  }
}

###################################################
#                  Data sources                   #
###################################################

data "proxmox_acme_accounts" "all" {}

// ...which we will go through in order to fetch the whole data on each account.
data "proxmox_acme_account" "example" {
  for_each = data.proxmox_acme_accounts.all.accounts
  name     = each.value
}

data "proxmox_acme_plugin" "example" {
  plugin = "standalone"
}

output "data_proxmox_acme_plugin" {
  value = data.proxmox_acme_plugin.example
}

data "proxmox_apt_repository" "example" {
  file_path = "/etc/apt/sources.list"
  index     = 0
  node      = "pve"
}

data "proxmox_apt_standard_repository" "example" {
  handle = "no-subscription"
  node   = "pve"
}

data "proxmox_backup_jobs" "all" {}

data "proxmox_ceph_status" "node" {
  node_name = "pve"
}
data "proxmox_datastores" "all" {}
data "proxmox_hagroups" "all" {}
data "proxmox_haresources" "example_all" {}

data "proxmox_hardware_mapping_dir" "example" {
  name = "example"
}
data "proxmox_hardware_mapping_pci" "example" {
  name = "example"
}
data "proxmox_hardware_mapping_usb" "example" {
  name = "example"
}
data "proxmox_hardware_mappings" "example-dir" {
  check_node = "pve"
  type       = "dir"
}
data "proxmox_hardware_pci" "example" {
  node_name = "pve"
}
data "proxmox_metrics_server" "example" {
  name = "example_influxdb"
}
data "proxmox_node_config" "example" {
  node_name = "pve"
}
data "proxmox_replications" "all" {}
data "proxmox_sdn_vnets" "all" {}
data "proxmox_sdn_zones" "all" {}
data "proxmox_version" "example" {}
data "proxmox_virtual_environment_containers" "ubuntu_containers" {
  tags = ["ubuntu"]
}
data "proxmox_virtual_environment_dns" "first_node" {
  node_name = "first-node"
}
data "proxmox_virtual_environment_pools" "available_pools" {}
data "proxmox_virtual_environment_roles" "available_roles" {}
data "proxmox_virtual_environment_vms" "ubuntu_vms" {
  tags = ["ubuntu"]
}
data "proxmox_virtual_environment_users" "available_users" {}
data "proxmox_virtual_environment_time" "first_node_time" {
  node_name = "first-node"
}
