# Настройка отказоустойчивого кластера PostgreSQL 18

## Обзор архитектуры

Настройка высокодоступного кластера PostgreSQL 18 с использованием:
- **PostgreSQL 18** - основная СУБД
- **Patroni** - управление кластером, автоматический failover
- **HAProxy** - балансировка нагрузки и единая точка входа
- **etcd** (или Consul) - хранилище конфигурации для Patroni

### Топология

```
                    ┌─────────────┐
                    │   HAProxy   │
                    │  (Docker)   │
                    │  :5432      │
                    └──────┬──────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
    ┌───────▼──────┐              ┌───────▼──────┐
    │   CT 104     │              │   CT 105     │
    │ 192.168.50.21│              │ 192.168.50.22│
    │              │              │              │
    │ PostgreSQL  │◄────────────►│ PostgreSQL  │
    │  (Primary)   │   Streaming  │  (Standby)   │
    │             │   Replication │             │
    │  Patroni    │              │  Patroni    │
    └─────────────┘              └─────────────┘
            │                             │
            └──────────────┬──────────────┘
                           │
                    ┌──────▼──────┐
                    │    etcd     │
                    │  (Docker)   │
                    └─────────────┘
```

## Компоненты

### 1. PostgreSQL 18
- Основная СУБД
- Streaming Replication для синхронизации данных
- Автоматическое переключение ролей (Primary/Standby)

### 2. Patroni
- Управление жизненным циклом PostgreSQL
- Автоматический failover при отказе Primary
- Управление репликацией
- Интеграция с etcd для координации

### 3. HAProxy
- Балансировка нагрузки между узлами
- Единая точка входа для приложений
- Автоматическое определение активного Primary
- Health checks

### 4. etcd
- Хранилище конфигурации и состояния кластера
- Координация между узлами Patroni
- Хранение метаданных кластера

### Почему выбраны Patroni и etcd

**Зачем нужен Patroni:**
- **Автоматический failover без самописных скриптов.** Patroni берёт на себя обнаружение отказа Primary и переключение Standby в Primary, что исключает «ручные» переключения по ночам и уменьшает человеческий фактор.
- **Управление конфигурацией PostgreSQL как кластера.** Параметры, критичные для репликации и отказоустойчивости, хранятся централизованно (в DCS) и применяются ко всем узлам единообразно.
- **Прозрачная работа с репликами.** Patroni сам создаёт и пересоздаёт реплики, управляет репликационными слотами, следит за lag и не даёт «сломать» кластер некорректной настройкой.
- **Интеграция с HAProxy и внешними системами.** Через REST API Patroni предоставляет информацию о роли узла (Primary/Replica), состоянии кластера и позволяет безопасно выполнять switchover.

**Зачем нужен etcd (DCS — Distributed Configuration Store):**
- **Единый источник правды о состоянии кластера.** В etcd хранятся данные о лидере (Primary), конфигурация кластера и служебные метаданные; все Patroni-узлы читают одно и то же состояние.
- **Надёжная координация между узлами.** Etcd обеспечивает механизмы распределённых блокировок и lease, на основе которых Patroni реализует безопасный выбор лидера без split-brain.
- **Высокая доступность самого DCS.** Etcd разворачивается как кластер из нескольких узлов; при отказе одного узла DCS продолжает работать, а значит, сохраняется возможность failover PostgreSQL.
- **Простая интеграция и прозрачный протокол.** Etcd использует HTTP/JSON API, его легко мониторить и диагностировать; Patroni имеет встроенную поддержку etcd «из коробки».

**Почему не только встроенная репликация PostgreSQL без Patroni:**
- Стандартная streaming replication даёт механизм копирования данных, но **не решает**:
  - автоматический выбор нового Primary;
  - консенсус между несколькими узлами, кто именно должен стать Primary;
  - централизованное хранение конфигурации и состояний;
  - безопасный switchover и управление жизненным циклом реплик.
- Patroni + etcd как раз добавляют эти недостающие уровни — автоматику, координацию и отказоустойчивость уровня «кластер», а не отдельного сервера PostgreSQL.

## План установки

### Этап 1: Установка PostgreSQL 18
1. Установка PostgreSQL 18 на CT 104
2. Установка PostgreSQL 18 на CT 105
3. Базовая настройка обоих экземпляров

### Этап 2: Настройка репликации
1. Создание пользователя репликации
2. Настройка streaming replication
3. Проверка синхронизации данных

### Этап 3: Установка и настройка Patroni
1. Установка Patroni на оба узла
2. Установка etcd (в Docker на хосте или отдельном контейнере)
3. Настройка конфигурации Patroni
4. Запуск кластера

### Этап 4: Настройка HAProxy
1. Установка HAProxy в Docker
2. Настройка балансировки
3. Настройка health checks
4. Тестирование отказоустойчивости

## Детальная настройка

### Этап 1: Установка PostgreSQL 18

#### На CT 104 и CT 105

```bash
# Запуск скрипта установки
./setup_postgresql18.sh 104
./setup_postgresql18.sh 105
```

**Созданные пользователи:**
- `postgres` - суперпользователь (пароль: Qwe1234!)
- `sqlUser` - пользователь приложения (пароль: Qwe1234!)

**База данных:**
- `sqluser_db` - база данных для sqlUser

### Этап 2: Настройка репликации

#### Шаг 1: Создание пользователя репликации

На Primary (CT 104):
```sql
CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'Replicator123!';
```

#### Шаг 2: Настройка postgresql.conf

На обоих узлах:
```conf
# Включить WAL архивирование
wal_level = replica
max_wal_senders = 3
max_replication_slots = 3

# Настройки для репликации
hot_standby = on
hot_standby_feedback = on
```

#### Шаг 3: Настройка pg_hba.conf

На Primary (CT 104):
```
host    replication     replicator     192.168.50.22/32         md5
```

На Standby (CT 105):
```
host    replication     replicator     192.168.50.21/32         md5
```

#### Шаг 4: Создание репликационного слота

На Primary:
```sql
SELECT pg_create_physical_replication_slot('replica_slot');
```

### Этап 3: Установка Patroni

#### Шаг 1: Установка зависимостей

На обоих узлах:
```bash
dnf install -y python3-pip python3-devel gcc postgresql18-devel
pip3 install patroni[etcd] psycopg2-binary
```

#### Шаг 2: Установка etcd

Вариант 1: В Docker на хосте Proxmox
```bash
docker run -d --name etcd \
  --network host \
  -v /opt/etcd-data:/etcd-data \
  quay.io/coreos/etcd:v3.5.9 \
  /usr/local/bin/etcd \
  --name etcd0 \
  --data-dir /etcd-data \
  --listen-client-urls http://0.0.0.0:2379 \
  --advertise-client-urls http://192.168.50.1:2379 \
  --listen-peer-urls http://0.0.0.0:2380 \
  --initial-advertise-peer-urls http://192.168.50.1:2380 \
  --initial-cluster etcd0=http://192.168.50.1:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-cluster-state new
```

Вариант 2: В отдельном CT (рекомендуется для продакшена)

#### Шаг 3: Конфигурация Patroni для CT 104

`/etc/patroni/patroni.yml`:
```yaml
scope: postgres_cluster
namespace: /db/
name: postgres104

restapi:
  listen: 192.168.50.21:8008
  connect_address: 192.168.50.21:8008

etcd:
  hosts: 192.168.50.1:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 30
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        wal_keep_segments: 8
        max_wal_senders: 3
        max_replication_slots: 3
        checkpoint_timeout: 30

  initdb:
  - encoding: UTF8
  - data-checksums

  pg_hba:
  - host replication replicator 192.168.50.0/24 md5
  - host all all 192.168.50.0/24 md5

  users:
    replicator:
      password: Replicator123!
      options:
        - replication
    sqlUser:
      password: Qwe1234!
      options:
        - createdb

postgresql:
  listen: 192.168.50.21:5432
  connect_address: 192.168.50.21:5432
  data_dir: /var/lib/pgsql/18/data
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

#### Шаг 4: Конфигурация Patroni для CT 105

`/etc/patroni/patroni.yml`:
```yaml
scope: postgres_cluster
namespace: /db/
name: postgres105

restapi:
  listen: 192.168.50.22:8008
  connect_address: 192.168.50.22:8008

etcd:
  hosts: 192.168.50.1:2379

# Остальная конфигурация аналогична CT 104, но с другими IP
postgresql:
  listen: 192.168.50.22:5432
  connect_address: 192.168.50.22:8008
  data_dir: /var/lib/pgsql/18/data
  # ... остальное как в CT 104
```

#### Шаг 5: Создание systemd сервиса для Patroni

`/etc/systemd/system/patroni.service`:
```ini
[Unit]
Description=High availability PostgreSQL Cluster - Patroni
After=syslog.target network.target

[Service]
Type=notify
User=postgres
Group=postgres
ExecStart=/usr/local/bin/patroni /etc/patroni/patroni.yml
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=process
TimeoutSec=30
Restart=no

[Install]
WantedBy=multi-user.target
```

### Этап 4: Настройка HAProxy

#### Шаг 1: Создание конфигурации HAProxy

`/root/haproxy/haproxy.cfg`:
```conf
global
    log stdout format raw local0
    maxconn 4096

defaults
    log global
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

# Frontend для PostgreSQL
frontend postgres_frontend
    bind *:5432
    default_backend postgres_backend

# Backend с health checks
backend postgres_backend
    option httpchk GET /master
    http-check expect status 200
    
    # Primary (CT 104)
    server postgres104 192.168.50.21:5432 check port 8008 inter 3s fall 3 rise 3
    
    # Standby (CT 105) - только для чтения
    server postgres105 192.168.50.22:5432 check port 8008 inter 3s fall 3 rise 3 backup

# Frontend для чтения (опционально)
frontend postgres_readonly
    bind *:5433
    default_backend postgres_readonly_backend

backend postgres_readonly_backend
    option httpchk GET /replica
    http-check expect status 200
    
    server postgres104 192.168.50.21:5432 check port 8008 inter 3s fall 3 rise 3
    server postgres105 192.168.50.22:5432 check port 8008 inter 3s fall 3 rise 3
```

#### Шаг 2: Запуск HAProxy в Docker

```bash
docker run -d --name haproxy \
  --network host \
  -v /root/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
  haproxy:2.8-alpine
```

## Проверка и тестирование

### Проверка статуса кластера

```bash
# Проверка статуса через Patroni API
curl http://192.168.50.21:8008/patroni
curl http://192.168.50.22:8008/patroni

# Проверка через etcd
etcdctl --endpoints=http://192.168.50.1:2379 get /db/postgres_cluster/leader
```

### Тестирование отказоустойчивости

1. **Проверка подключения через HAProxy:**
   ```bash
   psql -h 192.168.50.1 -U sqlUser -d sqluser_db
   ```

2. **Остановка Primary узла:**
   ```bash
   pct exec 104 -- systemctl stop patroni
   ```

3. **Проверка автоматического failover:**
   - CT 105 должен стать Primary
   - HAProxy должен автоматически переключиться

4. **Восстановление узла:**
   ```bash
   pct exec 104 -- systemctl start patroni
   ```
   - Узел должен автоматически стать Standby

## Мониторинг

### Ключевые метрики

1. **Статус узлов:**
   - Primary/Standby состояние
   - Lag репликации
   - Доступность через Patroni API

2. **HAProxy:**
   - Статус health checks
   - Количество активных подключений
   - Статистика по узлам

3. **PostgreSQL:**
   - WAL lag
   - Количество репликационных слотов
   - Размер WAL файлов

## Резервное копирование

### Настройка pgBackRest (рекомендуется)

```bash
# Установка pgBackRest
dnf install -y pgbackrest

# Конфигурация
/etc/pgbackrest.conf:
[global]
repo1-path=/var/lib/pgbackrest
repo1-retention-full=2

[postgres_cluster]
pg1-path=/var/lib/pgsql/18/data
pg1-host=192.168.50.21
pg1-port=5432
```

## Безопасность

1. **Firewall:**
   - Открыть порты 5432, 8008 только для необходимых сетей
   - Ограничить доступ к etcd (порт 2379)

2. **SSL/TLS:**
   - Настроить SSL для PostgreSQL соединений
   - Использовать сертификаты для репликации

3. **Пароли:**
   - Использовать сильные пароли
   - Хранить пароли в защищенных местах
   - Ротация паролей

## Устранение неполадок

### Проблема: Patroni не может подключиться к etcd

**Решение:**
- Проверить доступность etcd: `curl http://192.168.50.1:2379/health`
- Проверить firewall правила
- Проверить логи Patroni: `journalctl -u patroni -f`

### Проблема: Репликация не работает

**Решение:**
- Проверить пользователя replicator: `SELECT * FROM pg_user WHERE usename = 'replicator';`
- Проверить pg_hba.conf
- Проверить репликационные слоты: `SELECT * FROM pg_replication_slots;`
- Проверить WAL lag: `SELECT * FROM pg_stat_replication;`

### Проблема: HAProxy не переключается на другой узел

**Решение:**
- Проверить health checks: `curl http://192.168.50.21:8008/master`
- Проверить конфигурацию HAProxy
- Проверить логи HAProxy: `docker logs haproxy`

## Полезные команды

```bash
# Статус Patroni
patronictl -c /etc/patroni/patroni.yml list

# Переключение Primary вручную
patronictl -c /etc/patroni/patroni.yml switchover

# Перезагрузка кластера
patronictl -c /etc/patroni/patroni.yml restart postgres_cluster

# Проверка репликации
psql -h 192.168.50.21 -U postgres -c "SELECT * FROM pg_stat_replication;"

# Проверка lag
psql -h 192.168.50.21 -U postgres -c "SELECT pg_current_wal_lsn(), pg_last_wal_replay_lsn();"
```



