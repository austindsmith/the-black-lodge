vm_id = 9000
vm_name      = "rocky-10.1"

memory = 4096
cores = 4

iso_url      = "https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10.1-x86_64-boot.iso"
iso_checksum = "sha256:18543988d9a1a5632d142c3dc288136dcc48ab71628f92ebcd40ada7f4ecd110"


cd_files = [
  "./cidata/ubuntu-2404/meta-data",
  "./cidata/ubuntu-2404/user-data"
]

build_name = "rocky-x86_64"

build_sources = [
    "source.proxmox-iso.rocky-101",
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