# Правила iptables для Nginx серверов

include:
  - iptables.rules

iptables-allow-http:
  cmd.run:
    - name: iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    - require:
      - cmd: iptables-allow-ssh

iptables-allow-https:
  cmd.run:
    - name: iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    - require:
      - cmd: iptables-allow-http

iptables-allow-salt-publish:
  cmd.run:
    - name: 'iptables -A INPUT -p tcp --dport 4505 -s {{ pillar.get("salt_master_internal_ip", "127.0.0.1") }} -j ACCEPT'
    - require:
      - cmd: iptables-allow-https

iptables-allow-salt-ret:
  cmd.run:
    - name: 'iptables -A INPUT -p tcp --dport 4506 -s {{ pillar.get("salt_master_internal_ip", "127.0.0.1") }} -j ACCEPT'
    - require:
      - cmd: iptables-allow-salt-publish
