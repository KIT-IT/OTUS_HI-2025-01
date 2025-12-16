output "ct_id" {
  value       = proxmox_virtual_environment_container.ct.id
  description = "Container ID in Proxmox"
}

output "ct_vmid" {
  value       = proxmox_virtual_environment_container.ct.vm_id
  description = "Proxmox VMID of the container"
}

output "ct_hostname" {
  value       = proxmox_virtual_environment_container.ct.initialization[0].hostname
  description = "Container hostname"
}

output "ct_node" {
  value       = proxmox_virtual_environment_container.ct.node_name
  description = "Proxmox node where container is running"
}

output "ct_cpu_cores" {
  value       = proxmox_virtual_environment_container.ct.cpu[0].cores
  description = "Number of CPU cores"
}

output "ct_memory" {
  value       = proxmox_virtual_environment_container.ct.memory[0].dedicated
  description = "Container memory in MB"
}

output "ct_configured_ip" {
  value       = var.ct_ip_address
  description = "Configured IP for the container"
}
