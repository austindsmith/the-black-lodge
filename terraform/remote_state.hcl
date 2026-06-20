locals {
  secrets = yamldecode(sops_decrypt_file(find_in_parent_folders("remote_state.secret.yaml")))
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {
    bucket = "state"
    key    = "${get_path_from_repo_root()}/terraform.tfstate"
    region = "us-east-1"
    endpoints = {
      s3 = "http://192.168.1.131:9000"
    }
    access_key                  = "${local.secrets.rustfs_access_key}"
    secret_key                  = "${local.secrets.rustfs_secret_key}"
    use_path_style              = true
    use_lockfile                = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}
EOF
}
