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

variable "proxmox_debug" {
  description = "Enable debug mode"
  type        = bool
  default     = false
}

variable "proxmox_node_name" {
  description = "Name of the Proxmox node where VM will be created"
  type        = string
  default     = "proxmox"
}

variable "ct_hostname" {
  description = "Hostname for LXC container"
  type        = string
  default     = "terraform-ct"
}

variable "ct_tags" {
  description = "Tags for the container"
  type        = list(string)
  default     = ["terraform", "otus"]
}

variable "ct_cpu_cores" {
  description = "Number of CPU cores for the container"
  type        = number
  default     = 2
}

variable "ct_memory" {
  description = "Memory for container in MB"
  type        = number
  default     = 1024
}

variable "ct_disk_datastore" {
  description = "Datastore for container disk (e.g., local-lvm)"
  type        = string
  default     = "local-lvm"
}

variable "ct_disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 8
}

variable "ct_network_bridge" {
  description = "Network bridge (e.g., vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "ct_ip_address" {
  description = "IP address for the container (CIDR notation or dhcp)"
  type        = string
  default     = "dhcp"
}

variable "ct_gateway" {
  description = "Gateway IP address (optional)"
  type        = string
  default     = ""
}

variable "ct_template_file_id" {
  description = "Template file ID for container (e.g., local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst)"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
}

variable "ct_os_type" {
  description = "Container OS type (e.g., debian, ubuntu)"
  type        = string
  default     = "debian"
}

variable "ct_swap" {
  description = "Swap size in MB"
  type        = number
  default     = 512
}

variable "ct_root_password" {
  description = "Root password for container"
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

