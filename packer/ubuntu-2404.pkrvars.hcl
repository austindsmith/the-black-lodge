vm_id = 9000
vm_name      = "ubuntu-server-24.04"
operating_system = "ubuntu"
operating_system_version = "24.04"

memory = 4096
cores = 4

boot_iso = {
  type = "ide"
  iso_url      = "https://releases.ubuntu.com/noble/ubuntu-24.04.4-live-server-amd64.iso"
  iso_checksum = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"
  iso_storage_pool = "local-lvm"
  unmount = true
}

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