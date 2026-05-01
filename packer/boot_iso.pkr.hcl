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

