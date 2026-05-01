packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.1"
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
  vm_id                    = var.vm_id
  vm_name                  = var.vm_name

  boot_iso {
    type             = var.boot_iso_type
    iso_url          = var.iso_url
    iso_checksum     = var.iso_checksum
    iso_storage_pool = var.boot_iso_storage_pool
    unmount          = var.boot_unmount
  }
  bios   = var.bios
  memory = var.memory
  cores  = var.cores

  network_adapters {
    model  = var.model
    bridge = var.bridge
  }
  disks {
    type         = var.disk_type
    disk_size    = var.disk_size
    storage_pool = var.storage_pool
  }
  additional_iso_files {
    cd_files         = var.cd_files
    cd_label         = var.cd_label
    iso_storage_pool = var.additional_iso_storage_pool
    unmount          = var.additional_unmount
  }
  qemu_agent = var.qemu_agent

  ssh_username         = var.ssh_username
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = var.ssh_timeout

  boot_wait = var.boot_wait

  boot_command = var.boot_command

  template_name = join("-", [
    var.vm_name,
    "base",
    formatdate("YYYYMMDD-hhmm", timestamp()),
  ])
}
build {
  name = var.build_name
  sources = [
    "source.proxmox-iso.virtual-machine",
  ]
  # Clean up the machine for cloud-init
  provisioner "shell" {
    execute_command = "echo 'virtual-machine' | {{ .Vars }} sudo -S -E sh -eux '{{ .Path }}'"
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

