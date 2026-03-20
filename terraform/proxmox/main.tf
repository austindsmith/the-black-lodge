resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.name
  description = var.description
  tags        = var.tags
  node_name   = var.virtual_environment_node_name
  vm_id       = var.vm_id

  started = true
  on_boot = true


  clone {
    vm_id = var.template_id
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size
  }

  cpu {
    cores = var.cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.ram
  }

  network_device {
    vlan_id = var.vlan_id
  }

  initialization {
    user_account {
      username = var.username
      keys     = var.ssh_public_keys
    }
    dns {
      servers = var.dns_servers
      domain  = "theblacklodge.org"
    }
    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.gateway
      }
    }
  }
}

output "vm_ipv4_address" {
  value = proxmox_virtual_environment_vm.vm.ipv4_addresses[1][0]
}
