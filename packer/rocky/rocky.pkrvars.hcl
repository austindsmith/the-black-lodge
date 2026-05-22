vm_id   = 9001
vm_name = "rocky-101"

memory = 4096
cores  = 4


cd_files = ["./http/ks.cfg"]
cd_label = "OEMDRV"

build_sources = [
  "source.proxmox-iso.rocky-101",
]

template_name
template_suffix

boot_command = [
  "<esc><wait>",
  "e<wait>",
  "<end><spacebar>",
  "inst.ks=cdrom:/ks.cfg",
  "<f10>"
]
cleanup_script = "./proxmox/scripts/cleanup-rocky.sh"
