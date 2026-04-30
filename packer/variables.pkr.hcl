variable "proxmox_url" {
  type = string
}

variable "insecure_skip_tls_verify" {
  type = bool
}

variable "proxmox_username" {
  type = string
}

variable "proxmox_token" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type = string
}

variable "task_timeout" {
  type = string
}

variable "qemu_agent" {
  type = bool
}

variable "ssh_username" {
  type = string
}

variable "ssh_private_key_file" {
  type = string
}

variable "ssh_timeout" {
  type = string
}

variable "boot_wait" {
  type = string
}

variable "vm_name" {
  type = string
}

variable "vm_id" {
  type = number
}

variable "operating_system" {
  type = string
}

variable "operating_system_version" {
  type = string
}

variable "memory" {
  type = string
}

variable "cores" {
  type = string
}

variable "boot_command" {
  type = list(string)
}

variable "boot_iso" {
  type = object({
    type             = string
    iso_url          = string
    iso_checksum     = string
    iso_storage_pool = string
    unmount          = bool
  })
}

variable "network_adapters" {
  type = object({
    model  = string
    bridge = string
  })
}

variable "disks" {
  type = object({
    type         = string
    disk_size    = string
    storage_pool = string
  })
}

variable "additional_iso_files" {
  type = object({
    cd_files         = list(string)
    cd_label         = string
    iso_storage_pool = string
    unmount          = bool
  })
}

variable "build" {
  type = object({
    name    = string
    sources = list(string)
  })
}