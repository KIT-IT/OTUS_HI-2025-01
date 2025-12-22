# Роль для Backend серверов
# Базовые настройки для backend серверов

include:
  - iptables

# Установка grain для идентификации роли
backend-role-grain:
  grains.present:
    - name: role
    - value: backend

# Пример: простой HTTP сервер для тестирования
simple-http-server:
  pkg.installed:
    - name: python3
  cmd.run:
    - name: |
        python3 -m http.server 8000 &
        echo $! > /tmp/http-server.pid
    - creates: /tmp/http-server.pid
    - require:
      - pkg: simple-http-server

