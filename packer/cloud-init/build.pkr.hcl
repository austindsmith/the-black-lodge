packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "virtual-machine" {

  proxmox_url              = var.proxmox_url
  insecure_skip_tls_verify = var.insecure_skip_tls_verify
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  task_timeout             = var.task_timeout

  vm_id   = var.vm_id
  vm_name = var.vm_name

  memory = var.memory
  cores  = var.cores

  network_adapters {
    model  = var.model
    bridge = var.bridge
  }

  boot_iso {
    type             = "download"
    iso_url          = var.iso_url
    iso_checksum     = var.iso_checksum
    iso_storage_pool = var.boot_iso_storage_pool
    disk_image       = true
    iso_download_pve = true
    unmount          = true
  }

  disks {
    type         = var.disk_type
    disk_size    = var.disk_size
    storage_pool = var.storage_pool
    io_thread    = true
  }

  additional_iso_files {
    device           = "ide2"
    cd_files         = var.cd_files
    cd_label         = var.cd_label
    iso_storage_pool = var.additional_iso_storage_pool
    unmount          = var.additional_unmount
  }

  qemu_agent = var.qemu_agent

  ssh_username         = var.ssh_username
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = var.ssh_timeout

  boot_command = []

  template_name = join("-", [
    var.vm_name,
    "base",
    formatdate("YYYYMMDD-hhmm", timestamp()),
  ])
}

build {

  sources = [
    "source.proxmox-iso.virtual-machine",
  ]

  provisioner "shell" {
    execute_command = "echo 'packer' | {{ .Vars }} sudo -S -E sh -eux '{{ .Path }}'"

    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 2; done",

      "sudo rm -f /etc/ssh/ssh_host_*",

      "sudo truncate -s 0 /etc/machine-id",

      "sudo dnf clean all || true",
      "sudo yum clean all || true",

      "sudo cloud-init clean",

      "sudo sync"
    ]
  }
}