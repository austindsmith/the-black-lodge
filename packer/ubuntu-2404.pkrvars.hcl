vm_id = 9000
vm_name      = "ubuntu-server-24.04"

memory = 4096
cores = 4

iso_url      = "https://releases.ubuntu.com/noble/ubuntu-24.04.4-live-server-amd64.iso"
iso_checksum = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"


cd_files = [
  "./cidata/ubuntu-2404/meta-data",
  "./cidata/ubuntu-2404/user-data"
]

build_name = "ubuntu-x86_64"

build_sources = [
    "source.proxmox-iso.ubuntu-2404",
  ]

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