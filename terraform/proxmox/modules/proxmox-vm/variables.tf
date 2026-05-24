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
  description = "The Proxmox node on which VMs will be created"
  default     = "proxmox"
}

variable "pool_id" {
  type        = string
  description = "The pool to assign VMs for organization"
}

variable "template_id" {
  type        = number
  description = "VM ID of the Proxmox template to clone"
}

variable "nodes" {
  type = map(object({
    ip    = string
    vm_id = number
  }))
  description = "Map of VM names to their IP address and VM ID"
}

variable "description" {
  type        = string
  description = "Description applied to each VM"
}

variable "tags" {
  type        = list(string)
  description = "Tags applied to each VM"
}

variable "cores" {
  type        = number
  description = "Number of CPU cores per VM"
}

variable "cpu_type" {
  type        = string
  description = "CPU type (e.g. host, kvm64, x86-64-v2-AES)"
}

variable "ram" {
  type        = number
  description = "Dedicated RAM in MB per VM"
}

variable "datastore_id" {
  type        = string
  description = "Proxmox datastore for VM disks"
  default     = "local-lvm"
}

variable "disk_size" {
  type        = number
  description = "Root disk size in GB"
}

variable "vlan_id" {
  type        = number
  description = "VLAN tag for the VM network interface"
}

variable "gateway" {
  type        = string
  description = "Default IPv4 gateway for VM network configuration"
}

variable "dns_servers" {
  type        = list(string)
  description = "List of DNS servers for cloud-init network configuration"
}

variable "username" {
  type        = string
  description = "Default user created via cloud-init"
}

# Can be removed if openssh PAM starts working
variable "ssh_password" {
  type        = string
  description = "SSH password added to the cloud-init user, needed for Alpine"
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys added to the cloud-init user"
}

variable "ansible_inventory_path" {
  type    = string
  default = ""
}

variable "ansible_template_type" {
  type        = string
  description = "Type of Ansible template to use"
}
