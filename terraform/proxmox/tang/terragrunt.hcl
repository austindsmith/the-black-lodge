include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../modules/proxmox-vm"
}
locals {
  common = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  name        = "tang.theblacklodge.org"
  description = ""
  tags        = ["gitops", "terraform", "packer"]
  vm_id       = 8000
  ram         = 4096

  ipv4_address = "192.168.100.5/24"

}