include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../modules/proxmox-vm"
}

inputs = {
  name        = "k8s.theblacklodge.org"
  description = ""
  tags        = ["gitops", "terraform", "packer"]
  vm_id       = 8001
  ram         = 8192

  ipv4_address = "192.168.100.15/24"

}