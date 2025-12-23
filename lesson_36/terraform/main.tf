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

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts"
}

############################
# Security Group для Ceph  #
############################
resource "yandex_vpc_security_group" "ceph" {
  name        = "ceph-sg"
  description = "Security group for Ceph cluster (MON, OSD, MDS, clients)"
  network_id  = data.yandex_vpc_network.this.id

  # SSH
  ingress {
    protocol       = "TCP"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Ceph Monitor
  ingress {
    protocol       = "TCP"
    description    = "Ceph Monitor"
    port           = 6789
    v4_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  # Ceph OSD (множество портов)
  ingress {
    protocol       = "TCP"
    description    = "Ceph OSD"
    from_port      = 6800
    to_port         = 7300
    v4_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  # Ceph MDS
  ingress {
    protocol       = "TCP"
    description    = "Ceph MDS"
    port           = 6800
    v4_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  # Внутренняя коммуникация между узлами
  ingress {
    protocol       = "TCP"
    description    = "Internal cluster communication"
    from_port      = 1
    to_port         = 65535
    v4_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  # Исходящий трафик
  egress {
    protocol       = "TCP"
    description    = "Any outbound TCP"
    from_port      = 1
    to_port         = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "UDP"
    description    = "Any outbound UDP"
    from_port      = 1
    to_port         = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# Ceph Monitor Nodes      #
############################
resource "yandex_compute_instance" "mon" {
  count       = var.mon_count
  name        = "ceph-mon-${count.index + 1}"
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
    security_group_ids = [yandex_vpc_security_group.ceph.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

############################
# Ceph OSD Nodes          #
############################
resource "yandex_compute_instance" "osd" {
  count       = var.osd_count
  name        = "ceph-osd-${count.index + 1}"
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

  # Дополнительный диск для OSD данных
  secondary_disk {
    disk_id     = yandex_compute_disk.osd_disk[count.index].id
    auto_delete = true
  }

  network_interface {
    subnet_id          = data.yandex_vpc_subnet.this.id
    nat                = count.index < 2 ? true : false  # Первые 2 OSD с NAT, последний без (лимит внешних IP)
    security_group_ids = [yandex_vpc_security_group.ceph.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

# Диски для OSD (используем network-hdd для экономии квоты)
resource "yandex_compute_disk" "osd_disk" {
  count     = var.osd_count
  name      = "ceph-osd-disk-${count.index + 1}"
  type      = "network-hdd"  # Используем HDD вместо SSD для экономии квоты
  zone      = var.zone
  size      = var.osd_disk_size
}

############################
# Ceph MDS Node           #
############################
resource "yandex_compute_instance" "mds" {
  count       = var.mds_count
  name        = "ceph-mds-${count.index + 1}"
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
    security_group_ids = [yandex_vpc_security_group.ceph.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

############################
# Client Nodes            #
############################
resource "yandex_compute_instance" "client" {
  count       = var.client_count
  name        = "ceph-client-${count.index + 1}"
  platform_id = "standard-v2"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 2
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
    security_group_ids = [yandex_vpc_security_group.ceph.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

############################
# Ansible Inventory       #
############################
resource "local_file" "inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content  = templatefile("${path.module}/templates/inventory.tpl", {
    mon_ips    = [for m in yandex_compute_instance.mon : m.network_interface[0].nat_ip_address]
    osd_ips    = [for o in yandex_compute_instance.osd : o.network_interface[0].nat_ip_address != "" ? o.network_interface[0].nat_ip_address : o.network_interface[0].ip_address]
    mds_ips    = [for m in yandex_compute_instance.mds : m.network_interface[0].nat_ip_address]
    client_ips = [for c in yandex_compute_instance.client : c.network_interface[0].nat_ip_address]
  })
}

