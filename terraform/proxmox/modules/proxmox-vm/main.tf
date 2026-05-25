resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory-${var.ansible_template_type}.tmpl", {
    nodes = var.nodes
  })
  filename        = var.ansible_inventory_path
  file_permission = "0644"
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = var.nodes

  name        = each.key
  description = var.description
  tags        = var.tags
  pool_id     = var.pool_id
  node_name   = var.proxmox_node
  vm_id       = each.value.vm_id

  started = true
  on_boot = true


  clone {
    vm_id = var.template_id
  }

  agent {
    enabled = true
    timeout = "10m"
  }

  disk {
    datastore_id = var.datastore_id
    interface    = var.interface
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
    datastore_id = var.datastore_id
    user_account {
      username = var.username
      password = var.ssh_password
      keys     = var.ssh_public_keys
    }
    dns {
      servers = var.dns_servers
      domain  = "theblacklodge.org"
    }
    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.gateway
      }
    }
  }
}
