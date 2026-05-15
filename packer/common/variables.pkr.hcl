variable "proxmox_url" {
  type    = string
  default = "https://proxmox.theblacklodge.org:8006/api2/json"
}
variable "insecure_skip_tls_verify" {
  type    = bool
  default = true
}

variable "proxmox_username" {
  type = string
}

variable "proxmox_token" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "proxmox"
}

variable "task_timeout" {
  type    = string
  default = "10m"
}

variable "vm_name" {
  type = string
}

variable "vm_id" {
  type = number
}

variable "bios" {
  type    = string
  default = "ovmf"
}

variable "cpu_type" {
  type    = string
  default = "host"
}

variable "memory" {
  type = string
}

variable "cores" {
  type = string
}

variable "qemu_agent" {
  type    = bool
  default = true
}

variable "ssh_username" {
  type    = string
  default = "ansible"
}

variable "ssh_private_key_file" {
  type    = string
  default = "~/.ssh/keys/ansible@theblacklodge.org"
}

variable "ssh_timeout" {
  type    = string
  default = "25m"
}

variable "boot_wait" {
  type    = string
  default = "30s"
}

variable "boot_command" {
  type = list(string)
}

variable "model" {
  type    = string
  default = "virtio"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "disk_type" {
  type    = string
  default = "scsi"
}

variable "disk_size" {
  type    = string
  default = "64G"
}

variable "storage_pool" {
  type    = string
  default = "local"
}

variable "build_name" {
  type = string
}

variable "build_sources" {
  type = list(string)
}

variable "boot_iso_type" {
  type    = string
  default = "ide"
}

variable "iso_url" {
  type = string
}

variable "iso_checksum" {
  type = string
}

variable "boot_iso_storage_pool" {
  type    = string
  default = "local"
}

variable "disk_interface" {
  type    = string
  default = "virtio"
}

variable "boot_unmount" {
  type    = bool
  default = true
}

variable "cd_files" {
  type = list(string)
}

variable "cd_label" {
  type    = string
  default = "cidata"
}

variable "additional_iso_storage_pool" {
  type    = string
  default = "isos"
}

variable "additional_unmount" {
  type    = bool
  default = true
}

variable "cleanup_script" {
  type = string
}