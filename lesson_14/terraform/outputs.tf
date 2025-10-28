

output "consul_servers_ips" {
  value = yandex_compute_instance.consul_server[*].network_interface[0].nat_ip_address
  description = "Public IPs of Consul servers"
}

output "consul_servers_private_ips" {
  value = yandex_compute_instance.consul_server[*].network_interface[0].ip_address
  description = "Private IPs of Consul servers"
}

output "consul_client_ip" {
  value = yandex_compute_instance.consul_client[0].network_interface[0].nat_ip_address
  description = "Public IP of Consul client"
}

output "consul_client_private_ip" {
  value = yandex_compute_instance.consul_client[0].network_interface[0].ip_address
  description = "Private IP of Consul client"
}

output "web_servers_ips" {
  value = yandex_compute_instance.web[*].network_interface[0].nat_ip_address
}

output "web_servers_private_ips" {
  value = yandex_compute_instance.web[*].network_interface[0].ip_address
}

output "opensearch_ips" {
  value = yandex_compute_instance.opensearch[*].network_interface[0].nat_ip_address
}

output "opensearch_private_ips" {
  value = yandex_compute_instance.opensearch[*].network_interface[0].ip_address
}
