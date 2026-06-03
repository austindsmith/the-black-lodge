packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
    windows-update = {
      version = "0.18.1"
      source  = "github.com/rgl/windows-update"
    }
  }
}


variable "http_bind_address" {
  type    = string
  default = "192.168.1.235"
}

source "proxmox-iso" "windows-2025-amd64" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node
  vm_id                    = 9003
  pool                     = var.pool

  template_name        = "windows-2025-uefi"
  template_description = "Windows Server 2025 with VirtIO drivers and OpenSSH."
  tags                 = "windows-2025;template"

  machine  = "q35"
  cpu_type = "host"
  cores    = 2
  memory   = 4096
  os       = "win11"

  vga {
    type   = "qxl"
    memory = 32
  }

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  scsi_controller = "virtio-scsi-single"

  disks {
    type         = "scsi"
    io_thread    = true
    ssd          = true
    discard      = true
    disk_size    = "61440M"
    storage_pool = "local-lvm"
    format       = "raw"
  }

  boot_iso {
    type             = "ide"
    iso_storage_pool = "local"
    iso_url          = "https://go.microsoft.com/fwlink/p/?LinkID=2195280&clcid=0x409&culture=en-us&country=US"
    iso_checksum     = "sha256:3e4fa6d8507b554856fc9ca6079cc402df11a8b79344871669f0251535255325"
    #iso_download_pve = true
    unmount = true
  }

  additional_iso_files {
    type             = "ide"
    unmount          = true
    iso_storage_pool = "local"
    cd_label         = "PROVISION"
    cd_files = [
      "drivers/NetKVM/2k25/amd64/*.cat",
      "drivers/NetKVM/2k25/amd64/*.inf",
      "drivers/NetKVM/2k25/amd64/*.sys",
      "drivers/NetKVM/2k25/amd64/*.exe",
      "drivers/qxldod/2k25/amd64/*.cat",
      "drivers/qxldod/2k25/amd64/*.inf",
      "drivers/qxldod/2k25/amd64/*.sys",
      "drivers/vioscsi/2k25/amd64/*.cat",
      "drivers/vioscsi/2k25/amd64/*.inf",
      "drivers/vioscsi/2k25/amd64/*.sys",
      "drivers/vioserial/2k25/amd64/*.cat",
      "drivers/vioserial/2k25/amd64/*.inf",
      "drivers/vioserial/2k25/amd64/*.sys",
      "drivers/viostor/2k25/amd64/*.cat",
      "drivers/viostor/2k25/amd64/*.inf",
      "drivers/viostor/2k25/amd64/*.sys",
      "drivers/virtio-win-guest-tools.exe",
      "provision-autounattend.ps1",
      "provision-guest-tools-qemu-kvm.ps1",
      "provision-openssh.ps1",
      "provision-psremoting.ps1",
      "provision-pwsh.ps1",
      "provision-winrm.ps1",
      "cdrom/autounattend.xml",
    ]
  }

  ssh_username      = "vagrant"
  ssh_password      = "vagrant"
  ssh_timeout       = "60m"
  http_bind_address = var.http_bind_address
  http_directory    = "."
  boot_wait         = "30s"
}

build {
  sources = ["source.proxmox-iso.windows-2025-amd64"]

  provisioner "powershell" {
    use_pwsh = true
    script   = "disable-windows-updates.ps1"
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "disable-windows-defender.ps1"
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "provision.ps1"
  }

  provisioner "windows-update" {
    filters = [
      "exclude:$_.Title -like '*KB5007651*'",
      "include:$true",
    ]
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "optimize-cleanup-image.ps1"
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "enable-remote-desktop.ps1"
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "provision-cloudbase-init.ps1"
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "provision-lock-screen-background.ps1"
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "eject-media.ps1"
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "optimize.ps1"
  }
}
