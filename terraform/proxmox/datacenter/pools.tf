resource "proxmox_virtual_environment_pool" "infrastructure" {
  pool_id = "infrastructure"
  comment = "Core infrastructure: DNS, auth, backup, secrets"
}

resource "proxmox_virtual_environment_pool" "homelab" {
  pool_id = "homelab"
  comment = "User-facing homelab services"
}

resource "proxmox_virtual_environment_pool" "kubernetes" {
  pool_id = "kubernetes"
  comment = "k3s cluster nodes"
}

resource "proxmox_virtual_environment_pool" "templates" {
  pool_id = "templates"
  comment = "VM and CT base templates"
}
