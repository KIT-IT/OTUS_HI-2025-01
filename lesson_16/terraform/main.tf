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
  image_id        = "fd808e721rc1vt7jkd0o"
  ssh_public_key  = file("/home/sedunovsv/.ssh/id_ed25519.pub")
  instance_user   = "ubuntu"
}

data "yandex_vpc_network" "network" {
  name = "otus-network"
}

data "yandex_vpc_subnet" "subnet" {
  name = "otus-subnet"
}

resource "yandex_compute_disk" "boot_kafka" {
  name     = "boot-kafka"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = 20
  image_id = local.image_id
}

resource "yandex_compute_disk" "boot_elk" {
  name     = "boot-elk"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = 20
  image_id = local.image_id
}

resource "yandex_compute_disk" "boot_app" {
  name     = "boot-app"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = 20
  image_id = local.image_id
}

resource "yandex_compute_instance" "kafka" {
  name = "kafka-node"

  resources {
    cores  = 4
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot_kafka.id
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${local.instance_user}:${local.ssh_public_key}"
  }
}

resource "yandex_compute_instance" "elk" {
  name = "elk-node"

  resources {
    cores  = 4
    memory = 8
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot_elk.id
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${local.instance_user}:${local.ssh_public_key}"
  }
}

resource "yandex_compute_instance" "app" {
  name = "app-node"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot_app.id
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${local.instance_user}:${local.ssh_public_key}"
  }
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content  = <<EOT
[kafka]
kafka ansible_host=${yandex_compute_instance.kafka.network_interface.0.nat_ip_address} ansible_user=${local.instance_user}

[elk]
elk ansible_host=${yandex_compute_instance.elk.network_interface.0.nat_ip_address} ansible_user=${local.instance_user}

[app]
app ansible_host=${yandex_compute_instance.app.network_interface.0.nat_ip_address} ansible_user=${local.instance_user}

[all:vars]
ansible_ssh_private_key_file=/home/sedunovsv/.ssh/id_ed25519
EOT
}
