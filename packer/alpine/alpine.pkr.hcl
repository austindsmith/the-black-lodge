packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "alpine" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node
  vm_id                    = 9002

  iso_storage_pool = "local"
  iso_url          = "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-virt-3.20.2-x86_64.iso"
  iso_checksum     = "file:https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-virt-3.20.2-x86_64.iso.sha256"

  template_name        = "alpine-v3-20"
  template_description = "Alpine Linux cloud image with QEMU guest agent, cloud-init and Python."

  scsi_controller = "virtio-scsi-single"
  os              = "l26"
  qemu_agent      = true

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disks {
    type         = "scsi"
    disk_size    = "10G"
    storage_pool = "local-lvm"
    format       = "raw"
    io_thread    = true
  }

  ssh_username = "root"
  ssh_password = var.ssh_password
  ssh_port     = local.ssh_port
  ssh_timeout  = "5m"

  boot_command = [
    "root<enter><wait>",
    "ifconfig 'eth0' up && udhcpc -i 'eth0'<enter><wait5s>",
    "setup-alpine -q<enter><wait>",
    "us<enter>",
    "us<enter><wait10s>",
    "setup-timezone -z Israel<enter><wait>",
    "setup-sshd -c openssh<enter><wait>",
    "setup-disk -m sys<enter>",
    "<enter>",
    "y<enter><wait15s>",
    "mount /dev/sda3 /mnt<enter>",
    "echo 'PermitRootLogin yes' >> /mnt/etc/ssh/sshd_config<enter>",
    "echo 'Port ${local.ssh_port}' >> /mnt/etc/ssh/sshd_config<enter>",
    "reboot<enter><wait30s>",
    "root<enter><wait>",
    "echo 'root:${var.ssh_password}' | chpasswd<enter>",
    "sed -i 's:#\\(.*/v.*/community\\):\\1:' /etc/apk/repositories<enter>",
    "apk update<enter><wait5s>",
    "apk add qemu-guest-agent<enter><wait5s>",
    "sed -i 's:/dev/virtio-ports/org.qemu.guest_agent.0:$(find /dev/vport* | head -n 1):' /etc/init.d/qemu-guest-agent<enter>",
    "rc-update add qemu-guest-agent<enter>",
    "rc-service qemu-guest-agent start<enter>",
  ]

  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"
}

build {
  sources = ["source.proxmox-iso.alpine"]

  provisioner "shell" {
    inline = [
      "apk add python3 py3-pip sudo",
      "apk add cloud-init e2fsprogs-extra mount py3-pyserial py3-netifaces",
      "setup-cloud-init",
    ]
  }

  provisioner "shell" {
    inline = [
      "sed -i '/PermitRootLogin yes/d' /etc/ssh/sshd_config",
      "passwd --lock root",
      "rm -rf /root/.ash_history"
    ]
  }
}
