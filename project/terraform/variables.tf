# ============================================================================
# Proxmox Provider Variables
# ============================================================================

variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://proxmox.example.com:8006/api2/json)"
  type        = string
  sensitive   = false
}

variable "proxmox_username" {
  description = "Proxmox username (e.g., root@pam)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox user password"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification (useful for self-signed certificates)"
  type        = bool
  default     = true
}

variable "proxmox_node_name" {
  description = "Name of the Proxmox node where containers will be created"
  type        = string
  default     = "proxmox"
}

# ============================================================================
# Common Container Variables
# ============================================================================

variable "domain_name" {
  description = "Domain name for FQDN (e.g., nix.netlab.local)"
  type        = string
  default     = "nix.netlab.local"
}

variable "ct_template_file_id" {
  description = "Template file ID for container (e.g., local:vztmpl/almalinux-10-default_20250930_amd64.tar.xz)"
  type        = string
  default     = "local:vztmpl/almalinux-10-default_20250930_amd64.tar.xz"
}

variable "ct_os_type" {
  description = "Container OS type (e.g., debian, ubuntu, almalinux)"
  type        = string
  default     = "debian"
}

variable "ct_root_password" {
  description = "Root password for containers"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key for container access (can be key content)"
  type        = string
  default     = ""
}

variable "ssh_public_key_file" {
  description = "Path to SSH public key file (alternative to ssh_public_key)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags for all containers"
  type        = list(string)
  default     = ["terraform", "project"]
}

variable "ct_user_name" {
  description = "Username to create on containers"
  type        = string
  default     = "sedunovsv"
}

variable "ct_user_password" {
  description = "Password for the user to create on containers"
  type        = string
  sensitive   = true
  default     = "sedunovsv"
}

# ============================================================================
# Network Variables
# ============================================================================

variable "network_bridge" {
  description = "Network bridge (e.g., vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Gateway IP address"
  type        = string
  default     = "192.168.50.1"
}

# ============================================================================
# HAProxy Variables
# ============================================================================

variable "haproxy_cpu_cores" {
  description = "Number of CPU cores for HAProxy containers"
  type        = number
  default     = 1
}

variable "haproxy_memory" {
  description = "Memory for HAProxy containers in MB"
  type        = number
  default     = 512
}

variable "haproxy_swap" {
  description = "Swap size for HAProxy containers in MB"
  type        = number
  default     = 256
}

variable "haproxy_disk_datastore" {
  description = "Datastore for HAProxy container disk"
  type        = string
  default     = "local-lvm"
}

variable "haproxy_disk_size" {
  description = "Disk size for HAProxy containers in GB"
  type        = number
  default     = 5
}

variable "haproxy_ip_addresses" {
  description = "List of IP addresses for HAProxy containers (CIDR notation)"
  type        = list(string)
  default     = ["192.168.50.11/24", "192.168.50.12/24"]
}

variable "haproxy_vmids" {
  description = "List of VMIDs for HAProxy containers"
  type        = list(number)
  default     = [100, 101]
}

# ============================================================================
# PostgreSQL Variables
# ============================================================================

variable "postgres_cpu_cores" {
  description = "Number of CPU cores for PostgreSQL containers"
  type        = number
  default     = 2
}

variable "postgres_memory" {
  description = "Memory for PostgreSQL containers in MB"
  type        = number
  default     = 2048
}

variable "postgres_swap" {
  description = "Swap size for PostgreSQL containers in MB"
  type        = number
  default     = 512
}

variable "postgres_disk_datastore" {
  description = "Datastore for PostgreSQL container disk"
  type        = string
  default     = "local-lvm"
}

variable "postgres_disk_size" {
  description = "Disk size for PostgreSQL containers in GB"
  type        = number
  default     = 20
}

variable "postgres_disk_size_third" {
  description = "Disk size for third PostgreSQL container in GB (can be smaller if needed)"
  type        = number
  default     = 10
}

variable "postgres_ip_addresses" {
  description = "List of IP addresses for PostgreSQL containers (CIDR notation)"
  type        = list(string)
  default     = ["192.168.50.21/24", "192.168.50.22/24", "192.168.50.23/24"]
}

variable "postgres_vmids" {
  description = "List of VMIDs for PostgreSQL containers"
  type        = list(number)
  default     = [102, 103, 104]
}

# ============================================================================
# Docker Manager Variables
# ============================================================================

variable "docker_manager_cpu_cores" {
  description = "Number of CPU cores for Docker Manager containers"
  type        = number
  default     = 2
}

variable "docker_manager_memory" {
  description = "Memory for Docker Manager containers in MB"
  type        = number
  default     = 1536
}

variable "docker_manager_swap" {
  description = "Swap size for Docker Manager containers in MB"
  type        = number
  default     = 512
}

variable "docker_manager_disk_datastore" {
  description = "Datastore for Docker Manager container disk"
  type        = string
  default     = "local-lvm"
}

variable "docker_manager_disk_size" {
  description = "Disk size for Docker Manager containers in GB"
  type        = number
  default     = 15
}

variable "docker_manager_ip_addresses" {
  description = "List of IP addresses for Docker Manager containers (CIDR notation)"
  type        = list(string)
  default     = ["192.168.50.31/24", "192.168.50.32/24"]
}

variable "docker_manager_vmids" {
  description = "List of VMIDs for Docker Manager containers"
  type        = list(number)
  default     = [105, 106]
}

# ============================================================================
# Docker Worker Variables
# ============================================================================

variable "docker_worker_cpu_cores" {
  description = "Number of CPU cores for Docker Worker containers"
  type        = number
  default     = 4
}

variable "docker_worker_memory" {
  description = "Memory for Docker Worker containers in MB"
  type        = number
  default     = 3072
}

variable "docker_worker_swap" {
  description = "Swap size for Docker Worker containers in MB"
  type        = number
  default     = 1024
}

variable "docker_worker_disk_datastore" {
  description = "Datastore for Docker Worker container disk"
  type        = string
  default     = "local-lvm"
}

variable "docker_worker_disk_size" {
  description = "Disk size for Docker Worker containers in GB"
  type        = number
  default     = 20
}

variable "docker_worker_ip_addresses" {
  description = "List of IP addresses for Docker Worker containers (CIDR notation)"
  type        = list(string)
  default     = ["192.168.50.41/24", "192.168.50.42/24"]
}

variable "docker_worker_vmids" {
  description = "List of VMIDs for Docker Worker containers"
  type        = list(number)
  default     = [107, 108]
}

# ============================================================================
# etcd Variables
# ============================================================================

variable "etcd_cpu_cores" {
  description = "Number of CPU cores for etcd containers"
  type        = number
  default     = 2
}

variable "etcd_memory" {
  description = "Memory for etcd containers in MB"
  type        = number
  default     = 2048
}

variable "etcd_swap" {
  description = "Swap size for etcd containers in MB"
  type        = number
  default     = 512
}

variable "etcd_disk_datastore" {
  description = "Datastore for etcd container disk"
  type        = string
  default     = "local-lvm"
}

variable "etcd_disk_size" {
  description = "Disk size for etcd containers in GB"
  type        = number
  default     = 10
}

variable "etcd_ip_addresses" {
  description = "List of IP addresses for etcd containers (CIDR notation)"
  type        = list(string)
  default     = ["192.168.50.51/24", "192.168.50.52/24", "192.168.50.53/24"]
}

variable "etcd_vmids" {
  description = "List of VMIDs for etcd containers"
  type        = list(number)
  default     = [109, 110, 111]
}
