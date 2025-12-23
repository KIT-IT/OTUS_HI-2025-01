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

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

