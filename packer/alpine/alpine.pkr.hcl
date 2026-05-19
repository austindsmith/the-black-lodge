packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}
locals {
  ssh_public_key = file("~/.ssh/keys/ansible@theblacklodge.org.pub")
}
source "proxmox-iso" "alpine" {
  http_port_min            = 8501
  http_port_max            = 8501
  http_bind_address        = "0.0.0.0"
  http_directory           = "./http"
  proxmox_url              = "https://proxmox.theblacklodge.org:8006/api2/json"
  insecure_skip_tls_verify = true
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = "proxmox"
  scsi_controller          = "virtio-scsi-pci"
  task_timeout             = "10m"
  vm_id                    = 9002
  vm_name                  = "alpine"
  ssh_username             = "ansible"
  ssh_private_key_file     = "~/.ssh/keys/ansible@theblacklodge.org"

  #bios     = "ovmf"
  cpu_type = "host"

  memory = 4096
  cores  = 2

  boot_wait = "15s"

  boot = "order=scsi0;ide0;net0"

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }
  disks {
    type         = "scsi"
    disk_size    = "32G"
    storage_pool = "local"
  }

  boot_iso {
    type             = "ide"
    iso_url          = "https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64/alpine-virt-3.23.4-x86_64.iso"
    unmount          = true
    iso_checksum     = "sha256:f802033362595ad55de7bce00c500c51a756c94e229768afdcf7e68e49994c48"
    iso_storage_pool = "isos"
    iso_download_pve = true
  }

  additional_iso_files {
    cd_files = ["./http"]
    cd_label = "http"

    iso_storage_pool = "local"
    unmount          = true
  }
  qemu_agent = true

  template_name = join("-", [
    "alpine-template",
    "base",
    formatdate("YYYYMMDD-hhmm", timestamp()),
  ])

  boot_command = [
    "root<enter><wait>",
    "mount /dev/sr1 /mnt<enter><wait3>",
    "cat /mnt/http/ssh.keys<enter><wait3>",
    "ifconfig eth0 up && udhcpc -i eth0<enter><wait5>",
    "export ERASE_DISKS=/dev/sda<enter>",
    "export USEROPTS='-a -u -g audio,video,netdev ${var.ssh_username}'<enter>",
    "export USERSSHKEY=/mnt/http/ssh.keys<enter>",
    "setup-alpine -f /mnt/http/answers<enter><wait5>",
    "${var.root_password}<enter><wait>",
    "${var.root_password}<enter><wait15>",
    "echo 'PermitRootLogin yes' >> /mnt/etc/ssh/sshd_config<enter>",
    "umount /mnt; reboot<enter>"
  ]

}

build {
  name = "proxmox-alpine"
  sources = [
    "source.proxmox-iso.alpine"
  ]
}
