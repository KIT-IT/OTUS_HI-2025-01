output "master_public_ip" {
  value = yandex_compute_instance.master.network_interface[0].nat_ip_address
}

output "worker_public_ips" {
  value = [for w in yandex_compute_instance.worker : w.network_interface[0].nat_ip_address]
}

output "frontend_lb_ip" {
  description = "Public IP of external load balancer for frontend"
  value = [
    for l in yandex_lb_network_load_balancer.frontend_nlb.listener :
    l.external_address_spec.*.address[0]
  ][0]
}

