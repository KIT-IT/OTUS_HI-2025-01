# Установка и базовая настройка Nginx

nginx-package:
  pkg.installed:
    - name: nginx

nginx-config:
  file.managed:
    - name: /etc/nginx/nginx.conf
    - source: salt://nginx/files/nginx.conf
    - template: jinja
    - require:
      - pkg: nginx-package
    - watch_in:
      - service: nginx-service

nginx-default-site:
  file.managed:
    - name: /etc/nginx/sites-available/default
    - source: salt://nginx/files/default-site.conf
    - template: jinja
    - require:
      - pkg: nginx-package
    - watch_in:
      - service: nginx-service

nginx-service:
  service.running:
    - name: nginx
    - enable: True
    - require:
      - pkg: nginx-package
    - watch:
      - file: nginx-config
      - file: nginx-default-site

# Создание директории для статического контента
nginx-webroot:
  file.directory:
    - name: /var/www/html
    - makedirs: True
    - mode: 755
    - user: www-data
    - group: www-data

# Простая тестовая страница
nginx-test-page:
  file.managed:
    - name: /var/www/html/index.html
    - source: salt://nginx/files/index.html
    - template: jinja
    - require:
      - file: nginx-webroot

