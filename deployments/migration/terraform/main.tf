terraform {
  # Utilizes .envrc to pull from encrypted secret.yaml.
  backend "s3" {
    bucket                      = "state"
    key                         = "migration/netcup.tfstate"
    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
  required_providers {
    # Allows access to netcup. See hornc-greedy/netcup GitHub for API access docs.
    netcup = {
      source  = "hornc-greedy/netcup"
      version = "1.0.0"
    }
    # Allows SOPs decryption of secrets.
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.4"
    }
    # Allows access to local file system.
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9.0"
    }
  }
}
