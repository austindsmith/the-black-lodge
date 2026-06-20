###################################################
#                  Configuration                  #
###################################################

terraform {
  backend "local" { path = "../../.tfstate/rustfs/terraform.tfstate" }
  required_providers {
    rustfs = {
      source  = "weinmann-emt/rustfs"
      version = "0.0.7"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.4"
    }
  }
}

data "sops_file" "rustfs" {
  source_file = "${path.module}/secret.yaml"
}

provider "rustfs" {
  access_key    = data.sops_file.rustfs.data["access_key"]
  access_secret = data.sops_file.rustfs.data["access_secret"]
  endpoint      = data.sops_file.rustfs.data["endpoint"]
}

###################################################
#                    Data lake                    #
###################################################

resource "rustfs_bucket" "data-lake-source" {
  name = "data-lake-source"
}

resource "rustfs_bucket" "data-lake-staging" {
  name = "data-lake-staging"
}

resource "rustfs_bucket" "data-lake-marts" {
  name = "data-lake-marts"
}

###################################################
#                      State                      #
###################################################

resource "rustfs_bucket" "state" {
  name = "state"
}

###################################################
#                    Artifacts                    #
###################################################

resource "rustfs_bucket" "artifacts" {
  name = "artifacts"
}

###################################################
#                     Scratch                     #
###################################################

resource "rustfs_bucket" "scratch" {
  name = "scratch"
}
