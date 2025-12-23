variable "zone" {
  description = "YC zone"
  type        = string
  default     = "ru-central1-a"
}

variable "network_name" {
  description = "Existing VPC network name to use"
  type        = string
  default     = "otus-network"
}

variable "subnet_name" {
  description = "Existing subnet name to use"
  type        = string
  default     = "otus-subnet"
}

variable "ssh_public_key_path" {
  description = "SSH public key path to inject for user ubuntu"
  type        = string
  default     = "/home/sedunovsv/.ssh/id_ed25519.pub"
}

variable "mon_count" {
  description = "Number of Ceph monitor nodes"
  type        = number
  default     = 3
}

variable "osd_count" {
  description = "Number of Ceph OSD nodes"
  type        = number
  default     = 3
}

variable "mds_count" {
  description = "Number of Ceph MDS nodes"
  type        = number
  default     = 1
}

variable "client_count" {
  description = "Number of client nodes"
  type        = number
  default     = 2
}

variable "osd_disk_size" {
  description = "Size of OSD disk in GB (учебный стенд, достаточно для ≤ 500 MB данных)"
  type        = number
  default     = 10
}

