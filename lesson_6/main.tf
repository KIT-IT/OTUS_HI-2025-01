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

resource "yandex_compute_disk" "boot-disk" {
  name     = "boot-disk"
  type     = "network-hdd"
  zone     = "ru-central1-a"
  size     = "20"
  image_id = "fd808e721rc1vt7jkd0o"
}

resource "yandex_compute_instance" "nginx_backend_1" {
  name = "nginx-backend-1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd808e721rc1vt7jkd0o"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/meta_backend_1.yaml", {
      ssh_public_key = var.ssh_public_key
    })
  }
}

resource "yandex_compute_instance" "nginx_backend_2" {
  name = "nginx-backend-2"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd808e721rc1vt7jkd0o"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/meta_backend_2.yaml", {
      ssh_public_key = var.ssh_public_key
    })
  }
}

resource "yandex_compute_instance" "nginx_lb" {
  name = "nginx-lb"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd808e721rc1vt7jkd0o"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/meta_lb.yaml", {
      ssh_public_key = var.ssh_public_key
    })
  }

  depends_on = [yandex_compute_instance.nginx_backend_1, yandex_compute_instance.nginx_backend_2]

  connection {
    type        = "ssh"
    user        = "sedunovsv" # Имя пользователя, которое вы указали в метаданных
    private_key = file("/home/sedunovsv/.ssh/id_ed25519") # Укажите путь к вашему приватному SSH-ключу
    host        = self.network_interface.0.nat_ip_address # IP-адрес экземпляра
  }

  provisioner "remote-exec" {
    inline = [
      "until systemctl is-active nginx; do sleep 5; done",  # Ждать, пока Nginx не станет активным
      "echo '${templatefile("${path.module}/nginx.conf.tpl", { backend_1_ip = yandex_compute_instance.nginx_backend_1.network_interface.0.ip_address, backend_2_ip = yandex_compute_instance.nginx_backend_2.network_interface.0.ip_address })}' | sudo tee /etc/nginx/nginx.conf",
      "sudo systemctl restart nginx",
    ]
  }

  lifecycle {
    ignore_changes = [metadata]
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