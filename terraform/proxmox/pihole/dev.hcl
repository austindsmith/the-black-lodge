inputs = {
  cpu_type               = "host"
  cores                  = 4
  ram                    = 16384
  disk_size              = 100
  datastore_id           = "local-lvm"
  interface              = "virtio0"
  template_id            = 9002
  description            = ""
  pool_id                = "infrastructure"
  ansible_template_type  = "pihole"
  ansible_inventory_path = "${get_repo_root()}/ansible/inventory/dynamic/pihole.yml"
  vlan_id                = 5
  gateway                = "192.168.50.1"
  dns_servers            = ["192.168.1.5"]
  domain                 = "theblacklodge.org"

  username = "ansible"
  ssh_public_keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ87NZyVSmPPFAD2gzBlv3YJSMD+amqBHTIkb5rGDETd austin@theblacklodge.org",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKJX0mh+BfWY7aSt9LccuFdMbJCXEebr6qbI/glX7A6V ansible@theblacklodge.org"
  ]

  tags = ["packer", "proxmox", "gitops", "pihole"]

  nodes = {
    pihole-server-01 = { vm_id = 6000, ip = "192.168.50.10/24" }
  }
}
