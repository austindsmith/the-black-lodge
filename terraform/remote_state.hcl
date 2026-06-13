remote_state {
  backend = "s3"
  config = {
    bucket                      = "tf-state"
    key                         = "${path_relative_to_include()}/terraform.tfstate"
    region                      = "us-east-1"
    endpoint                    = "https://nas.theblacklodge.dev:9000"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
    encrypt                     = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terraform"
  }
}
