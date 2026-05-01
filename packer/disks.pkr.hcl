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