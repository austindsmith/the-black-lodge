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
  pool                     = var.pool

  template_name        = "alpine-v3-20"
  template_description = "Alpine Linux cloud image with QEMU guest agent and cloud-init."

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

  http_directory    = "./http"
  http_port_min     = 8501
  http_port_max     = 8501
  http_bind_address = "0.0.0.0"

  boot_wait = "10s"
  boot_command = [
    "root<enter><wait>",
    "ifconfig eth0 up && udhcpc -i eth0<enter><wait5>",
    "wget http://{{.HTTPIP}}:{{.HTTPPort}}/answers<enter><wait2>",
    "export ERASE_DISKS=/dev/vda<enter>",
    "setup-alpine -f /root/answers<enter><wait5>",
    "Maternal9-Brim4-Bucktooth3-Tribune6-Reoccupy2<enter><wait2>",
    "Maternal9-Brim4-Bucktooth3-Tribune6-Reoccupy2<enter><wait15>",
    "rc-service sshd stop<enter>",
    "mount /dev/vg0/lv_root /mnt<enter>",
    "mount --bind /dev /mnt/dev<enter>",
    "chroot /mnt<enter><wait>",
    "mkdir -p /home/ansible/.ssh<enter>",
    "wget -O /home/ansible/.ssh/authorized_keys http://{{.HTTPIP}}:{{.HTTPPort}}/ssh.keys<enter>",
    "chown -R ansible:ansible /home/ansible/.ssh<enter>",
    "chmod 700 /home/ansible/.ssh<enter>",
    "chmod 600 /home/ansible/.ssh/authorized_keys<enter>",
    "echo https://dl-cdn.alpinelinux.org/alpine/v$(cat /etc/alpine-release | cut -d'.' -f1,2)/community/ >> /etc/apk/repositories<enter><wait>",
    "apk update<enter><wait>",
    "apk upgrade<enter><wait>",
    "apk add --no-cache qemu-guest-agent<enter><wait>",
    "rc-update add qemu-guest-agent<enter>",
    "apk add --no-cache sudo<enter>",
    "mkdir -p /etc/sudoers.d<enter>",
    "echo '%wheel ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/wheel<enter>",
    "chmod 440 /etc/sudoers.d/wheel<enter>",
    "exit<enter>",
    "umount /mnt/dev<enter><wait2>",
    "umount /mnt<enter><wait2>",
    "reboot<enter>",
  ]

  boot_iso {
    type             = "ide"
    iso_storage_pool = "local"
    iso_url          = "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-virt-3.20.2-x86_64.iso"
    iso_checksum     = "file:https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-virt-3.20.2-x86_64.iso.sha256"
    iso_download_pve = true
    unmount          = true
  }

}

build {
  sources = ["source.proxmox-iso.alpine"]

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Path }}'"
    inline = [
      "echo 'https://dl-cdn.alpinelinux.org/alpine/v3.20/community' >> /etc/apk/repositories",
      "apk update",
      "apk add sudo python3 cloud-init e2fsprogs-extra py3-pyserial py3-netifaces",
      "setup-cloud-init",
      "passwd -l root",
      "rm -f /root/.ash_history",
    ]
  }
}
