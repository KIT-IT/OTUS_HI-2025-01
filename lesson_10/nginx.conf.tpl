events {}

http {
    # Upstream для балансировки между backend серверами
    upstream backend_servers {
        server ${backend_1_ip}:8000; # IP backend-1
        server ${backend_2_ip}:8000; # IP backend-2
    }

    # Upstream для балансировки между nginx серверами
    upstream nginx_servers {
        server ${nginx_1_ip}:80; # IP nginx-1
        server ${nginx_2_ip}:80; # IP nginx-2
    }

    # Основной сервер для балансировки
    server {
        listen 80;
        server_name _;

        # Балансировка между nginx серверами
        location / {
            proxy_pass http://nginx_servers;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Прямая балансировка между backend серверами
        location /api/ {
            proxy_pass http://backend_servers/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Health check endpoint
        location /health {
            return 200 "OK";
            add_header Content-Type text/plain;
        }
    }
}