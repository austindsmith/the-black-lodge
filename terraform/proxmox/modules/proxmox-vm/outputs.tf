output "vm_ids" {
  description = "Proxmox VM IDs keyed by node name"
  value       = { for k, v in proxmox_virtual_environment_vm.vm : k => v.vm_id }
}

output "vm_ipv4_addresses" {
  description = "Static IPv4 addresses keyed by node name"
  value       = { for k, v in var.nodes : k => v.ip }
}

output "vm_names" {
  description = "VM names as registered in Proxmox"
  value       = { for k, v in proxmox_virtual_environment_vm.vm : k => v.name }
}

output "ansible_template_type" {
  value       = var.ansible_template_type
  description = "Type of generated Ansible template"
}
