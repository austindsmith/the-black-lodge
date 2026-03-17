packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_username" {
  type = string
}

variable "proxmox_token" {
  type      = string
  sensitive = true
}

source "proxmox-iso" "ubuntu-2404" {
  proxmox_url              = "https://proxmox.theblacklodge.org:8006/api2/json"
  insecure_skip_tls_verify = true
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = "proxmox"
  task_timeout             = "10m"

  boot_iso {
    iso_url          = "https://releases.ubuntu.com/noble/ubuntu-24.04.4-live-server-amd64.iso"
    iso_checksum     = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"
    iso_storage_pool = "isos"
    unmount          = true
  }
  memory = 2048
  cores  = 4
  os     = "l26"

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }
  disks {
    type         = "scsi"
    disk_size    = "64G"
    storage_pool = "local-lvm"
  }
  additional_iso_files {
    cd_files         = ["./packer/ubuntu-2404/cidata/*"]
    cd_label         = "cidata"
    iso_storage_pool = "isos"
    unmount          = true
  }
  qemu_agent = true

  ssh_username         = "ubuntu"
  ssh_private_key_file = "~/.ssh/keys/ansible@theblacklodge.org"
  ssh_timeout          = "25m"

  boot_wait = "15s"

  # Commands for GRUB, bootloader and general ISO install. May need to tweak. https://developer.hashicorp.com/packer/docs/builders/virtualbox/iso#boot-command
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

  template_name = join("-", [
    "ubuntu",
    "2404",
    "base",
    formatdate("YYYYMMDD-hhmm", timestamp()),
  ])
}
build {
  name = "ubuntu-x86_64"
  sources = [
    "source.proxmox-iso.ubuntu-2404",
  ]
  # Clean up the machine for cloud-init
  provisioner "shell" {
    execute_command = "echo 'ubuntu' | {{ .Vars }} sudo -S -E sh -eux '{{ .Path }}'"
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo rm /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt -y autoremove --purge",
      "sudo apt -y clean",
      "sudo apt -y autoclean",
      "sudo cloud-init clean",
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo sync"
    ]
  }
}

