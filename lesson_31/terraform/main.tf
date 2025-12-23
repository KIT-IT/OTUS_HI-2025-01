terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.105.0"
    }
  }
  required_version = ">= 1.6.0"
}

provider "yandex" {
  # cloud_id, folder_id и токен берутся из окружения:
  # YC_TOKEN, YC_CLOUD_ID, YC_FOLDER_ID
  zone = var.zone
}

data "yandex_vpc_network" "this" {
  name = var.network_name
}

data "yandex_vpc_subnet" "this" {
  name = var.subnet_name
}

resource "yandex_vpc_security_group" "k8s" {
  name        = "k8s-sg"
  description = "Access to k8s control plane, nodes, ingress, Vault"
  network_id  = data.yandex_vpc_network.this.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Kubernetes API"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "kubelet/metrics"
    from_port      = 10250
    to_port        = 10255
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "NodePort range"
    from_port      = 30000
    to_port        = 32767
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTPS"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Vault UI/API"
    port           = 8200
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Postgres via NLB"
    port           = 5432
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "TCP"
    description    = "Any outbound TCP"
    from_port      = 1
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts"
}

############################
# Compute instances (k8s)  #
############################
resource "yandex_compute_instance" "master" {
  name        = "k8s-master-1"
  platform_id = "standard-v2"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = data.yandex_vpc_subnet.this.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.k8s.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

############################
# Network Load Balancer    #
############################

resource "yandex_lb_target_group" "frontend_tg" {
  name      = "k8s-frontend-tg"
  region_id = "ru-central1"

  target {
    subnet_id = data.yandex_vpc_subnet.this.id
    address   = yandex_compute_instance.worker[0].network_interface[0].ip_address
  }

  target {
    subnet_id = data.yandex_vpc_subnet.this.id
    address   = yandex_compute_instance.worker[1].network_interface[0].ip_address
  }
}

resource "yandex_lb_network_load_balancer" "frontend_nlb" {
  name                = "k8s-frontend-nlb"
  type                = "external"
  listener {
    name        = "http-80"
    port        = 80
    target_port = 30080
    protocol    = "tcp"
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  listener {
    name        = "pg-5432"
    port        = 5432
    target_port = 5432
    protocol    = "tcp"
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.frontend_tg.id
    healthcheck {
      name = "http-frontend"
      http_options {
        port = 30080
        path = "/"
      }
    }
  }
}

resource "yandex_compute_instance" "worker" {
  count       = var.worker_count
  name        = "k8s-worker-${count.index + 1}"
  platform_id = "standard-v2"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = data.yandex_vpc_subnet.this.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.k8s.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

resource "local_file" "inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content  = templatefile("${path.module}/templates/inventory.tpl", {
    master_ip  = yandex_compute_instance.master.network_interface[0].nat_ip_address
    worker_ips = [for w in yandex_compute_instance.worker : w.network_interface[0].nat_ip_address]
  })
}

