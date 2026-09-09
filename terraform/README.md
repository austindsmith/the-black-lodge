# Terraform

Add s3 credentials using the below:

[Source](https://developer.hashicorp.com/terraform/language/backend/s3#shared_credentials_files)

> shared_credentials_file - (Optional, Deprecated, use shared_credentials_files instead) Path to the AWS shared credentials file. Defaults to ~/.aws/credentials.
> shared_credentials_files - (Optional) List of paths to AWS shared credentials files. Defaults to ~/.aws/credentials.

## S3 Backend

```hcl
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
      s3 = "http://10.10.10.5:9000"
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
```
