# Nginx instances outputs
output "nginx_1_internal_ip" {
  value = yandex_compute_instance.nginx_1.network_interface.0.ip_address
}

output "nginx_1_external_ip" {
  value = yandex_compute_instance.nginx_1.network_interface.0.nat_ip_address
}

output "nginx_2_internal_ip" {
  value = yandex_compute_instance.nginx_2.network_interface.0.ip_address
}

output "nginx_2_external_ip" {
  value = yandex_compute_instance.nginx_2.network_interface.0.nat_ip_address
}

# Backend instances outputs
output "backend_1_internal_ip" {
  value = yandex_compute_instance.backend_1.network_interface.0.ip_address
}

output "backend_1_external_ip" {
  value = yandex_compute_instance.backend_1.network_interface.0.nat_ip_address
}

output "backend_2_internal_ip" {
  value = yandex_compute_instance.backend_2.network_interface.0.ip_address
}

output "backend_2_external_ip" {
  value = yandex_compute_instance.backend_2.network_interface.0.nat_ip_address
}

# Database instance outputs
output "database_internal_ip" {
  value = yandex_compute_instance.database.network_interface.0.ip_address
}

output "database_external_ip" {
  value = yandex_compute_instance.database.network_interface.0.nat_ip_address
}

# Summary outputs
output "nginx_servers" {
  value = {
    nginx_1 = yandex_compute_instance.nginx_1.network_interface.0.nat_ip_address
    nginx_2 = yandex_compute_instance.nginx_2.network_interface.0.nat_ip_address
  }
}

output "backend_servers" {
  value = {
    backend_1 = yandex_compute_instance.backend_1.network_interface.0.nat_ip_address
    backend_2 = yandex_compute_instance.backend_2.network_interface.0.nat_ip_address
  }
}

output "database_server" {
  value = yandex_compute_instance.database.network_interface.0.nat_ip_address
}

