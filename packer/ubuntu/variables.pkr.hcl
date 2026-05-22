variable "proxmox_username" {
  type = string
}

variable "proxmox_token" {
  type      = string
  sensitive = true
}

variable "proxmox_url" {
  type = string
}

variable "proxmox_node" {
  description = "Proxmox node ID to create the template on."
  type        = string
}

variable "ssh_password" {
  description = "Root user password."
  type        = string
  sensitive   = true
}

local "ssh_port" {
  expression = "22"
}
