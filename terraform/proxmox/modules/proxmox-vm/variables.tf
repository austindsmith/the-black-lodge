variable "virtual_environment_endpoint" {
  type        = string
  description = "The endpoint for the Proxmox Virtual Environment API (example: https://host:port)"
}

variable "virtual_environment_token" {
  type        = string
  description = "The token for the Proxmox Virtual Environment API"
  sensitive   = true
}

variable "virtual_environment_node_name" {
  type        = string
  description = "The node name for the Proxmox Virtual Environment API"
  default     = "proxmox"
}

variable "datastore_id" {
  type        = string
  description = "Datastore for VM disks"
  default     = "local-lvm"
}

variable "name" {
  type = string
}

variable "description" {
  type = string
}

variable "tags" {
  type = list(string)
}

variable "username" {
  type = string
}

variable "ssh_public_keys" {
  type = list(string)
}
variable "disk_size" {
  type = number
}
variable "cores" {
  type = number
}

variable "cpu_type" {
  type = string
}

variable "vm_id" {
  type = string
}

variable "template_id" {
  type = number
}

variable "ram" {
  type = number
}

variable "vlan_id" {
  type = number
}

variable "dns_servers" {
  type = list(string)
}

variable "ipv4_address" {
  type = string
}

variable "gateway" {
  type = string
}
