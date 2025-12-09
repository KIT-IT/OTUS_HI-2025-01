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
}

# Создаём LXC контейнер вместо ВМ
resource "proxmox_virtual_environment_container" "ct" {
  node_name   = var.proxmox_node_name
  description = "LXC container created by Terraform for OTUS lesson 19"

  cpu {
    cores = var.ct_cpu_cores
  }

  memory {
    dedicated = var.ct_memory
    swap      = var.ct_swap
  }

  disk {
    datastore_id = var.ct_disk_datastore
    size         = var.ct_disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.ct_network_bridge
  }

  operating_system {
    template_file_id = var.ct_template_file_id
    type             = var.ct_os_type
  }

  initialization {
    hostname = var.ct_hostname
    ip_config {
      ipv4 {
        address = var.ct_ip_address
        gateway = var.ct_gateway != "" ? var.ct_gateway : null
      }
    }

    user_account {
      password = var.ct_root_password != "" ? var.ct_root_password : null
      keys     = local.ssh_public_key_content != "" ? [local.ssh_public_key_content] : []
    }
  }

  unprivileged       = true
  start_on_boot      = true
  tags               = var.ct_tags
}
