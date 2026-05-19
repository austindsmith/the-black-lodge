variable "proxmox_username" {
  type = string
}

variable "proxmox_token" {
  type      = string
  sensitive = true
}

variable "root_username" {
  type    = string
  default = "the-black-lodge"
}

variable "root_password" {
  type      = string
  sensitive = true
}

variable "ssh_username" {
  type    = string
  default = "ansible"
}

variable "ssh_private_key_file" {
  type    = string
  default = "~/.ssh/keys/ansible@theblacklodge.org"
}
