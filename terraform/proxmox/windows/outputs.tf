output "ip" {
  value = proxmox_virtual_environment_vm.generate.ipv4_addresses[index(proxmox_virtual_environment_vm.generate.network_interface_names, "Ethernet")][0]
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.generate.vm_id
}
