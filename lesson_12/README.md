# Saleor E-commerce Platform - Быстрый запуск

## Что это?

Высокодоступная платформа электронной коммерции на базе Saleor с автоматическим failover PostgreSQL кластера.

## Что включено

- **PostgreSQL кластер** (3 узла) с Patroni для автоматического failover
- **HAProxy** для балансировки нагрузки и маршрутизации
- **Saleor API** - GraphQL API для e-commerce
- **Saleor Dashboard** - административная панель
- **Storefront** - клиентский интерфейс магазина
- **etcd** - координация кластера

## Быстрый запуск

### 1. Подготовка
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

### 2. Запуск
```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_12
./start.sh
```

### 3. Доступ к сервисам
После успешного развертывания:

- **Storefront**: http://Storefront_IP:3000
- **Saleor API**: http://HAProxy_IP/graphql/
- **Saleor Dashboard**: http://HAProxy_IP:9000/
- **HAProxy Stats**: http://HAProxy_IP:8080/haproxy_stats (admin/password)

## Управление

### Проверка статуса
```bash
# Статус кластера PostgreSQL
patronictl -c /etc/patroni/patroni.yml list

# Статус HAProxy
systemctl status haproxy

# Статус Saleor
docker compose -f /opt/saleor/docker-compose.yml ps
```

### Перезапуск сервисов
```bash
# Перезапуск Saleor
docker compose -f /opt/saleor/docker-compose.yml restart

# Перезапуск HAProxy
systemctl restart haproxy

# Перезапуск PostgreSQL кластера
patronictl -c /etc/patroni/patroni.yml restart saleor-cluster
```

## Структура проекта

```
lesson_12/
├── README.md                    # Этот файл
├── README-PG-HA-SALEOR.md      # Полная документация
├── TECHNICAL-DOCUMENTATION.md  # Техническая документация
├── POSTGRESQL-PATRONI-GUIDE.md # Руководство по PostgreSQL
├── HAPROXY-GUIDE.md            # Руководство по HAProxy
├── ARCHITECTURE-DIAGRAM.md     # Архитектурные диаграммы
├── start.sh                    # Скрипт запуска
├── deploy-cluster.sh           # Развертывание кластера
├── update-inventory.sh         # Обновление инвентаря
└── pg_ha/
    ├── terraform/              # Инфраструктура
    └── ansible/                # Конфигурация
```

## Устранение неполадок

### Проблемы с подключением
```bash
# Проверьте Security Groups в Yandex Cloud
# Убедитесь что открыты порты: 22, 80, 5432, 8000, 9000, 3000, 8080
```

### Проблемы с PostgreSQL
```bash
# Проверьте статус кластера
patronictl -c /etc/patroni/patroni.yml list

# Перезапустите Patroni
systemctl restart patroni
```

### Проблемы с Saleor
```bash
# Проверьте логи
docker compose -f /opt/saleor/docker-compose.yml logs

# Перезапустите контейнеры
docker compose -f /opt/saleor/docker-compose.yml restart
```

## Дополнительная документация

- **[Полная документация](README-PG-HA-SALEOR.md)** - детальное руководство
- **[Техническая документация](TECHNICAL-DOCUMENTATION.md)** - архитектура и компоненты
- **[PostgreSQL + Patroni](POSTGRESQL-PATRONI-GUIDE.md)** - управление БД кластером
- **[HAProxy](HAPROXY-GUIDE.md)** - балансировка нагрузки
- **[Архитектурные диаграммы](ARCHITECTURE-DIAGRAM.md)** - схемы системы

## Безопасность

- Все ВМ в приватной подсети
- Доступ только через NAT Gateway
- SSH только по ключам
- PostgreSQL доступ только через HAProxy

## Резервное копирование

```bash
# Создание бэкапа БД
pg_dump -h localhost -U postgres saleor > backup_$(date +%Y%m%d).sql

# Восстановление из бэкапа
psql -h localhost -U postgres saleor < backup_20240116.sql
```

## Поддержка

При возникновении проблем:
1. Проверьте логи сервисов
2. Изучите соответствующую документацию
3. Проверьте статус всех компонентов системы

---

**Время развертывания**: ~15-20 минут  
**Время восстановления**: ~30-60 секунд (PostgreSQL failover)  
**Доступность**: 99.9%+ (с автоматическим failover)
