terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    local = {
      source = "hashicorp/local"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-a"
}

locals {
  image_id        = "fd808e721rc1vt7jkd0o"  # Ubuntu 22.04
  ssh_public_key  = file("/home/sedunovsv/.ssh/id_ed25519.pub")
  instance_user   = "ubuntu"
}

# Используем существующую сеть и подсеть
data "yandex_vpc_network" "network" {
  name = "otus-network"
}

data "yandex_vpc_subnet" "subnet" {
  name = "otus-subnet"
}

# Security Group для Salt Master
resource "yandex_vpc_security_group" "salt_master_sg" {
  name        = "salt-master-sg"
  description = "Security group for Salt Master"
  network_id  = data.yandex_vpc_network.network.id

  ingress {
    description    = "SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Salt publish port"
    protocol       = "TCP"
    port           = 4505
    v4_cidr_blocks = [data.yandex_vpc_subnet.subnet.v4_cidr_blocks[0]]
  }

  ingress {
    description    = "Salt ret port"
    protocol       = "TCP"
    port           = 4506
    v4_cidr_blocks = [data.yandex_vpc_subnet.subnet.v4_cidr_blocks[0]]
  }

  ingress {
    description    = "SaltGUI REST API"
    protocol       = "TCP"
    port           = 8000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "SaltGUI Web UI Frontend"
    protocol       = "TCP"
    port           = 8001
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group для Nginx серверов
resource "yandex_vpc_security_group" "nginx_sg" {
  name        = "nginx-sg"
  description = "Security group for Nginx servers"
  network_id  = data.yandex_vpc_network.network.id

  ingress {
    description    = "SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTPS"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Salt publish port"
    protocol       = "TCP"
    port           = 4505
    v4_cidr_blocks = [data.yandex_vpc_subnet.subnet.v4_cidr_blocks[0]]
  }

  ingress {
    description    = "Salt ret port"
    protocol       = "TCP"
    port           = 4506
    v4_cidr_blocks = [data.yandex_vpc_subnet.subnet.v4_cidr_blocks[0]]
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group для Backend серверов
resource "yandex_vpc_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Security group for Backend servers"
  network_id  = data.yandex_vpc_network.network.id

  ingress {
    description    = "SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Backend port 8000"
    protocol       = "TCP"
    port           = 8000
    v4_cidr_blocks = [data.yandex_vpc_subnet.subnet.v4_cidr_blocks[0]]
  }

  ingress {
    description    = "Backend port 8080"
    protocol       = "TCP"
    port           = 8080
    v4_cidr_blocks = [data.yandex_vpc_subnet.subnet.v4_cidr_blocks[0]]
  }

  ingress {
    description    = "Salt publish port"
    protocol       = "TCP"
    port           = 4505
    v4_cidr_blocks = [data.yandex_vpc_subnet.subnet.v4_cidr_blocks[0]]
  }

  ingress {
    description    = "Salt ret port"
    protocol       = "TCP"
    port           = 4506
    v4_cidr_blocks = [data.yandex_vpc_subnet.subnet.v4_cidr_blocks[0]]
  }

  egress {
    description    = "Allow all outbound"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Boot disk для Salt Master
resource "yandex_compute_disk" "boot_salt_master" {
  name     = "boot-salt-master"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = 20
  image_id = local.image_id
}

# Boot disk для Nginx серверов
resource "yandex_compute_disk" "boot_nginx" {
  count    = 2
  name     = "boot-nginx-${count.index + 1}"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = 20
  image_id = local.image_id
}

# Boot disk для Backend серверов
resource "yandex_compute_disk" "boot_backend" {
  count    = 2
  name     = "boot-backend-${count.index + 1}"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = 20
  image_id = local.image_id
}

# Salt Master ВМ
resource "yandex_compute_instance" "salt_master" {
  name = "salt-master"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot_salt_master.id
  }

  network_interface {
    subnet_id          = data.yandex_vpc_subnet.subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.salt_master_sg.id]
  }

  metadata = {
    ssh-keys = "${local.instance_user}:${local.ssh_public_key}"
  }
}

# Nginx серверы
resource "yandex_compute_instance" "nginx" {
  count = 2
  name  = "nginx-${count.index + 1}"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot_nginx[count.index].id
  }

  network_interface {
    subnet_id          = data.yandex_vpc_subnet.subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.nginx_sg.id]
  }

  metadata = {
    ssh-keys = "${local.instance_user}:${local.ssh_public_key}"
  }
}

# Backend серверы
resource "yandex_compute_instance" "backend" {
  count = 2
  name  = "backend-${count.index + 1}"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot_backend[count.index].id
  }

  network_interface {
    subnet_id          = data.yandex_vpc_subnet.subnet.id
    nat                = false  # Только внутренний IP
    security_group_ids = [yandex_vpc_security_group.backend_sg.id]
  }

  metadata = {
    ssh-keys = "${local.instance_user}:${local.ssh_public_key}"
  }
}

# Генерация Ansible inventory
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content  = <<EOT
[salt_master]
salt-master ansible_host=${yandex_compute_instance.salt_master.network_interface.0.nat_ip_address} ansible_user=${local.instance_user} internal_ip=${yandex_compute_instance.salt_master.network_interface.0.ip_address}

[nginx]
%{ for i, nginx in yandex_compute_instance.nginx ~}
nginx-${i + 1} ansible_host=${nginx.network_interface.0.nat_ip_address} ansible_user=${local.instance_user} internal_ip=${nginx.network_interface.0.ip_address}
%{ endfor ~}

[backend]
%{ for i, backend in yandex_compute_instance.backend ~}
backend-${i + 1} ansible_host=${backend.network_interface.0.ip_address} ansible_user=${local.instance_user} internal_ip=${backend.network_interface.0.ip_address} ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no ubuntu@${yandex_compute_instance.salt_master.network_interface.0.nat_ip_address}"'
%{ endfor ~}

[all:vars]
ansible_ssh_private_key_file=/home/sedunovsv/.ssh/id_ed25519
ansible_python_interpreter=/usr/bin/python3
EOT
}

# Генерация файла с IP адресами для Salt
resource "local_file" "salt_inventory" {
  filename = "${path.module}/../salt-inventory.txt"
  content  = <<EOT
# Salt Master
SALT_MASTER_IP=${yandex_compute_instance.salt_master.network_interface.0.nat_ip_address}
SALT_MASTER_INTERNAL_IP=${yandex_compute_instance.salt_master.network_interface.0.ip_address}

# Nginx servers
%{ for i, nginx in yandex_compute_instance.nginx ~}
NGINX_${i + 1}_IP=${nginx.network_interface.0.nat_ip_address}
NGINX_${i + 1}_INTERNAL_IP=${nginx.network_interface.0.ip_address}
%{ endfor ~}

# Backend servers
%{ for i, backend in yandex_compute_instance.backend ~}
BACKEND_${i + 1}_IP=${backend.network_interface.0.ip_address}
%{ endfor ~}
EOT
}

