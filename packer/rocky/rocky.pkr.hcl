packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "rocky" {
  proxmox_url              = var.proxmox_url
  insecure_skip_tls_verify = var.insecure_skip_tls_verify
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node
  task_timeout             = var.task_timeout
  vm_id                    = var.vm_id
  vm_name                  = var.vm_name
  scsi_controller          = "virtio-scsi-pci"

  memory = var.memory
  cores  = var.cores

  iso_storage_pool = "local"
  iso_url          = "https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10.1-x86_64-boot.iso"
  iso_checksum     = "sha256:18543988d9a1a5632d142c3dc288136dcc48ab71628f92ebcd40ada7f4ecd110"

  template_name        = "${var.template_name}${var.template_name_suffix}"
  template_description = var.template_description

  unmount_iso = true

  scsi_controller = "virtio-scsi-single"
  os              = "l26"
  qemu_agent      = true


  boot_iso {
    type             = var.boot_iso_type
    iso_url          = var.iso_url
    iso_checksum     = var.iso_checksum
    iso_storage_pool = var.boot_iso_storage_pool
    iso_download_pve = true
    unmount          = var.boot_unmount
  }


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


}
build {
  sources = [
    "source.proxmox-iso.rocky",
  ]
  provisioner "shell" {
    execute_command = "echo 'rocky' | {{ .Vars }} sudo -S -E sh -eux '{{ .Path }}'"
    script          = var.cleanup_script
  }
}
