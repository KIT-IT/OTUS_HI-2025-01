# Роль для Nginx серверов
# Устанавливает и настраивает Nginx

include:
  - nginx
  - iptables

# Установка grain для идентификации роли
nginx-role-grain:
  grains.present:
    - name: role
    - value: nginx

