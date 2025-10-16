# Ansible Configuration для Nginx, Keepalived, Django и PostgreSQL

Этот каталог содержит Ansible playbooks и роли для развертывания и управления инфраструктурой с высокой доступностью.

## Архитектура

Ansible настраивает следующую архитектуру:

- **Nginx**: Установлен и настроен как балансировщик нагрузки для backend серверов
- **Keepalived**: Установлен и настроен для высокой доступности (HA) Nginx серверов, обеспечивая виртуальный IP (VIP)
- **Django**: Backend приложение с REST API
- **PostgreSQL**: База данных для Django приложения

## Структура каталогов

```
ansible/
├── playbooks/                 # Основные playbooks
│   ├── nginx_ha.yml          # Настройка Nginx + Keepalived
│   ├── database.yml          # Настройка PostgreSQL
│   ├── backend.yml           # Настройка Django backend
│   └── full_deployment.yml   # Полное развертывание
├── roles/                    # Ansible роли
│   ├── nginx/                # Роль для Nginx
│   │   ├── tasks/main.yml
│   │   ├── handlers/main.yml
│   │   ├── templates/
│   │   └── vars/main.yml
│   ├── keepalived/           # Роль для Keepalived
│   │   ├── tasks/main.yml
│   │   ├── handlers/main.yml
│   │   ├── templates/
│   │   └── vars/main.yml
│   ├── database/             # Роль для PostgreSQL
│   │   ├── tasks/main.yml
│   │   ├── handlers/main.yml
│   │   └── vars/main.yml
│   └── backend/              # Роль для Django
│       ├── tasks/main.yml
│       ├── handlers/main.yml
│       ├── templates/
│       └── vars/main.yml
├── group_vars/               # Переменные для групп хостов
│   ├── nginx_servers.yml
│   ├── database_servers.yml
│   ├── backend_servers.yml
│   └── all.yml
├── inventory.ini             # Ansible inventory
├── update_inventory.sh       # Скрипт обновления inventory
└── README.md                 # Этот файл
```

## Развертывание

### Предварительные требования

1. **Terraform**: Убедитесь, что инфраструктура Yandex Cloud развернута с помощью Terraform
2. **Ansible**: Установлен Ansible
3. **SSH ключ**: Приватный ключ должен быть доступен для Ansible

### Шаги развертывания

1. **Обновить Ansible Inventory**:
   ```bash
   cd ansible
   ./update_inventory.sh
   ```

2. **Запустить полное развертывание**:
   ```bash
   ansible-playbook -i inventory.ini playbooks/full_deployment.yml
   ```

3. **Или развернуть компоненты по отдельности**:
   ```bash
   # Только база данных
   ansible-playbook -i inventory.ini playbooks/database.yml
   
   # Только backend
   ansible-playbook -i inventory.ini playbooks/backend.yml
   
   # Только Nginx + Keepalived
   ansible-playbook -i inventory.ini playbooks/nginx_ha.yml
   ```

## Проверка

После успешного развертывания:

- **Nginx**: Доступ к Nginx серверам через их внешние IP-адреса или виртуальный IP
  - `http://<NGINX_EXTERNAL_IP>/`
  - `http://<VIRTUAL_IP>/api/` (балансировка запросов к backend серверам)
  - `http://<VIRTUAL_IP>/health` (должен вернуть 'OK')

- **Keepalived**: Проверка статуса Keepalived на Nginx серверах
  - `ssh sedunovsv@<NGINX_EXTERNAL_IP>`
  - `sudo systemctl status keepalived`
  - Проверка логов для переходов состояния VRRP

- **Backend API**: Проверка Django API
  - `http://<BACKEND_IP>/api/`
  - `http://<BACKEND_IP>/api/health/`
  - `http://<BACKEND_IP>/api/items/`

- **PostgreSQL**: Проверка подключения к базе данных
  - `ssh sedunovsv@<DATABASE_IP>`
  - `sudo -u postgres psql -c '\l'`

## Настройка

### Переменные

Основные переменные можно настроить в файлах `group_vars/`:

- `nginx_servers.yml`: Настройки Keepalived (приоритеты, VIP, router ID)
- `database_servers.yml`: Настройки PostgreSQL (версия, база данных, пользователи)
- `backend_servers.yml`: Настройки Django (проект, приложение, порты)
- `all.yml`: Общие настройки (Python интерпретатор, SSH параметры)

### Роли

Каждая роль содержит:
- `tasks/main.yml`: Основные задачи
- `handlers/main.yml`: Обработчики событий
- `templates/`: Jinja2 шаблоны
- `vars/main.yml`: Переменные по умолчанию

## Устранение неполадок

1. **Проверка подключения**:
   ```bash
   ansible all -i inventory.ini -m ping
   ```

2. **Проверка статуса сервисов**:
   ```bash
   ansible all -i inventory.ini -m systemd -a "name=nginx state=started"
   ```

3. **Просмотр логов**:
   ```bash
   ansible all -i inventory.ini -m shell -a "sudo journalctl -u nginx -n 20"
   ```

## Дополнительные возможности

- **Масштабирование**: Легко добавить новые серверы в inventory
- **Мониторинг**: Интеграция с системами мониторинга
- **Безопасность**: Настройка файрволов и SSL сертификатов
- **Резервное копирование**: Автоматическое резервное копирование базы данных