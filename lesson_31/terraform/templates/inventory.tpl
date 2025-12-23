[master]
master-1 ansible_host=${master_ip} ansible_user=ubuntu

[worker]
%{ for ip in worker_ips ~}
worker-${index(worker_ips, ip)+1} ansible_host=${ip} ansible_user=ubuntu
%{ endfor ~}

[k8s:children]
master
worker

