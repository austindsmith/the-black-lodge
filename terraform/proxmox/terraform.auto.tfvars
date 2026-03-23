name        = "tang"
description = ""
tags        = ["gitops", "terraform", "packer"]
vm_id       = 8000
template_id = 9000

datastore_id = "local-lvm"

username = "ansible"
ssh_public_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKJX0mh+BfWY7aSt9LccuFdMbJCXEebr6qbI/glX7A6V ansible@theblacklodge.org",
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ87NZyVSmPPFAD2gzBlv3YJSMD+amqBHTIkb5rGDETd austin@theblacklodge.org"
]

disk_size = 64
cores     = 2
cpu_type  = "host"
ram       = 4096

vlan_id      = 5
dns_servers  = ["192.168.1.5", "1.1.1.1"]
ipv4_address = "192.168.100.5/24"
gateway      = "192.168.100.1"
