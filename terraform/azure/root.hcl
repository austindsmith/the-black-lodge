download_dir = "${get_repo_root()}/.terragrunt-cache"

include "remote_state" {
  path = find_in_parent_folders("remote_state.hcl")
}

locals {
  secrets = yamldecode(sops_decrypt_file("${get_repo_root()}/terraform/azure/secret.yaml"))
}
