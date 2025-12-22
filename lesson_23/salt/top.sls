# Top file for Salt States
# Определяет какие состояния применять к каким серверам

base:
  # Salt Master
  'salt-master':
    - roles.salt-master
    - iptables.salt-master
  
  # Nginx серверы (по имени хоста или grain)
  'nginx-*':
    - roles.nginx
    - nginx
    - iptables.nginx
  
  # Backend серверы
  'backend-*':
    - roles.backend
    - iptables.backend
  
  # Все серверы получают базовые настройки iptables
  '*':
    - iptables.rules

