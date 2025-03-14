output "internal_nginx_lb_ip" {
  value = yandex_compute_instance.nginx_lb.network_interface.0.ip_address
}

output "external_nginx_lb_ip" {
  value = yandex_compute_instance.nginx_lb.network_interface.0.nat_ip_address
}

output "balance_nginx_lb_ip" {
  value = format("IP для балансировки: %s/api", yandex_compute_instance.nginx_lb.network_interface.0.nat_ip_address)
}

output "internal_nginx_backend_1_ip" {
  value = yandex_compute_instance.nginx_backend_1.network_interface.0.nat_ip_address
}

output "external_nginx_backend_1_ip" {
  value = yandex_compute_instance.nginx_backend_1.network_interface.0.ip_address
}

output "internal_nginx_backend_2_ip" {
  value = yandex_compute_instance.nginx_backend_2.network_interface.0.nat_ip_address
}

output "external_nginx_backend_2_ip" {
  value = yandex_compute_instance.nginx_backend_2.network_interface.0.ip_address
}



