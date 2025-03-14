events {}

http {
    upstream backend {
        server ${backend_1_ip}:8000; # IP бэкенда 1
        server ${backend_2_ip}:8000; # IP бэкенда 2
    }

    server {
        listen 80;

        location / {
            root /var/www/html;
            index index.html;
        }

        location /api/ {
            proxy_pass http://backend/;
        }
    }
}