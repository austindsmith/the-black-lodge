packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "rocky" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node
  vm_id                    = 9001
  pool                     = var.pool

  template_name        = "rocky-v10-1"
  template_description = "Rocky Linux cloud image with QEMU guest agent and cloud-init."

  cpu_type   = "host"
  memory     = 4096
  cores      = 2
  os         = "l26"
  qemu_agent = true

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disks {
    type         = "virtio"
    disk_size    = "16G"
    storage_pool = "local-lvm"
    format       = "raw"
  }

  ssh_username         = "ansible"
  ssh_private_key_file = "~/.ssh/keys/ansible@theblacklodge.org"
  ssh_timeout          = "10m"

  boot_wait    = "10s"
  boot_command = ["<up><wait><enter><wait>"]


  boot_iso {
    type             = "ide"
    iso_storage_pool = "local"
    iso_url          = "https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10.1-x86_64-boot.iso"
    iso_checksum     = "file:https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10.1-x86_64-boot.iso.CHECKSUM"
    iso_download_pve = true
    unmount          = true
  }

  additional_iso_files {
    cd_files         = ["./cdrom/ks.cfg"]
    cd_label         = "OEMDRV"
    iso_storage_pool = "local"
    unmount          = true
  }

}
build {
  sources = [
    "source.proxmox-iso.rocky",
  ]
  provisioner "shell" {
    execute_command = "echo 'rocky' | {{ .Vars }} sudo -S -E sh -eux '{{ .Path }}'"
    script          = "./scripts/cleanup.sh"
  }
}
