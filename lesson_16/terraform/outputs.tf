output "kafka_external_ip" {
  value = yandex_compute_instance.kafka.network_interface.0.nat_ip_address
  description = "Public IP address of Kafka node"
}

output "elk_external_ip" {
  value = yandex_compute_instance.elk.network_interface.0.nat_ip_address
  description = "Public IP address of ELK node"
}

output "app_external_ip" {
  value = yandex_compute_instance.app.network_interface.0.nat_ip_address
  description = "Public IP address of APP node"
}

output "kafka_internal_ip" {
  value = yandex_compute_instance.kafka.network_interface.0.ip_address
  description = "Private IP address of Kafka node"
}

output "elk_internal_ip" {
  value = yandex_compute_instance.elk.network_interface.0.ip_address
  description = "Private IP address of ELK node"
}

output "app_internal_ip" {
  value = yandex_compute_instance.app.network_interface.0.ip_address
  description = "Private IP address of APP node"
}
