variable "proxmox_endpoint" {
  type = string
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_insecure" {
  type    = bool
  default = false
}

variable "proxmox_node_name" {
  type    = string
  default = "pve"
}

variable "proxmox_node_address" {
  type = string
}

variable "snippets_datastore_id" {
  type    = string
  default = "local"
}

variable "prefix" {
  type    = string
  default = "generate"
}

variable "windows_template" {
  type    = string
  default = "windows-2025-uefi"
}

variable "username" {
  type    = string
  default = "vagrant"
}

variable "password" {
  type      = string
  sensitive = true
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "timezone" {
  type    = string
  default = "America/Denver"
}

variable "cores" {
  type    = number
  default = 4
}

variable "memory_mb" {
  type    = number
  default = 8192
}

variable "os_disk_gb" {
  type    = number
  default = 80
}

variable "data_disk_gb" {
  type    = number
  default = 64
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}
