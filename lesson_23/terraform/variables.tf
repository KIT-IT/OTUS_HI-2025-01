# Переменные для Terraform конфигурации
# Можно переопределить через terraform.tfvars или через -var

variable "image_id" {
  description = "Yandex Cloud image ID (Ubuntu 22.04)"
  type        = string
  default     = "fd808e721rc1vt7jkd0o"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "/home/sedunovsv/.ssh/id_ed25519.pub"
}

variable "instance_user" {
  description = "Default user for instances"
  type        = string
  default     = "ubuntu"
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "otus-network"
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
  default     = "otus-subnet"
}

variable "nginx_count" {
  description = "Number of Nginx servers"
  type        = number
  default     = 2
}

variable "backend_count" {
  description = "Number of Backend servers"
  type        = number
  default     = 2
}

