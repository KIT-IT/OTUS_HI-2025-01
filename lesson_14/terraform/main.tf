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
  name        = "consul-cluster-sg"
  network_id  = yandex_vpc_network.net.id
  description = "Allow SSH, HTTP, Consul, inter-node"

  ingress {
    protocol       = "tcp"
    description    = "SSH"
    port           = 22
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
    description    = "Inter-node communication"
    from_port      = 1
    to_port        = 65535
    v4_cidr_blocks = [var.subnet_cidr]
  }

  ingress {
    protocol       = "tcp"
    description    = "Consul Server RPC"
    port           = 8300
    v4_cidr_blocks = [var.subnet_cidr]
  }

  ingress {
    protocol       = "tcp"
    description    = "Consul LAN Serf"
    port           = 8301
    v4_cidr_blocks = [var.subnet_cidr]
  }

  ingress {
    protocol       = "tcp"
    description    = "Consul WAN Serf"
    port           = 8302
    v4_cidr_blocks= [var.subnet_cidr]
  }

  ingress {
    protocol       = "tcp"
    description    = "Consul HTTP API"
    port           = 8500
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "tcp"
    description    = "Consul DNS"
    port           = 8600
    v4_cidr_blocks = [var.subnet_cidr]
  }

  ingress {
    protocol       = "udp"
    description    = "Consul DNS"
    port           = 8600
    v4_cidr_blocks = [var.subnet_cidr]
  }

  ingress {
    protocol       = "tcp"
    description    = "OpenSearch"
    port           = 9200
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "tcp"
    description    = "OpenSearch Dashboard"
    port           = 5601
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "consul_server" {
  count       = var.consul_server_count
  name        = "consul-server-${count.index + 1}"
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
    ssh-keys       = "ubuntu:${var.ssh_public_key}"
    ssh_public_key = var.ssh_public_key
  }
  labels = merge(var.labels, { role = "consul-server", consul_type = "server" })
}

resource "yandex_compute_instance" "consul_client" {
  count       = var.consul_client_count
  name        = "consul-client-${count.index + 1}"
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
    ssh-keys       = "ubuntu:${var.ssh_public_key}"
    ssh_public_key = var.ssh_public_key
  }
  labels = merge(var.labels, { role = "consul-client", consul_type = "client" })
}

resource "yandex_compute_instance" "web" {
  count       = var.web_server_count
  name        = "web-${count.index + 1}"
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
    ssh-keys       = "ubuntu:${var.ssh_public_key}"
    ssh_public_key = var.ssh_public_key
    server_id      = "web-${count.index + 1}"
  }
  labels = merge(var.labels, { role = "web" })
}

resource "yandex_compute_instance" "opensearch" {
  count       = var.opensearch_count
  name        = "opensearch-${count.index + 1}"
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
  labels = merge(var.labels, { role = "opensearch" })
}
