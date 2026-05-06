vm_id = 9001
vm_name      = "rocky-101"

memory = 4096
cores = 4

iso_url      = "https://download.rockylinux.org/pub/rocky/10/isos/x86_64/Rocky-10.1-x86_64-boot.iso"
iso_checksum = "sha256:18543988d9a1a5632d142c3dc288136dcc48ab71628f92ebcd40ada7f4ecd110"


cd_files = ["./cidata/ks.cfg"]
cd_label = "OEMDRV"

build_name = "rocky-x86-64"

build_sources = [
    "source.proxmox-iso.rocky-101",
  ]

boot_command = [
  "<up><wait>",
  "e<wait>",
  "<down><down><end>",
  " inst.ks=cdrom<wait>",
  "<leftCtrlOn>x<leftCtrlOff>",
]

cleanup_script = "./iso/scripts/cleanup-rocky.sh"
