locals {
  secrets = yamldecode(sops_decrypt_file(find_in_parent_folders("remote_state.secret.yaml")))
}
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "local" {
    path = "${get_path_from_repo_root()}/terraform.tfstate"
  }
}
EOF
}
