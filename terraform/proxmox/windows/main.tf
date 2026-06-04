data "proxmox_virtual_environment_vms" "windows_template" {
  tags = [var.windows_template, "template"]
}

data "proxmox_vm" "windows_template" {
  node_name = data.proxmox_virtual_environment_vms.windows_template.vms[0].node_name
  id        = data.proxmox_virtual_environment_vms.windows_template.vms[0].vm_id
}

resource "proxmox_virtual_environment_vm" "generate" {
  name      = var.prefix
  node_name = var.proxmox_node_name
  tags      = sort([var.windows_template, "generate", "terraform"])

  clone {
    vm_id = data.proxmox_vm.windows_template.id
    full  = false
  }

  cpu {
    type  = "host"
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
  }

  network_device {
    bridge = var.network_bridge
  }

  disk {
    interface   = "scsi0"
    file_format = "raw"
    iothread    = true
    ssd         = true
    discard     = "on"
    size        = var.os_disk_gb
  }

  disk {
    interface   = "scsi1"
    file_format = "raw"
    iothread    = true
    ssd         = true
    discard     = "on"
    size        = var.data_disk_gb
  }

  agent {
    enabled = true
    trim    = true
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.generate_ci_user_data.id
  }
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
  content         = <<-EOF
    [generate]
    ${var.prefix} ansible_host=${proxmox_virtual_environment_vm.generate.ipv4_addresses[index(proxmox_virtual_environment_vm.generate.network_interface_names, "Ethernet")][0]}

    [generate:vars]
    ansible_connection=ssh
    ansible_user=${var.username}
    ansible_shell_type=powershell
    ansible_ssh_common_args=-o StrictHostKeyChecking=no
  EOF
}
