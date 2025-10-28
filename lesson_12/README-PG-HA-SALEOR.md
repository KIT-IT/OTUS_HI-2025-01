# Saleor E-commerce Platform с PostgreSQL HA

Высокодоступная платформа электронной коммерции на базе Saleor с кластером PostgreSQL и балансировщиком HAProxy.

## Архитектура

- **3 узла PostgreSQL** с Patroni для автоматического failover
- **1 балансировщик HAProxy** для маршрутизации к активному узлу PostgreSQL
- **1 узел Saleor** с API и Dashboard
- **1 узел Storefront** для клиентского интерфейса
- **etcd** для координации кластера Patroni

## Быстрый запуск

1. **Подготовка окружения:**
   ```bash
   # Установите Yandex Cloud CLI
   curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
   
   # Настройте аутентификацию
   yc init
   yc iam service-account create --name saleor-sa
   yc iam service-account key create --service-account-name saleor-sa --output sa_key.json
   mkdir -p ~/.config/yandex-cloud
   mv sa_key.json ~/.config/yandex-cloud/
   ```

2. **Запуск инфраструктуры:**
   ```bash
   cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_12
   ./start.sh
   ```

3. **Доступ к сервисам:**
   - **Saleor API:** http://HAProxy_IP/graphql/
   - **Saleor Dashboard:** http://HAProxy_IP:9000/
   - **Storefront:** http://Storefront_IP:3000/
   - **HAProxy Stats:** http://HAProxy_IP:8080/haproxy_stats (admin/password)

## Подробная документация

### Требования

- Ubuntu 22.04 LTS
- Terraform >= 1.6.0
- Ansible >= 2.9
- Yandex Cloud CLI
- SSH ключ для доступа к ВМ

### Переменные окружения

Создайте файл `terraform.tfvars`:
```hcl
yc_token = "your_yandex_cloud_token"
yc_cloud_id = "your_cloud_id"
yc_folder_id = "your_folder_id"
yc_zone = "ru-central1-a"
image_id = "fd80bm0rh4rkepi5ksdi"  # Ubuntu 22.04
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
```

### Структура проекта

```
lesson_12/
├── pg_ha/
│   ├── terraform/          # Инфраструктура как код
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── provider.tf
│   └── ansible/            # Конфигурация как код
│       ├── playbooks/
│       │   └── site.yml
│       ├── roles/
│       │   ├── patroni/    # PostgreSQL кластер
│       │   ├── haproxy/    # Балансировщик
│       │   ├── saleor/     # E-commerce платформа
│       │   ├── storefront/ # Клиентский интерфейс
│       │   └── db_init/    # Инициализация БД
│       └── inventories/
│           └── prod/
│               └── hosts.ini
├── deploy-cluster.sh       # Основной скрипт развертывания
├── update-inventory.sh     # Обновление инвентаря Ansible
└── start.sh               # Запуск с переменными окружения
```

### Terraform

Создает инфраструктуру в Yandex Cloud:
- VPC сеть с подсетью
- Security Groups с правилами доступа
- 3 ВМ для Patroni кластера
- 1 ВМ для HAProxy
- 1 ВМ для Saleor
- 1 ВМ для Storefront

### Ansible

Настраивает сервисы на созданных ВМ:
- **Patroni:** PostgreSQL кластер с автоматическим failover
- **HAProxy:** Балансировка нагрузки и маршрутизация
- **Saleor:** E-commerce API и админ панель
- **Storefront:** Клиентский интерфейс магазина
- **DB Init:** Создание БД и пользователей

### Мониторинг

- **HAProxy Stats:** http://HAProxy_IP:8080/haproxy_stats
- **Patroni Status:** `patronictl list` на любом узле Patroni
- **PostgreSQL:** Подключение через HAProxy на порт 5432

### Масштабирование

Для добавления узлов Patroni:
1. Обновите `patroni_count` в `variables.tf`
2. Запустите `terraform apply`
3. Запустите Ansible playbook

### Устранение неполадок

1. **Проблемы с подключением:**
   - Проверьте Security Groups
   - Убедитесь в правильности SSH ключей

2. **Проблемы с Patroni:**
   - Проверьте статус: `patronictl list`
   - Перезапустите: `systemctl restart patroni`

3. **Проблемы с HAProxy:**
   - Проверьте конфигурацию: `haproxy -c -f /etc/haproxy/haproxy.cfg`
   - Перезапустите: `systemctl restart haproxy`

### Безопасность

- Все ВМ находятся в приватной подсети
- Доступ только через NAT Gateway
- SSH доступ только по ключам
- PostgreSQL доступ только через HAProxy

### Резервное копирование

Настройте регулярное резервное копирование PostgreSQL:
```bash
# На активном узле Patroni
pg_dump -h localhost -U postgres saleor > backup_$(date +%Y%m%d).sql
```

### Обновления

1. **Обновление Saleor:**
   - Обновите версию в `roles/saleor/defaults/main.yml`
   - Запустите Ansible playbook

2. **Обновление инфраструктуры:**
   - Обновите Terraform конфигурацию
   - Запустите `terraform plan` для проверки
   - Примените изменения `terraform apply`