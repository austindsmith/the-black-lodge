include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../modules/proxmox-vm"
}

inputs = {
  name        = "freeipa-server-01.theblacklodge.org"
  description = ""
  tags        = ["gitops", "terraform", "packer"]
  vm_id       = 1000
  ram         = 4096

  ipv4_address = "192.168.100.254/24"

}