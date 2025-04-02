# Outputs for iSCSI Server
output "iscsi_server_internal_ip" {
  value = yandex_compute_instance.iscsi_server.network_interface.0.ip_address
  description = "Internal IP address of iSCSI server"
}

output "iscsi_server_external_ip" {
  value = yandex_compute_instance.iscsi_server.network_interface.0.nat_ip_address
  description = "External IP address of iSCSI server"
}

# Outputs for GFS2 Clients
output "gfs2_clients_internal_ips" {
  value = yandex_compute_instance.gfs2_clients[*].network_interface.0.ip_address
  description = "Internal IP addresses of GFS2 client nodes"
}

output "gfs2_clients_external_ips" {
  value = yandex_compute_instance.gfs2_clients[*].network_interface.0.nat_ip_address
  description = "External IP addresses of GFS2 client nodes"
}

# Outputs for Disks
output "iscsi_disk_id" {
  value = yandex_compute_disk.iscsi_disk.id
  description = "ID of iSCSI shared disk"
}

output "gfs2_data_disks_ids" {
  value = yandex_compute_disk.gfs2_data_disks[*].id
  description = "IDs of GFS2 data disks"
}

# Network Information
output "network_id" {
  value = yandex_vpc_network.gfs2_net.id
  description = "ID of created network"
}

output "subnet_id" {
  value = yandex_vpc_subnet.gfs2_subnet.id
  description = "ID of created subnet"
}

# Formatted outputs
output "iscsi_connection_string" {
  value = format(
    "iSCSI Target: %s (External IP: %s)",
    yandex_compute_instance.iscsi_server.network_interface.0.ip_address,
    yandex_compute_instance.iscsi_server.network_interface.0.nat_ip_address
  )
  description = "Formatted connection string for iSCSI target"
}

output "gfs2_cluster_info" {
  value = format(
    "GFS2 Cluster: %d nodes (External IPs: %s)",
    length(yandex_compute_instance.gfs2_clients),
    join(", ", yandex_compute_instance.gfs2_clients[*].network_interface.0.nat_ip_address)
  )
  description = "Formatted cluster information"
}

# Additional useful outputs
output "gfs2_clients_details" {
  value = [
    for idx, instance in yandex_compute_instance.gfs2_clients : {
      name         = instance.name
      external_ip  = instance.network_interface.0.nat_ip_address
      internal_ip  = instance.network_interface.0.ip_address
      disk_id      = yandex_compute_disk.gfs2_data_disks[idx].id
    }
  ]
  description = "Detailed information about GFS2 clients"
}