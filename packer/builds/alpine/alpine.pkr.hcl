vm_id                = 9002
template_name        = "alpine"
template_name_suffix = "-v3-20"
template_description = "Alpine Linux cloud image with QEMU guest agent, cloud-init and Python."

disk_size    = "10G"
storage_pool = "local-lvm"
memory       = "1024"
cores        = "2"

iso_url      = "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-virt-3.20.2-x86_64.iso"
iso_checksum = "file:https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-virt-3.20.2-x86_64.iso.sha256"

ssh_timeout = "5m"
boot_wait   = "10s"

boot_command = [
  "root<enter><wait>",
  "ifconfig 'eth0' up && udhcpc -i 'eth0'<enter><wait5s>",
  "setup-alpine -q<enter><wait>",
  "us<enter>",
  "us<enter><wait10s>",
  "setup-timezone -z UTC<enter><wait>",
  "setup-sshd -c openssh<enter><wait>",
  "setup-disk -m sys<enter>",
  "<enter>",
  "y<enter><wait15s>",
  "mount /dev/sda3 /mnt<enter>",
  "echo 'PermitRootLogin yes' >> /mnt/etc/ssh/sshd_config<enter>",
  "echo 'Port 22' >> /mnt/etc/ssh/sshd_config<enter>",
  "reboot<enter><wait30s>",
  "root<enter><wait>",
  "echo 'root:${var.ssh_password}' | chpasswd<enter>",
  "sed -i 's:#\\(.*/v.*/community\\):\\1:' /etc/apk/repositories<enter>",
  "apk update<enter><wait5s>",
  "apk add qemu-guest-agent<enter><wait5s>",
  "sed -i 's:/dev/virtio-ports/org.qemu.guest_agent.0:$(find /dev/vport* | head -n 1):' /etc/init.d/qemu-guest-agent<enter>",
  "rc-update add qemu-guest-agent<enter>",
  "rc-service qemu-guest-agent start<enter>",
]
