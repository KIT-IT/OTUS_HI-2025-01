terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone      = "ru-central1-a"
  folder_id = "b1gr66gumfmr5ua86ol9"
}

# MySQL Cluster - 3 nodes for high availability
resource "yandex_compute_instance" "mysql_node_1" {
  name = "mysql-node-1"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd808e721rc1vt7jkd0o"
      size     = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/meta_mysql_node.yaml", {
      ssh_public_key = var.ssh_public_key
      node_id        = 1
      cluster_nodes  = "mysql-node-1,mysql-node-2,mysql-node-3"
    })
  }
}

resource "yandex_compute_instance" "mysql_node_2" {
  name = "mysql-node-2"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd808e721rc1vt7jkd0o"
      size     = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/meta_mysql_node.yaml", {
      ssh_public_key = var.ssh_public_key
      node_id        = 2
      cluster_nodes  = "mysql-node-1,mysql-node-2,mysql-node-3"
    })
  }
}

resource "yandex_compute_instance" "mysql_node_3" {
  name = "mysql-node-3"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd808e721rc1vt7jkd0o"
      size     = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/meta_mysql_node.yaml", {
      ssh_public_key = var.ssh_public_key
      node_id        = 3
      cluster_nodes  = "mysql-node-1,mysql-node-2,mysql-node-3"
    })
  }
}


resource "yandex_vpc_network" "network" {
  name = "my-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "my-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}