# PostgreSQL + Patroni: Руководство по высокодоступному кластеру

## Что такое Patroni и зачем он нужен

**Patroni** - это система управления PostgreSQL кластером, которая обеспечивает автоматический failover и высокую доступность базы данных.

### Основные проблемы без Patroni:
- **Ручной failover**: При сбое master нужно вручную переключать на replica
- **Потеря данных**: Риск потери транзакций при сбое
- **Долгое восстановление**: Время простоя может быть значительным
- **Сложность управления**: Нужно вручную следить за состоянием узлов

### Что решает Patroni:
- **Автоматический failover**: Переключение на replica за 30-60 секунд
- **Zero data loss**: Гарантия сохранности данных
- **Автоматическое восстановление**: Восстановление сбоев без вмешательства
- **Централизованное управление**: Единая точка управления кластером

## Архитектура Patroni кластера

```
┌─────────────────────────────────────────────────────────────┐
│                    Patroni Cluster                         │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │   Node 1    │    │   Node 2    │    │   Node 3    │    │
│  │  (Master)   │    │ (Replica)   │    │ (Replica)   │    │
│  │             │    │             │    │             │    │
│  │ PostgreSQL  │    │ PostgreSQL  │    │ PostgreSQL  │    │
│  │   Port 5432 │    │   Port 5432 │    │   Port 5432 │    │
│  │             │    │             │    │             │    │
│  │ Patroni     │    │ Patroni     │    │ Patroni     │    │
│  │ Port 8008   │    │ Port 8008   │    │ Port 8008   │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│         │                   │                   │          │
│         └───────────────────┼───────────────────┘          │
│                             │                              │
│  ┌─────────────────────────┴─────────────────────────┐    │
│  │                etcd Cluster                       │    │
│  │            (Coordination Store)                   │    │
│  │              Port 2379                            │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Компоненты системы

### 1. PostgreSQL
- **Master**: Принимает запросы на запись и чтение
- **Replicas**: Только чтение, синхронизация с master
- **Streaming Replication**: Реальное время синхронизации данных

### 2. Patroni
- **Leader Election**: Выбор master узла
- **Health Monitoring**: Проверка состояния PostgreSQL
- **Failover Management**: Автоматическое переключение
- **Configuration Management**: Управление конфигурацией

### 3. etcd
- **Distributed Lock**: Блокировка для выбора master
- **Configuration Store**: Хранение метаданных кластера
- **Leader Election**: Координация выбора лидера

## Принцип работы

### 1. Инициализация кластера
```bash
# На первом узле
patronictl -c /etc/patroni/patroni.yml bootstrap saleor-cluster
```

### 2. Leader Election
1. **Запрос лидерства**: Узел запрашивает роль master в etcd
2. **Проверка здоровья**: Patroni проверяет состояние PostgreSQL
3. **Получение блокировки**: Успешный узел становится master
4. **Уведомление**: Другие узлы получают уведомление о новом master

### 3. Streaming Replication
```sql
-- На master узле
SELECT client_addr, state, sync_state 
FROM pg_stat_replication;
```

### 4. Failover процесс
1. **Обнаружение сбоя**: Patroni не может подключиться к master
2. **Освобождение блокировки**: etcd освобождает блокировку master
3. **Выбор нового master**: Один из replica узлов становится master
4. **Обновление конфигурации**: Остальные узлы переключаются на новый master

## Конфигурация Patroni

### Основной файл конфигурации
```yaml
# /etc/patroni/patroni.yml
scope: saleor-cluster
name: patroni-1
namespace: /saleor/

restapi:
  listen: 0.0.0.0:8008
  connect_address: 10.20.0.10:8008

etcd3:
  host: 10.20.0.10:2379

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 10.20.0.10:5432
  data_dir: /var/lib/postgresql/15/main
  
  authentication:
    replication:
      username: replicator
      password: replicator_password
    superuser:
      username: postgres
      password: postgres_password

  parameters:
    max_connections: 100
    shared_buffers: 256MB
    effective_cache_size: 1GB
    wal_level: replica
    hot_standby: on
    max_wal_senders: 3
    max_replication_slots: 3

  pg_hba.conf:
    - host all all 0.0.0.0/0 md5
    - host replication replicator 10.20.0.0/24 md5

  recovery_conf:
    restore_command: 'cp /var/lib/postgresql/15/archive/%f %p'

  use_pg_rewind: true
  use_slots: true

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
```

## Управление кластером

### Основные команды
```bash
# Статус кластера
patronictl -c /etc/patroni/patroni.yml list

# Перезапуск узла
patronictl -c /etc/patroni/patroni.yml restart saleor-cluster patroni-1

# Переключение master
patronictl -c /etc/patroni/patroni.yml failover saleor-cluster

# Перезагрузка конфигурации
patronictl -c /etc/patroni/patroni.yml reload saleor-cluster

# История кластера
patronictl -c /etc/patroni/patroni.yml history saleor-cluster
```

### Мониторинг
```bash
# Статус PostgreSQL
systemctl status postgresql

# Статус Patroni
systemctl status patroni

# Логи Patroni
journalctl -u patroni -f

# Логи PostgreSQL
tail -f /var/log/postgresql/postgresql-15-main.log
```

## HAProxy интеграция

### Конфигурация HAProxy для PostgreSQL
```haproxy
# /etc/haproxy/haproxy.cfg
global
    log /dev/log    local0
    log /dev/log    local1 notice
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5s
    timeout client  50s
    timeout server  50s

frontend postgres
    bind *:5432
    default_backend patroni_pg

backend patroni_pg
    option tcp-check
    tcp-check connect port 5432
    default-server inter 3s fall 3 rise 2
    server patroni-1 10.20.0.10:5432 check
    server patroni-2 10.20.0.11:5432 check
    server patroni-3 10.20.0.12:5432 check
```

### Health Check через Patroni REST API
```bash
# Проверка статуса узла
curl http://10.20.0.10:8008/patroni

# Проверка master
curl http://10.20.0.10:8008/master

# Проверка replica
curl http://10.20.0.11:8008/replica
```

## Резервное копирование

### Стратегия бэкапов
```bash
# Полный бэкап
pg_dump -h localhost -U postgres saleor > backup_$(date +%Y%m%d).sql

# Инкрементальный бэкап (WAL архивы)
# В postgresql.conf
archive_mode = on
archive_command = 'cp %p /var/lib/postgresql/15/archive/%f'

# Point-in-time recovery
pg_basebackup -h 10.20.0.10 -U replicator -D /backup/base -Ft -z -P
```

### Восстановление
```bash
# Восстановление из полного бэкапа
psql -h localhost -U postgres saleor < backup_20240116.sql

# Point-in-time recovery
# 1. Остановить PostgreSQL
systemctl stop postgresql

# 2. Восстановить base backup
rm -rf /var/lib/postgresql/15/main/*
tar -xzf /backup/base/base.tar.gz -C /var/lib/postgresql/15/main/

# 3. Настроить recovery
echo "restore_command = 'cp /var/lib/postgresql/15/archive/%f %p'" >> /var/lib/postgresql/15/main/recovery.conf
echo "recovery_target_time = '2024-01-16 12:00:00'" >> /var/lib/postgresql/15/main/recovery.conf

# 4. Запустить PostgreSQL
systemctl start postgresql
```

## Мониторинг и алерты

### Ключевые метрики
```sql
-- Статус репликации
SELECT 
    client_addr,
    state,
    sync_state,
    sync_priority,
    lag
FROM pg_stat_replication;

-- Размер WAL файлов
SELECT 
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) as wal_size;

-- Активные соединения
SELECT count(*) as active_connections 
FROM pg_stat_activity 
WHERE state = 'active';
```

### Настройка алертов
```bash
# Скрипт проверки master
#!/bin/bash
MASTER=$(patronictl -c /etc/patroni/patroni.yml list | grep -c "Leader")
if [ $MASTER -eq 0 ]; then
    echo "ALERT: No master found in cluster!"
    # Отправить уведомление
fi
```

## Устранение неполадок

### Частые проблемы

1. **Split Brain (Разделение мозга)**
   ```bash
   # Проверка статуса всех узлов
   patronictl -c /etc/patroni/patroni.yml list
   
   # Принудительное переключение
   patronictl -c /etc/patroni/patroni.yml failover saleor-cluster
   ```

2. **Проблемы с репликацией**
   ```sql
   -- Проверка статуса репликации
   SELECT * FROM pg_stat_replication;
   
   -- Проверка слотов репликации
   SELECT * FROM pg_replication_slots;
   ```

3. **Проблемы с etcd**
   ```bash
   # Проверка статуса etcd
   etcdctl cluster-health
   
   # Перезапуск etcd
   systemctl restart etcd
   ```

### Логи для диагностики
```bash
# Patroni логи
journalctl -u patroni -f

# PostgreSQL логи
tail -f /var/log/postgresql/postgresql-15-main.log

# etcd логи
journalctl -u etcd -f

# HAProxy логи
tail -f /var/log/haproxy.log
```

## Производительность

### Оптимизация PostgreSQL
```sql
-- Основные параметры
shared_buffers = 256MB                    -- 25% от RAM
effective_cache_size = 1GB                -- 75% от RAM
work_mem = 4MB                            -- Для сортировки
maintenance_work_mem = 64MB               -- Для VACUUM
checkpoint_completion_target = 0.9        -- Плавные checkpoint'ы
wal_buffers = 16MB                        -- WAL буферы
max_connections = 100                     -- Максимум соединений
```

### Мониторинг производительности
```sql
-- Медленные запросы
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- Статистика по таблицам
SELECT 
    schemaname,
    tablename,
    n_tup_ins,
    n_tup_upd,
    n_tup_del,
    n_live_tup,
    n_dead_tup
FROM pg_stat_user_tables;
```

## Безопасность

### Настройка аутентификации
```sql
-- Создание пользователей
CREATE USER saleor WITH PASSWORD 'saleor_password';
CREATE USER replicator WITH REPLICATION PASSWORD 'replicator_password';

-- Настройка прав доступа
GRANT ALL PRIVILEGES ON DATABASE saleor TO saleor;
GRANT CONNECT ON DATABASE saleor TO replicator;
```

### Шифрование соединений
```yaml
# В patroni.yml
postgresql:
  parameters:
    ssl: on
    ssl_cert_file: '/etc/ssl/certs/server.crt'
    ssl_key_file: '/etc/ssl/private/server.key'
```

### Firewall правила
```bash
# Разрешить только HAProxy
ufw allow from 10.20.0.0/24 to any port 5432
ufw allow from 10.20.0.0/24 to any port 8008
ufw deny 5432
ufw deny 8008
```
