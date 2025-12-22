terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66.0"
    }
  }
  required_version = ">= 1.0"
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = var.proxmox_tls_insecure
}

# Локальные переменные для обработки SSH ключа
locals {
  ssh_public_key_content = var.ssh_public_key_file != "" ? file(var.ssh_public_key_file) : var.ssh_public_key
  # Извлекаем IP адрес Proxmox из URL
  proxmox_host = replace(replace(var.proxmox_api_url, "https://", ""), ":8006/api2/json", "")
}

# ============================================================================
# HAProxy + keepalived CT (2 instances)
# ============================================================================

resource "proxmox_virtual_environment_container" "haproxy" {
  count       = 2
  vm_id       = var.haproxy_vmids[count.index]
  node_name   = var.proxmox_node_name
  description = "HAProxy + keepalived container ${count.index + 1}"

  cpu {
    cores = var.haproxy_cpu_cores
  }

  memory {
    dedicated = var.haproxy_memory
    swap      = var.haproxy_swap
  }

  disk {
    datastore_id = var.haproxy_disk_datastore
    size         = var.haproxy_disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  operating_system {
    template_file_id = var.ct_template_file_id
    type             = var.ct_os_type
  }

  initialization {
    hostname = "ct-haproxy-${count.index + 1}.${var.domain_name}"
    ip_config {
      ipv4 {
        address = var.haproxy_ip_addresses[count.index]
        gateway = var.network_gateway
      }
    }

    user_account {
      password = var.ct_root_password != "" ? var.ct_root_password : null
      keys     = local.ssh_public_key_content != "" ? [local.ssh_public_key_content] : []
    }
  }

  unprivileged  = true
  start_on_boot = true
  tags          = concat(var.common_tags, ["haproxy", "keepalived"])
}

# Provisioner для настройки SSH и создания пользователя на HAProxy контейнерах
resource "null_resource" "haproxy_setup" {
  count = 2
  depends_on = [proxmox_virtual_environment_container.haproxy]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 5
      sshpass -p '${var.proxmox_password}' ssh -o StrictHostKeyChecking=no root@${local.proxmox_host} bash -c "
        pct exec ${proxmox_virtual_environment_container.haproxy[count.index].vm_id} -- bash -c \"
          if ! command -v sshd >/dev/null 2>&1; then
            dnf install -y openssh-server openssh-clients >/dev/null 2>&1
          fi
          cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true
          sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
          sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
          sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
          sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
          grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
          grep -q '^PasswordAuthentication' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
          systemctl enable sshd
          systemctl restart sshd
          if ! id -u ${var.ct_user_name} >/dev/null 2>&1; then
            useradd -m -s /bin/bash ${var.ct_user_name}
            echo '${var.ct_user_name}:${var.ct_user_password}' | chpasswd
            usermod -aG wheel ${var.ct_user_name}
          else
            echo '${var.ct_user_name}:${var.ct_user_password}' | chpasswd
          fi
        \"
      "
    EOT
  }
}

# ============================================================================
# PostgreSQL + Patroni CT (3 instances)
# ============================================================================

resource "proxmox_virtual_environment_container" "postgres" {
  count       = 3
  vm_id       = var.postgres_vmids[count.index]
  node_name   = var.proxmox_node_name
  description = "PostgreSQL + Patroni container ${count.index + 1}"

  cpu {
    cores = var.postgres_cpu_cores
  }

  memory {
    dedicated = var.postgres_memory
    swap      = var.postgres_swap
  }

  disk {
    datastore_id = var.postgres_disk_datastore
    size         = var.postgres_disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  operating_system {
    template_file_id = var.ct_template_file_id
    type             = var.ct_os_type
  }

  initialization {
    hostname = "ct-pg-${count.index + 1}.${var.domain_name}"
    ip_config {
      ipv4 {
        address = var.postgres_ip_addresses[count.index]
        gateway = var.network_gateway
      }
    }

    user_account {
      password = var.ct_root_password != "" ? var.ct_root_password : null
      keys     = local.ssh_public_key_content != "" ? [local.ssh_public_key_content] : []
    }
  }

  unprivileged  = true
  start_on_boot = true
  tags          = concat(var.common_tags, ["postgresql", "patroni"])
}

# Provisioner для настройки SSH и создания пользователя на PostgreSQL контейнерах
resource "null_resource" "postgres_setup" {
  count = 3
  depends_on = [proxmox_virtual_environment_container.postgres]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 5
      sshpass -p '${var.proxmox_password}' ssh -o StrictHostKeyChecking=no root@${local.proxmox_host} bash -c "
        pct exec ${proxmox_virtual_environment_container.postgres[count.index].vm_id} -- bash -c \"
          if ! command -v sshd >/dev/null 2>&1; then
            dnf install -y openssh-server openssh-clients >/dev/null 2>&1
          fi
          cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true
          sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
          sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
          sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
          sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
          grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
          grep -q '^PasswordAuthentication' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
          systemctl enable sshd
          systemctl restart sshd
          if ! id -u ${var.ct_user_name} >/dev/null 2>&1; then
            useradd -m -s /bin/bash ${var.ct_user_name}
            echo '${var.ct_user_name}:${var.ct_user_password}' | chpasswd
            usermod -aG wheel ${var.ct_user_name}
          else
            echo '${var.ct_user_name}:${var.ct_user_password}' | chpasswd
          fi
        \"
      "
    EOT
  }
}

# ============================================================================
# Docker Swarm Manager CT (2 instances)
# ============================================================================

resource "proxmox_virtual_environment_container" "docker_manager" {
  count       = 2
  vm_id       = var.docker_manager_vmids[count.index]
  node_name   = var.proxmox_node_name
  description = "Docker Swarm Manager container ${count.index + 1}"

  cpu {
    cores = var.docker_manager_cpu_cores
  }

  memory {
    dedicated = var.docker_manager_memory
    swap      = var.docker_manager_swap
  }

  disk {
    datastore_id = var.docker_manager_disk_datastore
    size         = var.docker_manager_disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  operating_system {
    template_file_id = var.ct_template_file_id
    type             = var.ct_os_type
  }

  initialization {
    hostname = "ct-docker-mgr-${count.index + 1}.${var.domain_name}"
    ip_config {
      ipv4 {
        address = var.docker_manager_ip_addresses[count.index]
        gateway = var.network_gateway
      }
    }

    user_account {
      password = var.ct_root_password != "" ? var.ct_root_password : null
      keys     = local.ssh_public_key_content != "" ? [local.ssh_public_key_content] : []
    }
  }

  unprivileged  = true
  start_on_boot = true
  tags          = concat(var.common_tags, ["docker", "swarm", "manager"])
}

# Provisioner для настройки SSH и создания пользователя на Docker Manager контейнерах
resource "null_resource" "docker_manager_setup" {
  count = 2
  depends_on = [proxmox_virtual_environment_container.docker_manager]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 5
      sshpass -p '${var.proxmox_password}' ssh -o StrictHostKeyChecking=no root@${local.proxmox_host} bash -c "
        pct exec ${proxmox_virtual_environment_container.docker_manager[count.index].vm_id} -- bash -c \"
          if ! command -v sshd >/dev/null 2>&1; then
            dnf install -y openssh-server openssh-clients >/dev/null 2>&1
          fi
          cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true
          sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
          sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
          sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
          sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
          grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
          grep -q '^PasswordAuthentication' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
          systemctl enable sshd
          systemctl restart sshd
          if ! id -u ${var.ct_user_name} >/dev/null 2>&1; then
            useradd -m -s /bin/bash ${var.ct_user_name}
            echo '${var.ct_user_name}:${var.ct_user_password}' | chpasswd
            usermod -aG wheel ${var.ct_user_name}
          else
            echo '${var.ct_user_name}:${var.ct_user_password}' | chpasswd
          fi
        \"
      "
    EOT
  }
}

# ============================================================================
# Docker Swarm Worker CT (2 instances)
# ============================================================================

resource "proxmox_virtual_environment_container" "docker_worker" {
  count       = 2
  vm_id       = var.docker_worker_vmids[count.index]
  node_name   = var.proxmox_node_name
  description = "Docker Swarm Worker container ${count.index + 1}"

  cpu {
    cores = var.docker_worker_cpu_cores
  }

  memory {
    dedicated = var.docker_worker_memory
    swap      = var.docker_worker_swap
  }

  disk {
    datastore_id = var.docker_worker_disk_datastore
    size         = var.docker_worker_disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  operating_system {
    template_file_id = var.ct_template_file_id
    type             = var.ct_os_type
  }

  initialization {
    hostname = "ct-docker-wkr-${count.index + 1}.${var.domain_name}"
    ip_config {
      ipv4 {
        address = var.docker_worker_ip_addresses[count.index]
        gateway = var.network_gateway
      }
    }

    user_account {
      password = var.ct_root_password != "" ? var.ct_root_password : null
      keys     = local.ssh_public_key_content != "" ? [local.ssh_public_key_content] : []
    }
  }

  unprivileged  = true
  start_on_boot = true
  tags          = concat(var.common_tags, ["docker", "swarm", "worker"])
}

# Provisioner для настройки SSH и создания пользователя на Docker Worker контейнерах
resource "null_resource" "docker_worker_setup" {
  count = 2
  depends_on = [proxmox_virtual_environment_container.docker_worker]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 5
      sshpass -p '${var.proxmox_password}' ssh -o StrictHostKeyChecking=no root@${local.proxmox_host} bash -c "
        pct exec ${proxmox_virtual_environment_container.docker_worker[count.index].vm_id} -- bash -c \"
          if ! command -v sshd >/dev/null 2>&1; then
            dnf install -y openssh-server openssh-clients >/dev/null 2>&1
          fi
          cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true
          sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
          sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
          sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
          sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
          grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
          grep -q '^PasswordAuthentication' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
          systemctl enable sshd
          systemctl restart sshd
          if ! id -u ${var.ct_user_name} >/dev/null 2>&1; then
            useradd -m -s /bin/bash ${var.ct_user_name}
            echo '${var.ct_user_name}:${var.ct_user_password}' | chpasswd
            usermod -aG wheel ${var.ct_user_name}
          else
            echo '${var.ct_user_name}:${var.ct_user_password}' | chpasswd
          fi
        \"
      "
    EOT
  }
}

# ============================================================================
# etcd CT (3 instances)
# ============================================================================

resource "proxmox_virtual_environment_container" "etcd" {
  count       = 3
  vm_id       = var.etcd_vmids[count.index]
  node_name   = var.proxmox_node_name
  description = "etcd container ${count.index + 1}"

  cpu {
    cores = var.etcd_cpu_cores
  }

  memory {
    dedicated = var.etcd_memory
    swap      = var.etcd_swap
  }

  disk {
    datastore_id = var.etcd_disk_datastore
    size         = var.etcd_disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  operating_system {
    template_file_id = var.ct_template_file_id
    type             = var.ct_os_type
  }

  initialization {
    hostname = "ct-etcd-${count.index + 1}.${var.domain_name}"
    ip_config {
      ipv4 {
        address = var.etcd_ip_addresses[count.index]
        gateway = var.network_gateway
      }
    }

    user_account {
      password = var.ct_root_password != "" ? var.ct_root_password : null
      keys     = local.ssh_public_key_content != "" ? [local.ssh_public_key_content] : []
    }
  }

  unprivileged  = true
  start_on_boot = true
  tags          = concat(var.common_tags, ["etcd"])
}

# Provisioner для настройки SSH и создания пользователя на etcd контейнерах
resource "null_resource" "etcd_setup" {
  count = 3
  depends_on = [proxmox_virtual_environment_container.etcd]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 5
      sshpass -p '${var.proxmox_password}' ssh -o StrictHostKeyChecking=no root@${local.proxmox_host} bash -c "
        pct exec ${proxmox_virtual_environment_container.etcd[count.index].vm_id} -- bash -c \"
          if ! command -v sshd >/dev/null 2>&1; then
            dnf install -y openssh-server openssh-clients >/dev/null 2>&1
          fi
          cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true
          sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
          sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
          sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
          sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
          grep -q '^PermitRootLogin' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
          grep -q '^PasswordAuthentication' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
          systemctl enable sshd
          systemctl restart sshd
          if ! id -u ${var.ct_user_name} >/dev/null 2>&1; then
            useradd -m -s /bin/bash ${var.ct_user_name}
            echo '${var.ct_user_name}:${var.ct_user_password}' | chpasswd
            usermod -aG wheel ${var.ct_user_name}
          else
            echo '${var.ct_user_name}:${var.ct_user_password}' | chpasswd
          fi
        \"
      "
    EOT
  }
}
