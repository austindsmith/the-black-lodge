resource "proxmox_virtual_environment_vm" "pbs" {
  name      = "pbs"
  node_name = "black-lodge"
  vm_id     = 9000

  clone {
    vm_id = 9001
    full  = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi1"
    size         = 2000
  }

  initialization {
    ip_config {
      ipv4 {
        address = "10.0.10.20/24"
        gateway = "10.0.10.1"
      }
    }
    user_account {
      username = "austin"
      keys     = [file("~/.ssh/id_ed25519.pub")]
    }
  }

  network_device {
    bridge = "vmbr0"
  }
}

output "pbs_ip" {
  value = "10.0.10.20"
}
