locals {
  secrets = yamldecode(sops_decrypt_file(find_in_parent_folders("remote_state.secret.yaml")))
}
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {
    bucket = "terraform"
    key = "${path_relative_to_include("remote_state")}/terraform.tfstate"
    region = "us-east-1"
    endpoints = {
      s3 = "https://d0ed396d44b40901c9b05eae7bbcb1a2.r2.cloudflarestorage.com"
    }
    access_key                  = "${local.secrets.cloudflare_access_key}"
    secret_key                  = "${local.secrets.cloudflare_secret_key}"
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
