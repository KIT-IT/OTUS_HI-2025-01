# Правила iptables для Salt Master

include:
  - iptables.rules

iptables-allow-salt-publish:
  cmd.run:
    - name: iptables -A INPUT -p tcp --dport 4505 -j ACCEPT
    - require:
      - cmd: iptables-allow-ssh

iptables-allow-salt-ret:
  cmd.run:
    - name: iptables -A INPUT -p tcp --dport 4506 -j ACCEPT
    - require:
      - cmd: iptables-allow-salt-publish

# Разрешить Salt REST API (для SaltGUI)
iptables-allow-salt-api:
  cmd.run:
    - name: iptables -A INPUT -p tcp --dport 8000 -j ACCEPT
    - require:
      - cmd: iptables-allow-salt-ret

# Разрешить SaltGUI Frontend
iptables-allow-saltgui:
  cmd.run:
    - name: iptables -A INPUT -p tcp --dport 8001 -j ACCEPT
    - require:
      - cmd: iptables-allow-salt-api
