output "mon_public_ips" {
  description = "Public IP addresses of Ceph monitor nodes"
  value       = [for m in yandex_compute_instance.mon : m.network_interface[0].nat_ip_address]
}

output "osd_public_ips" {
  description = "Public IP addresses of Ceph OSD nodes"
  value       = [for o in yandex_compute_instance.osd : o.network_interface[0].nat_ip_address]
}

output "mds_public_ips" {
  description = "Public IP addresses of Ceph MDS nodes"
  value       = [for m in yandex_compute_instance.mds : m.network_interface[0].nat_ip_address]
}

output "client_public_ips" {
  description = "Public IP addresses of client nodes"
  value       = [for c in yandex_compute_instance.client : c.network_interface[0].nat_ip_address]
}

output "mon_internal_ips" {
  description = "Internal IP addresses of Ceph monitor nodes"
  value       = [for m in yandex_compute_instance.mon : m.network_interface[0].ip_address]
}

output "osd_internal_ips" {
  description = "Internal IP addresses of Ceph OSD nodes"
  value       = [for o in yandex_compute_instance.osd : o.network_interface[0].ip_address]
}

