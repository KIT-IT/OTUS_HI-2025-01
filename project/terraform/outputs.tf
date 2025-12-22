# ============================================================================
# HAProxy Outputs
# ============================================================================

output "haproxy_hostnames" {
  value       = [for ct in proxmox_virtual_environment_container.haproxy : ct.initialization[0].hostname]
  description = "Hostnames of HAProxy containers"
}

output "haproxy_ips" {
  value       = [for ct in proxmox_virtual_environment_container.haproxy : ct.initialization[0].ip_config[0].ipv4[0].address]
  description = "IP addresses of HAProxy containers"
}

output "haproxy_vmids" {
  value       = [for ct in proxmox_virtual_environment_container.haproxy : ct.vm_id]
  description = "VMIDs of HAProxy containers"
}

# ============================================================================
# PostgreSQL Outputs
# ============================================================================

output "postgres_hostnames" {
  value       = [for ct in proxmox_virtual_environment_container.postgres : ct.initialization[0].hostname]
  description = "Hostnames of PostgreSQL containers"
}

output "postgres_ips" {
  value       = [for ct in proxmox_virtual_environment_container.postgres : ct.initialization[0].ip_config[0].ipv4[0].address]
  description = "IP addresses of PostgreSQL containers"
}

output "postgres_vmids" {
  value       = [for ct in proxmox_virtual_environment_container.postgres : ct.vm_id]
  description = "VMIDs of PostgreSQL containers"
}

# ============================================================================
# Docker Manager Outputs
# ============================================================================

output "docker_manager_hostnames" {
  value       = [for ct in proxmox_virtual_environment_container.docker_manager : ct.initialization[0].hostname]
  description = "Hostnames of Docker Manager containers"
}

output "docker_manager_ips" {
  value       = [for ct in proxmox_virtual_environment_container.docker_manager : ct.initialization[0].ip_config[0].ipv4[0].address]
  description = "IP addresses of Docker Manager containers"
}

output "docker_manager_vmids" {
  value       = [for ct in proxmox_virtual_environment_container.docker_manager : ct.vm_id]
  description = "VMIDs of Docker Manager containers"
}

# ============================================================================
# Docker Worker Outputs
# ============================================================================

output "docker_worker_hostnames" {
  value       = [for ct in proxmox_virtual_environment_container.docker_worker : ct.initialization[0].hostname]
  description = "Hostnames of Docker Worker containers"
}

output "docker_worker_ips" {
  value       = [for ct in proxmox_virtual_environment_container.docker_worker : ct.initialization[0].ip_config[0].ipv4[0].address]
  description = "IP addresses of Docker Worker containers"
}

output "docker_worker_vmids" {
  value       = [for ct in proxmox_virtual_environment_container.docker_worker : ct.vm_id]
  description = "VMIDs of Docker Worker containers"
}

# ============================================================================
# etcd Outputs
# ============================================================================

output "etcd_hostnames" {
  value       = [for ct in proxmox_virtual_environment_container.etcd : ct.initialization[0].hostname]
  description = "Hostnames of etcd containers"
}

output "etcd_ips" {
  value       = [for ct in proxmox_virtual_environment_container.etcd : ct.initialization[0].ip_config[0].ipv4[0].address]
  description = "IP addresses of etcd containers"
}

output "etcd_vmids" {
  value       = [for ct in proxmox_virtual_environment_container.etcd : ct.vm_id]
  description = "VMIDs of etcd containers"
}

# ============================================================================
# Summary Outputs
# ============================================================================

output "all_containers" {
  value = {
    haproxy = {
      hostnames = [for ct in proxmox_virtual_environment_container.haproxy : ct.initialization[0].hostname]
      ips       = [for ct in proxmox_virtual_environment_container.haproxy : ct.initialization[0].ip_config[0].ipv4[0].address]
      vmids     = [for ct in proxmox_virtual_environment_container.haproxy : ct.vm_id]
    }
    postgres = {
      hostnames = [for ct in proxmox_virtual_environment_container.postgres : ct.initialization[0].hostname]
      ips       = [for ct in proxmox_virtual_environment_container.postgres : ct.initialization[0].ip_config[0].ipv4[0].address]
      vmids     = [for ct in proxmox_virtual_environment_container.postgres : ct.vm_id]
    }
    docker_manager = {
      hostnames = [for ct in proxmox_virtual_environment_container.docker_manager : ct.initialization[0].hostname]
      ips       = [for ct in proxmox_virtual_environment_container.docker_manager : ct.initialization[0].ip_config[0].ipv4[0].address]
      vmids     = [for ct in proxmox_virtual_environment_container.docker_manager : ct.vm_id]
    }
    docker_worker = {
      hostnames = [for ct in proxmox_virtual_environment_container.docker_worker : ct.initialization[0].hostname]
      ips       = [for ct in proxmox_virtual_environment_container.docker_worker : ct.initialization[0].ip_config[0].ipv4[0].address]
      vmids     = [for ct in proxmox_virtual_environment_container.docker_worker : ct.vm_id]
    }
    etcd = {
      hostnames = [for ct in proxmox_virtual_environment_container.etcd : ct.initialization[0].hostname]
      ips       = [for ct in proxmox_virtual_environment_container.etcd : ct.initialization[0].ip_config[0].ipv4[0].address]
      vmids     = [for ct in proxmox_virtual_environment_container.etcd : ct.vm_id]
    }
  }
  description = "Summary of all containers with hostnames, IPs, and VMIDs"
}
