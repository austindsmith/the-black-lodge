generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "${get_path_from_repo_root()}/terraform.tfstate"
    region = "us-east-1"

    endpoints = {
      s3 = "https://s3.theblacklodge.dev"
    }

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
