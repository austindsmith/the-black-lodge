###################################################
#                  Configuration                  #
###################################################

terraform {
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
    netcup = {
      source  = "hornc-greedy/netcup"
      version = "1.0.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.4"
    }
  }
}

data "sops_file" "netcup" {
  source_file = "${path.module}/secret.yaml"
}

provider "netcup" {
  customer_number   = data.sops_file.netcup.data["netcup_customer_number"]
  api_key           = data.sops_file.netcup.data["netcup_api_key"]
  api_password      = data.sops_file.netcup.data["netcup_api_password"]
  scp_refresh_token = data.sops_file.netcup.data["netcup_scp_refresh_token"]
}


###################################################
#                  Data sources                   #
###################################################

data "netcup_servers" "all" {}

output "server_ids" {
  value = [for s in data.netcup_servers.all.servers : s.id]
}
