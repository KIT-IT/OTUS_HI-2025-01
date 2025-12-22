# PostgreSQL HA Cluster с Patroni и etcd

## Содержание

1. [Архитектура кластера](#архитектура-кластера)
2. [Компоненты системы](#компоненты-системы)
3. [Зависимости между компонентами](#зависимости-между-компонентами)
4. [Схема кластера](#схема-кластера)
5. [Настройки компонентов](#настройки-компонентов)
6. [Установка и развертывание](#установка-и-развертывание)
7. [Управление кластером](#управление-кластером)
8. [Мониторинг и проверка](#мониторинг-и-проверка)
9. [Troubleshooting](#troubleshooting)

---

## Архитектура кластера

Кластер PostgreSQL High Availability состоит из следующих компонентов:

- **PostgreSQL 18** - база данных (3 узла: master + 2 реплики)
- **Patroni** - система управления HA для PostgreSQL
- **etcd** - распределенное хранилище ключ-значение для координации (3 узла)
- **HAProxy** - балансировщик нагрузки (2 узла)

### Принцип работы

1. **etcd** хранит состояние кластера и координацию между узлами Patroni
2. **Patroni** управляет жизненным циклом PostgreSQL и обеспечивает автоматический failover
3. **PostgreSQL** работает в режиме streaming replication (master-replica)
4. **HAProxy** распределяет запросы между узлами PostgreSQL

---

## Компоненты системы

### 1. etcd (Distributed Coordination Store)

**Назначение:** Хранит метаданные кластера, состояние лидера, конфигурацию Patroni

**Узлы:**
- CT 109 (etcd1): 192.168.50.51
- CT 110 (etcd2): 192.168.50.52
- CT 111 (etcd3): 192.168.50.53

**Версия:** 3.5.13

**Порты:**
- 2379 - клиентские подключения
- 2380 - пиринговые подключения между узлами etcd

### 2. PostgreSQL 18

**Назначение:** База данных с поддержкой streaming replication

**Узлы:**
- CT 102 (pg102): 192.168.50.21 - replica
- CT 103 (pg103): 192.168.50.22 - master (лидер)
- CT 104 (pg104): 192.168.50.23 - replica

**Порт:** 5432

**Версия:** 18.1

### 3. Patroni

**Назначение:** Управление HA для PostgreSQL, автоматический failover

**Узлы:** Те же, что и PostgreSQL (102, 103, 104)

**Порты:**
- 8008 - REST API для мониторинга и управления

**Версия:** 3.3.0

### 4. HAProxy

**Назначение:** Балансировка нагрузки и единая точка входа

**Узлы:**
- CT 100 (haproxy1): 192.168.50.11
- CT 101 (haproxy2): 192.168.50.12

**Порты:**
- 5432 - PostgreSQL (балансировка)
- 8404 - Статистика HAProxy

---

## Зависимости между компонентами

```
┌─────────────────────────────────────────────────────────────┐
│                        HAProxy                              │
│                    (CT 100, 101)                            │
│                  Единая точка входа                        │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL + Patroni                      │
│              CT 102 (replica)                               │
│              CT 103 (master) ←────────────────┐            │
│              CT 104 (replica)                 │            │
└───────────────────────┬───────────────────────┼────────────┘
                        │                       │
                        │                       │
                        ▼                       │
┌───────────────────────────────────────────────┼────────────┐
│                    etcd                       │            │
│         CT 109 (etcd1)                        │            │
│         CT 110 (etcd2)                        │            │
│         CT 111 (etcd3)                        │            │
│    Координация и хранение состояния          │            │
└───────────────────────────────────────────────┴────────────┘
```

### Порядок запуска компонентов:

1. **etcd** - должен быть запущен первым (координация)
2. **Patroni** - запускается после etcd, управляет PostgreSQL
3. **PostgreSQL** - запускается автоматически Patroni
4. **HAProxy** - может быть запущен в любое время

### Зависимости:

- **Patroni** → **etcd**: Patroni использует etcd для координации и хранения состояния
- **Patroni** → **PostgreSQL**: Patroni управляет жизненным циклом PostgreSQL
- **PostgreSQL** → **PostgreSQL**: Streaming replication между master и replicas
- **HAProxy** → **Patroni REST API**: Проверка здоровья через REST API (порт 8008)
- **HAProxy** → **PostgreSQL**: Балансировка подключений к PostgreSQL (порт 5432)

---

## Схема кластера

```
                    ┌─────────────────┐
                    │   HAProxy 1     │
                    │ 192.168.50.11   │
                    │    CT 100       │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
                    │   ┌─────────┐   │
                    │   │HAProxy 2│   │
                    │   │192.168. │   │
                    │   │50.12    │   │
                    │   │CT 101   │   │
                    │   └─────────┘   │
                    │                 │
        ┌───────────┴─────────────────┴───────────┐
        │                                          │
        │         PostgreSQL + Patroni            │
        │                                          │
        │  ┌──────────┐  ┌──────────┐  ┌──────────┐
        │  │ pg102    │  │ pg103    │  │ pg104    │
        │  │ replica  │  │ master   │  │ replica  │
        │  │ 50.21    │  │ 50.22    │  │ 50.23    │
        │  │ CT 102   │  │ CT 103   │  │ CT 104   │
        │  └────┬─────┘  └────┬─────┘  └────┬─────┘
        │       │             │             │
        │       └─────────────┴─────────────┘
        │              Streaming Replication
        │
        └──────────────────┬───────────────────┐
                           │                   │
                           │                   │
        ┌──────────────────┴───────────────────┴──────────┐
        │                                                  │
        │                    etcd                         │
        │                                                  │
        │  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
        │  │ etcd1    │  │ etcd2    │  │ etcd3    │     │
        │  │ 50.51    │  │ 50.52    │  │ 50.53    │     │
        │  │ CT 109   │  │ CT 110   │  │ CT 111   │     │
        │  └────┬─────┘  └────┬─────┘  └────┬─────┘     │
        │       │             │             │            │
        │       └─────────────┴─────────────┘            │
        │              Кластер etcd                       │
        │         (координация Patroni)                   │
        └──────────────────────────────────────────────────┘
```

### Потоки данных:

1. **Клиент → HAProxy → PostgreSQL**: Запросы к базе данных
2. **PostgreSQL master → PostgreSQL replicas**: Streaming replication (WAL)
3. **Patroni ↔ etcd**: Координация и хранение состояния
4. **HAProxy → Patroni REST API**: Проверка здоровья узлов

---

## Настройки компонентов

### 1. etcd

#### Конфигурация (`/etc/etcd/etcd.conf`)

```ini
ETCD_NAME=etcd1                    # Уникальное имя узла
ETCD_DATA_DIR=/var/lib/etcd        # Директория данных
ETCD_LISTEN_CLIENT_URLS=http://192.168.50.51:2379,http://127.0.0.1:2379
ETCD_ADVERTISE_CLIENT_URLS=http://192.168.50.51:2379
ETCD_LISTEN_PEER_URLS=http://192.168.50.51:2380
ETCD_INITIAL_ADVERTISE_PEER_URLS=http://192.168.50.51:2380
ETCD_INITIAL_CLUSTER=etcd1=http://192.168.50.51:2380,etcd2=http://192.168.50.52:2380,etcd3=http://192.168.50.53:2380
ETCD_INITIAL_CLUSTER_TOKEN=patroni-cluster-token
ETCD_INITIAL_CLUSTER_STATE=new
```

#### Переменные (Ansible)

```yaml
etcd_version: "3.5.13"
etcd_user: "etcd"
etcd_group: "etcd"
etcd_data_dir: "/var/lib/etcd"
etcd_client_port: 2379
etcd_peer_port: 2380
etcd_cluster_name: "patroni-cluster"
```

#### Проверка работы

```bash
# Проверка здоровья кластера
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 endpoint health

# Просмотр всех ключей
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 get --prefix / --keys-only
```

### 2. PostgreSQL 18

#### Основные настройки (`postgresql.conf`)

```ini
listen_addresses = '*'              # Слушать на всех интерфейсах
port = 5432                         # Порт PostgreSQL
wal_level = replica                 # Уровень WAL для репликации
max_wal_senders = 3                 # Максимум потоков репликации
max_replication_slots = 10          # Максимум слотов репликации
hot_standby = on                    # Разрешить hot standby
hot_standby_feedback = on           # Обратная связь от реплик
wal_keep_size = 512MB               # Размер WAL для репликации
wal_log_hints = on                  # Логирование hints для pg_rewind
archive_mode = on                   # Включить архивирование
archive_command = 'mkdir -p /var/lib/pgsql/18/archive && cp %p /var/lib/pgsql/18/archive/%f'
archive_timeout = 300s              # Таймаут архивирования
```

#### Настройки репликации (`pg_hba.conf`)

```
host replication replicator 0.0.0.0/0 md5
host all all 0.0.0.0/0 md5
```

#### Переменные (Ansible)

```yaml
postgresql_version: 18
postgresql_data_dir: "/var/lib/pgsql/18/data"
postgresql_listen_addresses: "*"
postgresql_port: 5432
postgresql_allowed_networks:
  - "192.168.50.0/24"
```

#### Проверка работы

```bash
# Проверка подключения
pct exec 103 -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres -c "SELECT version();"

# Проверка репликации (на master)
pct exec 103 -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres -c "SELECT * FROM pg_stat_replication;"

# Проверка режима (на replica)
pct exec 102 -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres -c "SELECT pg_is_in_recovery();"
```

### 3. Patroni

#### Конфигурация (`/etc/patroni/patroni.yml`)

```yaml
scope: postgres                    # Имя кластера
namespace: /patroni/               # Namespace в etcd
name: pg103                        # Уникальное имя узла

restapi:
  listen: 192.168.50.22:8008       # REST API для мониторинга
  connect_address: 192.168.50.22:8008

etcd3:
  hosts: 192.168.50.51:2379,192.168.50.52:2379,192.168.50.53:2379

bootstrap:
  dcs:
    ttl: 60                        # TTL для блокировки лидера
    loop_wait: 10                   # Интервал проверки (секунды)
    retry_timeout: 20               # Таймаут повтора
    maximum_lag_on_failover: 1048576  # Максимальный lag для failover
    postgresql:
      use_pg_rewind: true           # Использовать pg_rewind
      use_slots: true                # Использовать replication slots
      parameters:
        wal_level: replica
        hot_standby: "on"
        wal_keep_size: 512MB
        max_wal_senders: 3
        max_replication_slots: 10
        wal_log_hints: "on"
        archive_mode: "on"
        archive_command: "mkdir -p /var/lib/pgsql/18/archive && cp %p /var/lib/pgsql/18/archive/%f"
        archive_timeout: 300s
  initdb:
    - encoding: UTF8
    - data-checksums
  pg_hba:
    - host replication replicator 0.0.0.0/0 md5
    - host all all 0.0.0.0/0 md5
  users:
    replicator:
      password: Replicator123!
      options:
        - replication
    postgres:
      password: Qwe1234!
      options:
        - createrole
        - createdb

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 192.168.50.22:5432
  data_dir: /var/lib/pgsql/18/data
  bin_dir: /usr/pgsql-18/bin
  pgpass: /var/lib/pgsql/.pgpass
  authentication:
    replication:
      username: replicator
      password: Replicator123!
    superuser:
      username: postgres
      password: Qwe1234!
  parameters:
    unix_socket_directories: '/var/run/postgresql'

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
```

#### Переменные (Ansible)

```yaml
patroni_version: "3.3.0"
patroni_scope: "postgres"
patroni_namespace: "/patroni/"
patroni_config_dir: "/etc/patroni"
patroni_user: "postgres"
patroni_restapi_port: 8008
patroni_postgresql_listen: "0.0.0.0:5432"
patroni_postgresql_data_dir: "/var/lib/pgsql/18/data"
patroni_postgresql_bin_dir: "/usr/pgsql-18/bin"
patroni_replication_username: "replicator"
patroni_replication_password: "Replicator123!"
patroni_superuser_username: "postgres"
patroni_superuser_password: "Qwe1234!"
```

#### Проверка работы

```bash
# Проверка статуса через REST API
curl http://192.168.50.22:8008/patroni

# Проверка лидера
curl http://192.168.50.22:8008/patroni | python3 -m json.tool | grep role

# Проверка здоровья
curl http://192.168.50.22:8008/health
```

### 4. HAProxy

#### Конфигурация (`/etc/haproxy/haproxy.cfg`)

```haproxy
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /var/lib/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

# Статистика HAProxy
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 30s
    stats admin if TRUE
    stats auth admin:admin

# PostgreSQL кластер
frontend postgresql_frontend
    bind *:5432
    default_backend postgresql_backend

backend postgresql_backend
    option httpchk GET /patroni
    http-check expect status 200
    server pg102 192.168.50.21:5432 check port 8008 inter 3s fall 3 rise 3
    server pg103 192.168.50.22:5432 check port 8008 inter 3s fall 3 rise 3
    server pg104 192.168.50.23:5432 check port 8008 inter 3s fall 3 rise 3
```

#### Переменные (Ansible)

```yaml
haproxy_listen_port: 5432
haproxy_stats_port: 8404
haproxy_stats_user: "admin"
haproxy_stats_password: "admin"
```

#### Проверка работы

```bash
# Проверка статистики
curl http://192.168.50.11:8404/stats

# Проверка подключения
psql -h 192.168.50.11 -U postgres -d postgres
```

---

## Установка и развертывание

### Предварительные требования

1. **Proxmox LXC контейнеры:**
   - CT 100, 101 - HAProxy
   - CT 102, 103, 104 - PostgreSQL + Patroni
   - CT 109, 110, 111 - etcd

2. **Пользователь:** `sedunovsv` с правами sudo без пароля

3. **Сеть:** Все контейнеры в одной подсети (192.168.50.0/24)

### Порядок установки

#### 1. Установка etcd кластера

```bash
cd /root/ansible-postgresql
ansible-playbook -i inventory/hosts.yml playbook.yml --limit etcd
```

**Что делает:**
- Создает пользователя etcd
- Скачивает и устанавливает etcd 3.5.13
- Настраивает конфигурацию для каждого узла
- Запускает etcd кластер

**Проверка:**
```bash
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 endpoint health
```

#### 2. Установка PostgreSQL и Patroni

```bash
cd /root/ansible-postgresql
ansible-playbook -i inventory/hosts.yml playbook.yml --limit postgresql
```

**Что делает:**
- Устанавливает PostgreSQL 18
- Устанавливает Python зависимости для Patroni
- Устанавливает Patroni через pip
- Настраивает конфигурацию Patroni для каждого узла
- Отключает автозапуск PostgreSQL (управляется Patroni)
- Запускает Patroni, который инициализирует PostgreSQL

**Проверка:**
```bash
# Проверка статуса Patroni
for ct in 102 103 104; do
  ip=$(pct config $ct | grep "ip=" | awk -F'ip=' '{print $2}' | awk -F',' '{print $1}' | awk -F'/' '{print $1}')
  echo "CT $ct ($ip):"
  curl -s http://$ip:8008/patroni | python3 -m json.tool | grep -E "role|state" | head -2
done
```

#### 3. Установка HAProxy

```bash
cd /root/ansible-postgresql
ansible-playbook -i inventory/hosts.yml playbook.yml --limit haproxy
```

**Что делает:**
- Устанавливает HAProxy
- Настраивает конфигурацию с health checks через Patroni REST API
- Запускает HAProxy

**Проверка:**
```bash
# Проверка статистики
curl http://192.168.50.11:8404/stats
```

### Полная установка

```bash
cd /root/ansible-postgresql
ansible-playbook -i inventory/hosts.yml playbook.yml
```

---

## Управление кластером

### Проверка статуса кластера

#### Использование скриптов

```bash
# Проверка etcd
/root/view_etcd.sh --full

# Проверка PostgreSQL и Patroni
/root/check_postgres_patroni.sh --full
```

#### Ручная проверка

**etcd:**
```bash
# Здоровье кластера
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 endpoint health

# Просмотр данных Patroni
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 get --prefix /patroni/
```

**Patroni:**
```bash
# Статус через REST API
curl http://192.168.50.22:8008/patroni | python3 -m json.tool

# Проверка лидера
curl http://192.168.50.22:8008/patroni | python3 -m json.tool | grep leader
```

**PostgreSQL:**
```bash
# Подключение к master
psql -h 192.168.50.22 -U postgres -d postgres

# Проверка репликации
psql -h 192.168.50.22 -U postgres -d postgres -c "SELECT * FROM pg_stat_replication;"
```

### Управление Patroni

#### Перезапуск Patroni

```bash
# На конкретном узле
pct exec 103 -- systemctl restart patroni

# На всех узлах
for ct in 102 103 104; do
  pct exec $ct -- systemctl restart patroni
done
```

#### Переключение лидера (manual failover)

```bash
# Переключение на другой узел
curl -X POST http://192.168.50.22:8008/failover

# Переключение на конкретный узел
curl -X POST http://192.168.50.22:8008/failover -d '{"leader": "pg102"}'
```

#### Перезагрузка конфигурации PostgreSQL

```bash
# Перезагрузка без перезапуска
curl -X POST http://192.168.50.22:8008/reload
```

### Управление PostgreSQL

**Важно:** Не запускайте PostgreSQL напрямую через systemd! Patroni управляет PostgreSQL.

```bash
# Проверка процесса
pct exec 103 -- ps aux | grep postgres

# Проверка подключений
pct exec 103 -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

### Управление etcd

#### Перезапуск etcd

```bash
# На конкретном узле
pct exec 109 -- systemctl restart etcd

# На всех узлах
for ct in 109 110 111; do
  pct exec $ct -- systemctl restart etcd
done
```

#### Очистка данных Patroni в etcd

```bash
# ВНИМАНИЕ: Это удалит все данные Patroni!
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 del --prefix /patroni/
```

---

## Мониторинг и проверка

### Скрипты для мониторинга

#### 1. Просмотр информации etcd

```bash
/root/view_etcd.sh --full          # Полная информация
/root/view_etcd.sh --patroni       # Только Patroni
/root/view_etcd.sh --health        # Только здоровье
/root/view_etcd.sh                 # Интерактивное меню
```

#### 2. Проверка PostgreSQL и Patroni

```bash
/root/check_postgres_patroni.sh --full     # Полная проверка
/root/check_postgres_patroni.sh --postgres # Только PostgreSQL
/root/check_postgres_patroni.sh --patroni  # Только Patroni
/root/check_postgres_patroni.sh --cluster   # Информация о кластере
/root/check_postgres_patroni.sh            # Интерактивное меню
```

### Ключевые метрики

#### etcd

- **Здоровье кластера:** Все 3 узла должны быть healthy
- **Лидер:** Должен быть выбран лидер
- **Размер данных:** Мониторить размер `/var/lib/etcd`

#### Patroni

- **Роль узла:** master или replica
- **Состояние:** running
- **Timeline:** Все узлы должны быть на одной timeline
- **Lag:** Задержка репликации (должна быть минимальной)

#### PostgreSQL

- **Подключения:** Количество активных подключений
- **Репликация:** Статус streaming replication
- **WAL:** Размер и количество WAL файлов
- **Производительность:** Время выполнения запросов

### Логи

#### etcd

```bash
# Логи etcd
pct exec 109 -- journalctl -u etcd -f

# Последние 50 строк
pct exec 109 -- journalctl -u etcd -n 50
```

#### Patroni

```bash
# Логи Patroni
pct exec 103 -- journalctl -u patroni -f

# Последние 50 строк
pct exec 103 -- journalctl -u patroni -n 50
```

#### PostgreSQL

```bash
# Логи PostgreSQL
pct exec 103 -- tail -f /var/lib/pgsql/18/data/log/*.log

# Последние 50 строк
pct exec 103 -- tail -n 50 /var/lib/pgsql/18/data/log/*.log
```

---

## Troubleshooting

### Проблема: etcd не запускается

**Симптомы:**
- `systemctl status etcd` показывает failed
- Логи: "bind: cannot assign requested address"

**Решение:**
1. Проверить IP адрес в конфигурации `/etc/etcd/etcd.conf`
2. Убедиться, что IP соответствует IP контейнера
3. Проверить, что порты 2379 и 2380 не заняты
4. Проверить, что все узлы etcd имеют правильные IP в `ETCD_INITIAL_CLUSTER`

### Проблема: Patroni не может подключиться к etcd

**Симптомы:**
- Логи Patroni: "Failed to get list of machines"
- Patroni не запускается

**Решение:**
1. Проверить здоровье etcd кластера
2. Проверить сетевую связность между узлами
3. Проверить конфигурацию Patroni (`/etc/patroni/patroni.yml`)
4. Убедиться, что etcd запущен на всех узлах

### Проблема: PostgreSQL не запускается

**Симптомы:**
- Процесс PostgreSQL не найден
- Patroni показывает ошибки в логах

**Решение:**
1. Проверить логи Patroni: `journalctl -u patroni -n 50`
2. Проверить права доступа к директории данных: `/var/lib/pgsql/18/data`
3. Проверить, что Patroni может подключиться к etcd
4. Очистить данные и переинициализировать (если необходимо)

### Проблема: Репликация не работает

**Симптомы:**
- Реплики не синхронизируются
- Lag увеличивается

**Решение:**
1. Проверить статус репликации на master:
   ```sql
   SELECT * FROM pg_stat_replication;
   ```
2. Проверить статус на реплике:
   ```sql
   SELECT pg_is_in_recovery();
   SELECT * FROM pg_stat_wal_receiver;
   ```
3. Проверить настройки `wal_level`, `max_wal_senders`, `max_replication_slots`
4. Проверить `pg_hba.conf` для разрешения репликации

### Проблема: Failover не происходит

**Симптомы:**
- При падении master реплика не становится master
- Patroni не переключает роли

**Решение:**
1. Проверить настройки `ttl`, `loop_wait`, `retry_timeout` в Patroni
2. Проверить, что etcd кластер работает
3. Проверить логи Patroni на всех узлах
4. Убедиться, что реплики синхронизированы

### Проблема: HAProxy не видит узлы

**Симптомы:**
- HAProxy показывает узлы как DOWN
- Невозможно подключиться через HAProxy

**Решение:**
1. Проверить, что Patroni REST API доступен на всех узлах
2. Проверить конфигурацию HAProxy (`/etc/haproxy/haproxy.cfg`)
3. Проверить health check endpoint: `curl http://192.168.50.22:8008/patroni`
4. Проверить статистику HAProxy: `curl http://192.168.50.11:8404/stats`

---

## Полезные команды

### etcd

```bash
# Просмотр всех ключей
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 get --prefix / --keys-only

# Просмотр данных Patroni
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 get --prefix /patroni/

# Просмотр лидера
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 get /patroni/postgres/leader
```

### Patroni

```bash
# Статус узла
curl http://192.168.50.22:8008/patroni | python3 -m json.tool

# История кластера
curl http://192.168.50.22:8008/history | python3 -m json.tool

# Переключение лидера
curl -X POST http://192.168.50.22:8008/failover

# Перезагрузка конфигурации
curl -X POST http://192.168.50.22:8008/reload

# Перезапуск PostgreSQL
curl -X POST http://192.168.50.22:8008/restart
```

### PostgreSQL

```bash
# Подключение к базе
psql -h 192.168.50.22 -U postgres -d postgres

# Проверка репликации (на master)
SELECT * FROM pg_stat_replication;

# Проверка режима (на replica)
SELECT pg_is_in_recovery();

# Проверка слотов репликации
SELECT * FROM pg_replication_slots;

# Проверка WAL
SELECT pg_current_wal_lsn();
```

### HAProxy

```bash
# Статистика
curl http://192.168.50.11:8404/stats

# Проверка подключения
psql -h 192.168.50.11 -U postgres -d postgres
```

---

## Резервное копирование

### pg_dump

```bash
# Резервное копирование базы данных
pct exec 103 -- sudo -u postgres /usr/pgsql-18/bin/pg_dump -h localhost -U postgres -d postgres > backup.sql

# Восстановление
pct exec 103 -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres < backup.sql
```

### pg_basebackup

```bash
# Физическое резервное копирование
pct exec 103 -- sudo -u postgres /usr/pgsql-18/bin/pg_basebackup -h 192.168.50.22 -U replicator -D /backup/postgres -Ft -z -P
```

---

## Обновление и обслуживание

### Обновление Patroni

```bash
# Остановка Patroni на всех узлах
for ct in 102 103 104; do
  pct exec $ct -- systemctl stop patroni
done

# Обновление через pip
for ct in 102 103 104; do
  pct exec $ct -- pip3 install --upgrade patroni[etcd]
done

# Запуск Patroni
for ct in 102 103 104; do
  pct exec $ct -- systemctl start patroni
done
```

### Обновление PostgreSQL

**Внимание:** Обновление PostgreSQL требует особой осторожности в HA кластере!

1. Обновить реплики по очереди
2. Переключить лидера на обновленную реплику
3. Обновить бывший master

---

## Безопасность

### Рекомендации

1. **Пароли:** Используйте сильные пароли для всех пользователей
2. **Сеть:** Ограничьте доступ к портам только необходимым IP
3. **SSL/TLS:** Настройте SSL для подключений к PostgreSQL
4. **Брандмауэр:** Настройте правила firewall
5. **Мониторинг:** Настройте мониторинг и алертинг

### Текущие настройки безопасности

- **PostgreSQL:** Доступ через сеть с аутентификацией MD5
- **Patroni REST API:** Доступен без аутентификации (только для мониторинга)
- **etcd:** Доступен без аутентификации (внутренняя сеть)
- **HAProxy:** Статистика защищена паролем

---

## Контакты и поддержка

- **Документация Patroni:** https://patroni.readthedocs.io/
- **Документация etcd:** https://etcd.io/docs/
- **Документация PostgreSQL:** https://www.postgresql.org/docs/

---

## Приложение: Схема портов

```
┌─────────────────────────────────────────────────────────┐
│                    Порты сервисов                       │
├─────────────────────────────────────────────────────────┤
│ etcd:                                                    │
│   - 2379 (клиентские подключения)                       │
│   - 2380 (пиринговые подключения)                       │
│                                                          │
│ PostgreSQL:                                              │
│   - 5432 (подключения к БД)                             │
│                                                          │
│ Patroni:                                                 │
│   - 8008 (REST API)                                      │
│                                                          │
│ HAProxy:                                                 │
│   - 5432 (PostgreSQL балансировка)                      │
│   - 8404 (статистика)                                   │
└─────────────────────────────────────────────────────────┘
```

---

## Приложение: Структура данных в etcd

```
/patroni/
  └── postgres/
      ├── config          # Конфигурация кластера
      ├── leader          # Текущий лидер
      ├── status          # Статус кластера
      ├── initialize      # System ID кластера
      ├── history         # История изменений
      └── members/
          ├── pg102       # Информация о узле pg102
          ├── pg103       # Информация о узле pg103
          └── pg104       # Информация о узле pg104
```

---

*Документация обновлена: 2025-12-17*


