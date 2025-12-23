[mons]
%{ for i, ip in mon_ips ~}
mon-${i+1} ansible_host=${ip} ansible_user=ubuntu
%{ endfor ~}

[osds]
%{ for i, ip in osd_ips ~}
osd-${i+1} ansible_host=${ip} ansible_user=ubuntu
%{ endfor ~}

[mdss]
%{ for i, ip in mds_ips ~}
mds-${i+1} ansible_host=${ip} ansible_user=ubuntu
%{ endfor ~}

[clients]
%{ for i, ip in client_ips ~}
client-${i+1} ansible_host=${ip} ansible_user=ubuntu
%{ endfor ~}

[ceph:children]
mons
osds
mdss

[ceph-cluster:children]
mons
osds
mdss
clients

