# Pillar данные для Nginx серверов

nginx:
  upstream_servers:
    - '192.168.0.10:8000'
    - '192.168.0.11:8000'
  
  server_name: '_'
  
  listen_port: 80

