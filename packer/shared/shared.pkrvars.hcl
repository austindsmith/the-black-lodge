proxmox_url      = "https://proxmox.theblacklodge.org:8006/api2/json"
proxmox_node     = "proxmox"
insecure_skip_tls_verify = true
task_timeout = "10m"
qemu_agent = true
ssh_username = "the_black_lodge"
ssh_private_key_file = "~/.ssh/keys/ansible@theblacklodge.org"
ssh_timeout = "25m"
boot_wait = "30s"
boot_iso = {
    type = "ide"
    iso_url = ""
    iso_checksum = ""
    iso_storage_pool = "isos"
    disk_interface = "virtio"
    unmount = true
}

network_adapters = {
    model  = "virtio"
    bridge = "vmbr0"
}

disks = {
    type  = "scsi"
    disk_size = "64G"
    storage_pool = "local-lvm"
}

additional_iso_files = {
    cd_files = [
      "./ubuntu-2404/cidata/meta-data",
      "./ubuntu-2404/cidata/user-data"
    ]
    cd_label         = "cidata"
    iso_storage_pool = "isos"
    unmount          = true
}

build = {
  name = "ubuntu-x86_64"
  sources = [
    "source.proxmox-iso.ubuntu-2404",
  ]
}