packer {
  required_plugins {
    docker = {
      version = ">= 1.2.3"
      source = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "alpine" {

  proxmox_url              = "https://proxmox.theblacklodge.org:8006/api2/json"
  insecure_skip_tls_verify = true
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = "proxmox"
  task_timeout             = "10m"
  vm_id                    = 9002
  vm_name                  = "alpine"
  ssh_username         = "ansible"
  ssh_private_key_file = "~/.ssh/keys/ansible@theblacklodge.org"

  bios     = "ovmf"
  cpu_type = "host"

  memory = 4096
  cores  = 2

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }
  disks {
    type         = "scsi"
    disk_size    = "32G"
    storage_pool = "local"
  }
  additional_iso_files {
    #cd_files         = ["./http"]
    #cd_label         = "http"
    # Adding iso url as a test
    iso_url = "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/cloud/nocloud_alpine-3.23.4-x86_64-bios-cloudinit-r0.qcow2"
    iso_checksum = "sha256:39fc293200534b03cf805620a099f2f68265220215434fde687536f67a955bc3"

    iso_storage_pool = "isos"
    unmount          = true
  }
  qemu_agent = true

  boot_iso {
    type = "scsi"
    iso_file = "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-virt-3.23.4-x86_64.iso"
    unmount = true
    iso_checksum = "sha256:39fc293200534b03cf805620a099f2f68265220215434fde687536f67a955bc3"
  }


}

build {
  name    = "proxmox-alpine"
  sources = [
    "source.proxmox-iso.alpine"
  ]
}
