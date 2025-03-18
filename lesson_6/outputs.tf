output "internal_nginx_lb_ip" {
  value = yandex_compute_instance.nginx_lb.network_interface.0.ip_address
}

output "external_nginx_lb_ip" {
  value = yandex_compute_instance.nginx_lb.network_interface.0.nat_ip_address
}

output "round_robin_balance_nginx_lb_ip" {
  value = format("IP для балансировки: %s/api/round_robin", yandex_compute_instance.nginx_lb.network_interface.0.nat_ip_address)
}

output "hash_balance_nginx_lb_ip" {
  value = format("IP для hash балансировки: %s/api/hash", yandex_compute_instance.nginx_lb.network_interface.0.nat_ip_address)
}

output "wordpress_balance_nginx_lb_ip" {
  value = format("IP для wordpress балансировки: %s/api/wordpress", yandex_compute_instance.nginx_lb.network_interface.0.nat_ip_address)
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

output "internal_wordpress_ip" {
  value = yandex_compute_instance.wordpress.network_interface[0].nat_ip_address
}

output "external_wordpress_ip" {
  value = yandex_compute_instance.wordpress.network_interface[0].ip_address
}

