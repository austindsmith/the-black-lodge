inputs = {
  cpu_type     = "host"
  cores        = 2
  ram          = 4096
  disk_size    = 50
  datastore_id = "local-lvm"
  interface    = "scsi0"
  template_id  = 9001
  description  = ""
  pool_id      = "infrastructure"
  type         = "netbox"
  vlan_id      = 2
  gateway      = "192.168.50.1"
  dns_servers  = ["192.168.1.5"]
  domain       = "theblacklodge.org"

  username = "ansible"
  ssh_public_keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ87NZyVSmPPFAD2gzBlv3YJSMD+amqBHTIkb5rGDETd austin@theblacklodge.org",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKJX0mh+BfWY7aSt9LccuFdMbJCXEebr6qbI/glX7A6V ansible@theblacklodge.org"
  ]

  tags = ["packer", "proxmox", "gitops", "infrastructure"]

  nodes = {
    netbox-server-01 = { vm_id = 1001, ip = "192.168.50.5/24" }
  }
}
