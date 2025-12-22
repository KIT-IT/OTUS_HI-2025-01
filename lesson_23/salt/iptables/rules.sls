# Правила iptables для разных типов серверов

# Базовые правила для всех серверов
iptables-flush:
  cmd.run:
    - name: 'iptables -F && iptables -X && iptables -t nat -F && iptables -t nat -X && iptables -t mangle -F && iptables -t mangle -X'

# Политика по умолчанию
iptables-default-policy:
  cmd.run:
    - name: 'iptables -P INPUT DROP && iptables -P FORWARD DROP && iptables -P OUTPUT ACCEPT'
    - require:
      - cmd: iptables-flush

# Разрешить loopback
iptables-allow-loopback:
  cmd.run:
    - name: iptables -A INPUT -i lo -j ACCEPT
    - require:
      - cmd: iptables-default-policy

# Разрешить установленные соединения
iptables-allow-established:
  cmd.run:
    - name: iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    - require:
      - cmd: iptables-allow-loopback

# Разрешить SSH для всех
iptables-allow-ssh:
  cmd.run:
    - name: iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    - require:
      - cmd: iptables-allow-established

# Логирование заблокированных пакетов (последнее правило)
iptables-log-reject:
  cmd.run:
    - name: 'iptables -A INPUT -j LOG --log-prefix "IPTABLES-DROPPED: " --log-level 4'
    - require:
      - cmd: iptables-allow-ssh
