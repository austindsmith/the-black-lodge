download_dir = "${get_repo_root()}/.terragrunt-cache"

locals {
  secrets = yamldecode(sops_decrypt_file("${get_repo_root()}/terraform/azure/secret.yaml"))
}
