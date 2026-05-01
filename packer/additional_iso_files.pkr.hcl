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