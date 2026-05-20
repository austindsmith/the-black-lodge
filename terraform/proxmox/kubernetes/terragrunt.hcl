include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  inventory = read_terragrunt_config("${get_terragrunt_dir()}/dev.hcl")
  nodes      = read_terragrunt_config("${get_terragrunt_dir()}/dev.hcl").inputs.nodes

}

inputs = local.inventory.inputs

terraform {
    source =  "${get_repo_root()}/terraform/modules/proxmox-vm"
}
