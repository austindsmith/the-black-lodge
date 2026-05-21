variable "proxmox_url" {
  type        = string
  description = "The endpoint for the Proxmox Virtual Environment API (example: https://host:port)"
}

variable "proxmox_token" {
  type        = string
  description = "The token for the Proxmox Virtual Environment API"
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "The node name for the Proxmox Virtual Environment API"
  default     = "proxmox"
}
