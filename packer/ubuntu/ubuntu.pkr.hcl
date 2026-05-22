packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "ubuntu" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node
  vm_id                    = 9000

  template_name        = "ubuntu-v24-04"
  template_description = "Ubuntu Linux cloud image with QEMU guest agent, cloud-init and Python."

  memory     = 4096
  cores      = 2
  os         = "l26"
  qemu_agent = true

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disks {
    type         = "scsi"
    disk_size    = "16G"
    storage_pool = "local-lvm"
    format       = "raw"
  }

  ssh_username         = "ansible"
  ssh_private_key_file = "~/.ssh/keys/ansible@theblacklodge.org"
  ssh_port             = local.ssh_port
  ssh_timeout          = "10m"

  boot_command = [
    "<esc><wait>",
    "<esc><wait>",
    "c<wait>",
    "set gfxpayload=keep",
    "<enter><wait>",
    "linux /casper/vmlinuz quiet<wait>",
    " autoinstall<wait>",
    " ds=nocloud;<wait>",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot<enter><wait>",
  ]

  boot_iso {
    type             = "ide"
    iso_storage_pool = "local"
    iso_url          = "https://releases.ubuntu.com/noble/ubuntu-24.04.4-live-server-amd64.iso"
    iso_checksum     = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"
    iso_download_pve = true
    unmount          = true
  }

  additional_iso_files {
    cd_files         = ["./http/user-data", "./http/meta-data"]
    cd_label         = "cidata"
    iso_storage_pool = "local"
    unmount          = true
  }

}
build {
  sources = [
    "source.proxmox-iso.ubuntu",
  ]
  provisioner "shell" {
    execute_command = "echo 'ubuntu' | {{ .Vars }} sudo -S -E sh -eux '{{ .Path }}'"
    script          = "./scripts/cleanup.sh"
  }
}
