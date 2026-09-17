include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "remote_state" {
  path = find_in_parent_folders("remote_state.hcl")
}

locals {
  inventory = read_terragrunt_config("${get_terragrunt_dir()}/dev.hcl")
  nodes     = read_terragrunt_config("${get_terragrunt_dir()}/dev.hcl").inputs.nodes

}

inputs = local.inventory.inputs

terraform {
  source = "${get_parent_terragrunt_dir("root")}/modules/proxmox-vm"
}
