include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "remote_state" {
  path = find_in_parent_folders("remote_state.hcl")
}

locals {
  local_secrets  = yamldecode(sops_decrypt_file("${get_terragrunt_dir()}/secret.yaml"))
  merged_secrets = merge(include.root.locals.secrets, local.local_secrets)
  configuration  = read_terragrunt_config("${get_terragrunt_dir()}/configuration.hcl")
}

inputs = local.configuration.inputs


generate "secrets" {
  path      = "secrets.auto.tfvars"
  if_exists = "overwrite"
  contents = join("\n", [
    for k, v in local.merged_secrets : "${k} = \"${v}\""
  ])
}

generate "variables" {
  path      = "variables.tf"
  if_exists = "overwrite"
  contents  = file("${get_repo_root()}/terraform/cloudflare/common/variables.tf")
}
