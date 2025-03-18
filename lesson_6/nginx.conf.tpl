events {}

http {
    upstream backend_round_robin {
        server ${backend_1_ip}:8000; # IP бэкенда 1
        server ${backend_2_ip}:8000; # IP бэкенда 2
    }

    upstream backend_hash {
        hash $remote_addr; 

        server ${backend_1_ip}:8000; # IP бэкенда 1
        server ${backend_2_ip}:8000; # IP бэкенда 2
    }

    upstream backend_wordpress {
        server ${backend_wordpress_ip}:80; # IP wordpress
    }

    server {
        listen 80;

        location / {
            root /var/www/html;
            index index.html;
        }

        location /api/round_robin/ {
            proxy_pass http://backend_round_robin/;
        }

        location /api/hash/ {
            proxy_pass http://backend_hash/;
        }

        location /api/wordpress/ {
            proxy_pass http://backend_wordpress/;
        }
    }
}