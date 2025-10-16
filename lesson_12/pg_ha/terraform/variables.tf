variable "yc_token" { type = string }
variable "yc_cloud_id" { type = string }
variable "yc_folder_id" { type = string }
variable "yc_zone" { 
  type = string 
  default = "ru-central1-a" 
}

variable "network_name" { 
  type = string 
  default = "pg-ha-net" 
}
variable "subnet_cidr" { 
  type = string 
  default = "10.20.0.0/24" 
}

variable "instance_cores" { 
  type = number 
  default = 2 
}
variable "instance_memory" { 
  type = number 
  default = 4 
}
variable "disk_size_gb" { 
  type = number 
  default = 30 
}

variable "patroni_count" { 
  type = number 
  default = 3 
}
variable "haproxy_count" { 
  type = number 
  default = 1 
}

variable "ssh_public_key" { 
  type = string 
}
variable "image_id" { 
  type = string 
  description = "Yandex Cloud image id (e.g. Ubuntu 22.04)" 
}

variable "labels" { 
  type = map(string) 
  default = { 
    project = "saleor-pg-ha" 
  } 
}
