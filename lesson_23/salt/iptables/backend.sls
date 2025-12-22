# Правила iptables для Backend серверов

include:
  - iptables.rules

iptables-allow-backend-8000:
  cmd.run:
    - name: 'iptables -A INPUT -p tcp --dport 8000 -s {{ pillar.get("nginx_subnet", "192.168.0.0/16") }} -j ACCEPT'
    - require:
      - cmd: iptables-allow-ssh

iptables-allow-backend-8080:
  cmd.run:
    - name: 'iptables -A INPUT -p tcp --dport 8080 -s {{ pillar.get("nginx_subnet", "192.168.0.0/16") }} -j ACCEPT'
    - require:
      - cmd: iptables-allow-backend-8000

iptables-allow-salt-publish:
  cmd.run:
    - name: 'iptables -A INPUT -p tcp --dport 4505 -s {{ pillar.get("salt_master_internal_ip", "127.0.0.1") }} -j ACCEPT'
    - require:
      - cmd: iptables-allow-backend-8080

iptables-allow-salt-ret:
  cmd.run:
    - name: 'iptables -A INPUT -p tcp --dport 4506 -s {{ pillar.get("salt_master_internal_ip", "127.0.0.1") }} -j ACCEPT'
    - require:
      - cmd: iptables-allow-salt-publish
