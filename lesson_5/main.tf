terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-a"
}

resource "yandex_vpc_network" "gfs2_net" {
  name = "gfs2-network"
}

resource "yandex_vpc_subnet" "gfs2_subnet" {
  name           = "gfs2-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.gfs2_net.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

# iSCSI Target Server
resource "yandex_compute_disk" "iscsi_disk" {
  name     = "iscsi-disk"
  type     = "network-ssd"
  zone     = "ru-central1-a"
  size     = 20
}

resource "yandex_compute_instance" "iscsi_server" {
  name        = "iscsi-server"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd8vmcue7aajpmeo39kk" # Ubuntu 20.04
    }
  }

  secondary_disk {
    disk_id     = yandex_compute_disk.iscsi_disk.id
    auto_delete = false
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.gfs2_subnet.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/meta.yaml", {
      ssh_public_key = var.ssh_public_key
    })
  }

  # Явная зависимость от создания диска и подсети
  depends_on = [
    yandex_compute_disk.iscsi_disk,
    yandex_vpc_subnet.gfs2_subnet
  ]
}

# GFS2 Clients
resource "yandex_compute_disk" "gfs2_data_disks" {
  count = 3
  name  = "gfs2-data-disk-${count.index}"
  type  = "network-ssd"
  zone  = "ru-central1-a"
  size  = 20
}

resource "yandex_compute_instance" "gfs2_clients" {
  count       = 3
  name        = "gfs2-client-${count.index}"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd8vmcue7aajpmeo39kk" # Ubuntu 20.04
    }
  }

  secondary_disk {
    disk_id     = yandex_compute_disk.gfs2_data_disks[count.index].id
    auto_delete = false
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.gfs2_subnet.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/meta.yaml", {
      ssh_public_key = var.ssh_public_key
    })
  }

  # Явная зависимость от создания соответствующего диска и подсети
  depends_on = [
    yandex_compute_disk.gfs2_data_disks,
    yandex_vpc_subnet.gfs2_subnet
  ]
}