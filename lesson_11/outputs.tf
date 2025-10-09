# MySQL Cluster nodes outputs
output "mysql_node_1_internal_ip" {
  value = yandex_compute_instance.mysql_node_1.network_interface.0.ip_address
}

output "mysql_node_1_external_ip" {
  value = yandex_compute_instance.mysql_node_1.network_interface.0.nat_ip_address
}

output "mysql_node_2_internal_ip" {
  value = yandex_compute_instance.mysql_node_2.network_interface.0.ip_address
}

output "mysql_node_2_external_ip" {
  value = yandex_compute_instance.mysql_node_2.network_interface.0.nat_ip_address
}

output "mysql_node_3_internal_ip" {
  value = yandex_compute_instance.mysql_node_3.network_interface.0.ip_address
}

output "mysql_node_3_external_ip" {
  value = yandex_compute_instance.mysql_node_3.network_interface.0.nat_ip_address
}

# Cluster summary outputs
output "mysql_cluster_nodes" {
  value = {
    node_1 = yandex_compute_instance.mysql_node_1.network_interface.0.nat_ip_address
    node_2 = yandex_compute_instance.mysql_node_2.network_interface.0.nat_ip_address
    node_3 = yandex_compute_instance.mysql_node_3.network_interface.0.nat_ip_address
  }
}

output "mysql_cluster_internal_ips" {
  value = {
    node_1 = yandex_compute_instance.mysql_node_1.network_interface.0.ip_address
    node_2 = yandex_compute_instance.mysql_node_2.network_interface.0.ip_address
    node_3 = yandex_compute_instance.mysql_node_3.network_interface.0.ip_address
  }
}

