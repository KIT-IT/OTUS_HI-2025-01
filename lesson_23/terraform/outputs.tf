output "salt_master_external_ip" {
  value       = yandex_compute_instance.salt_master.network_interface.0.nat_ip_address
  description = "Public IP address of Salt Master"
}

output "salt_master_internal_ip" {
  value       = yandex_compute_instance.salt_master.network_interface.0.ip_address
  description = "Private IP address of Salt Master"
}

output "nginx_external_ips" {
  value       = [for nginx in yandex_compute_instance.nginx : nginx.network_interface.0.nat_ip_address]
  description = "Public IP addresses of Nginx servers"
}

output "nginx_internal_ips" {
  value       = [for nginx in yandex_compute_instance.nginx : nginx.network_interface.0.ip_address]
  description = "Private IP addresses of Nginx servers"
}

output "backend_internal_ips" {
  value       = [for backend in yandex_compute_instance.backend : backend.network_interface.0.ip_address]
  description = "Private IP addresses of Backend servers"
}

output "all_servers" {
  value = {
    salt_master = {
      external_ip = yandex_compute_instance.salt_master.network_interface.0.nat_ip_address
      internal_ip = yandex_compute_instance.salt_master.network_interface.0.ip_address
    }
    nginx = [
      for nginx in yandex_compute_instance.nginx : {
        external_ip = nginx.network_interface.0.nat_ip_address
        internal_ip = nginx.network_interface.0.ip_address
      }
    ]
    backend = [
      for backend in yandex_compute_instance.backend : {
        internal_ip = backend.network_interface.0.ip_address
      }
    ]
  }
  description = "All servers with their IP addresses"
}

