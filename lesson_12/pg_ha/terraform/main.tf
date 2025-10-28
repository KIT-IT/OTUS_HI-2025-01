locals {
  patroni_names = [for i in range(var.patroni_count) : format("patroni-%02d", i+1)]
}

resource "yandex_vpc_network" "net" {
  name   = var.network_name
  labels = var.labels
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "${var.network_name}-subnet"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = [var.subnet_cidr]
  labels         = var.labels
}

resource "yandex_vpc_security_group" "sg" {
  name        = "pg-ha-sg"
  network_id  = yandex_vpc_network.net.id
  description = "Allow SSH, HAProxy, Postgres, inter-node"

  ingress {
    protocol       = "tcp"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "tcp"
    description    = "HAProxy frontend"
    port           = 5432
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "tcp"
    description    = "HTTP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "tcp"
    description    = "HTTPS"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "tcp"
    description    = "Saleor API"
    port           = 8000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "tcp"
    description    = "HAProxy Saleor Dashboard"
    port           = 9000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "tcp"
    description    = "Saleor Storefront"
    port           = 3000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "tcp"
    description    = "PostgreSQL direct (intra)"
    port           = 5432
    v4_cidr_blocks = [var.subnet_cidr]
  }

  ingress {
    protocol       = "tcp"
    description    = "Patroni/etcd/raft intra"
    from_port      = 1
    to_port        = 65535
    v4_cidr_blocks = [var.subnet_cidr]
  }

  egress {
    protocol       = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance_group" "patroni" {
  name               = "patroni-group"
  folder_id          = var.yc_folder_id
  service_account_id = "ajeblp4m9hckn7r41pto"

  instance_template {
    platform_id = "standard-v3"

    resources {
      cores         = var.instance_cores
      memory        = var.instance_memory
      core_fraction = 100
    }

    boot_disk {
      initialize_params {
        image_id = var.image_id
        size     = var.disk_size_gb
        type     = "network-ssd"
      }
    }

    network_interface {
      subnet_ids         = [yandex_vpc_subnet.subnet.id]
      security_group_ids = [yandex_vpc_security_group.sg.id]
      nat                = true
    }

    metadata = {
      ssh-keys = "ubuntu:${var.ssh_public_key}"
      ssh_public_key = var.ssh_public_key
    }
    labels = merge(var.labels, { role = "patroni" })
  }

  scale_policy {
    fixed_scale {
      size = var.patroni_count
    }
  }

  allocation_policy {
    zones = [var.yc_zone]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }
}

resource "yandex_compute_instance" "haproxy" {
  name        = "haproxy-1"
  zone        = var.yc_zone
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 10
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet.id
    security_group_ids = [yandex_vpc_security_group.sg.id]
    nat                = true
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
    ssh_public_key = var.ssh_public_key
  }
  labels = merge(var.labels, { role = "haproxy" })
}

resource "yandex_compute_instance" "saleor" {
  name        = "saleor-1"
  zone        = var.yc_zone
  platform_id = "standard-v3"

  resources {
    cores         = 4
    memory        = 8
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 30
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet.id
    security_group_ids = [yandex_vpc_security_group.sg.id]
    nat                = true
  }

  metadata = {
    ssh-keys       = "ubuntu:${var.ssh_public_key}"
    ssh_public_key = var.ssh_public_key
  }
  labels = merge(var.labels, { role = "saleor" })
}

resource "yandex_compute_instance" "storefront" {
  name        = "storefront-1"
  zone        = var.yc_zone
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet.id
    security_group_ids = [yandex_vpc_security_group.sg.id]
    nat                = true
  }

  metadata = {
    ssh-keys       = "ubuntu:${var.ssh_public_key}"
    ssh_public_key = var.ssh_public_key
  }
  labels = merge(var.labels, { role = "storefront" })
}

output "haproxy_public_ip" {
  value = yandex_compute_instance.haproxy.network_interface[0].nat_ip_address
}

output "subnet_id" {
  value = yandex_vpc_subnet.subnet.id
}

output "saleor_public_ip" {
  value = yandex_compute_instance.saleor.network_interface[0].nat_ip_address
}

output "storefront_public_ip" {
  value = yandex_compute_instance.storefront.network_interface[0].nat_ip_address
}
