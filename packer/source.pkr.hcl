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
