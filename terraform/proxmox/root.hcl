download_dir = "${get_repo_root()}/.terragrunt-cache"

remote_state {
  backend = "local"
  config = {
    path = "${get_repo_root()}/.tfstate/${path_relative_to_include()}/terraform.tfstate"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.98.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_url
  api_token = var.proxmox_token
  ssh {
    agent    = true
    username = "ansible"
  }
}
EOF
}

terraform {
  extra_arguments "secrets" {
    commands  = get_terraform_commands_that_need_vars()
    arguments = ["-var-file=${get_parent_terragrunt_dir()}/secrets.auto.tfvars"]
  }
  after_hook "ansible" {
    commands = ["apply"]
    execute = [
      "/bin/bash", "-c",
      <<-EOT
        HOSTS=$(terraform output -json vm_names | jq -r '[.[]] | join(",")')
        if [ -z "$HOSTS" ]; then
          echo "ansible hook: vm_names output was empty, skipping"
          exit 0
        fi
        echo "ansible hook: running playbook against $HOSTS"
        cd ${get_repo_root()}/ansible && \
          ansible-playbook site.yml \
            -i inventory/terraform.yml \
            --limit "$HOSTS" \
            -v
      EOT
    ]
    run_on_error = false
  }
}

inputs = {
  ansible_inventory_path = "${get_repo_root()}/ansible/inventory/terraform.yml"
}
