# Команды для проверки статуса кластера PostgreSQL

## Проверка etcd кластера

### Проверка состояния etcd узлов
```bash
# CT 109 (etcd1)
pct exec 109 -- systemctl status etcd

# CT 110 (etcd2)
pct exec 110 -- systemctl status etcd

# CT 111 (etcd3)
pct exec 111 -- systemctl status etcd
```

### Проверка членов кластера etcd
```bash
# С любого etcd узла
pct exec 109 -- etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 member list

# Или через переменные окружения
pct exec 109 -- bash -c "source /etc/etcd/etcd.conf && etcdctl member list"
```

### Проверка здоровья etcd
```bash
# Проверка здоровья кластера
pct exec 109 -- etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 endpoint health

# Проверка статуса
pct exec 109 -- etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 endpoint status
```

### Просмотр данных Patroni в etcd
```bash
# Список всех ключей Patroni
pct exec 109 -- etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 get --prefix /service/postgresql_cluster

# Текущий лидер
pct exec 109 -- etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 get /service/postgresql_cluster/leader

# Состояние всех узлов
pct exec 109 -- etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 get --prefix /service/postgresql_cluster/members
```

---

## Проверка Patroni

### Проверка статуса сервиса Patroni
```bash
# CT 102 (pg102)
pct exec 102 -- systemctl status patroni

# CT 103 (pg103)
pct exec 103 -- systemctl status patroni

# CT 104 (pg104)
pct exec 104 -- systemctl status patroni
```

### Проверка через REST API Patroni
```bash
# Статус узла pg102
curl http://192.168.50.21:8008/patroni

# Статус узла pg103
curl http://192.168.50.22:8008/patroni

# Статус узла pg104
curl http://192.168.50.23:8008/patroni

# Проверка, является ли узел Primary (только Primary вернет 200)
curl http://192.168.50.21:8008/master
curl http://192.168.50.22:8008/master
curl http://192.168.50.23:8008/master

# Проверка, является ли узел Replica (только Replica вернет 200)
curl http://192.168.50.21:8008/replica
curl http://192.168.50.22:8008/replica
curl http://192.168.50.23:8008/replica

# Health check
curl http://192.168.50.21:8008/health
curl http://192.168.50.22:8008/health
curl http://192.168.50.23:8008/health
```

### Проверка через patronictl
```bash
# С любого PostgreSQL узла
pct exec 102 -- patronictl -c /etc/patroni/patroni.yml list

# Детальная информация о кластере
pct exec 102 -- patronictl -c /etc/patroni/patroni.yml show-config

# История переключений
pct exec 102 -- patronictl -c /etc/patroni/patroni.yml history
```

### Проверка логов Patroni
```bash
# CT 102
pct exec 102 -- journalctl -u patroni -n 50 --no-pager

# CT 103
pct exec 103 -- journalctl -u patroni -n 50 --no-pager

# CT 104
pct exec 104 -- journalctl -u patroni -n 50 --no-pager

# Следить за логами в реальном времени
pct exec 102 -- journalctl -u patroni -f
```

---

## Проверка PostgreSQL

### Проверка статуса PostgreSQL (управляется Patroni)
```bash
# CT 102
pct exec 102 -- systemctl status postgresql-18

# CT 103
pct exec 103 -- systemctl status postgresql-18

# CT 104
pct exec 104 -- systemctl status postgresql-18
```

### Проверка процесса PostgreSQL
```bash
# Проверка процессов
pct exec 102 -- ps aux | grep postgres

# Проверка портов
pct exec 102 -- ss -ltnp | grep 5432
pct exec 103 -- ss -ltnp | grep 5432
pct exec 104 -- ss -ltnp | grep 5432
```

### Подключение к PostgreSQL
```bash
# Подключение к Primary (через VIP HAProxy)
psql "postgresql://sqlUser:Qwe1234!@<VIP_HAPROXY>:5432/sqluser_db"

# Подключение напрямую к узлу pg102
pct exec 102 -- psql -U postgres -d postgres

# Подключение напрямую к узлу pg103
pct exec 103 -- psql -U postgres -d postgres

# Подключение напрямую к узлу pg104
pct exec 104 -- psql -U postgres -d postgres
```

### Проверка роли узла (Primary/Replica)
```bash
# С любого узла
pct exec 102 -- psql -U postgres -c "SELECT pg_is_in_recovery();"

# Если вернуло false - это Primary
# Если вернуло true - это Replica
```

### Проверка репликации
```bash
# На Primary узле - проверка статуса репликации
pct exec 102 -- psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Проверка WAL lag
pct exec 102 -- psql -U postgres -c "SELECT pg_current_wal_lsn(), pg_last_wal_replay_lsn();"

# Проверка репликационных слотов
pct exec 102 -- psql -U postgres -c "SELECT * FROM pg_replication_slots;"
```

### Проверка подключений к БД
```bash
# Активные подключения
pct exec 102 -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Детальная информация о подключениях
pct exec 102 -- psql -U postgres -c "SELECT datname, usename, application_name, client_addr, state FROM pg_stat_activity WHERE datname IS NOT NULL;"
```

---

## Комплексная проверка кластера

### Использование готовых скриптов
```bash
# Проверка etcd и Patroni кластера
/root/view_etcd.sh

# Проверка PostgreSQL и Patroni
/root/check_postgres_patroni.sh

# Проверка HAProxy и Keepalived
/root/check_haproxy.sh
```

### Быстрая проверка всех компонентов
```bash
# etcd
echo "=== etcd ===" && pct exec 109 -- systemctl is-active etcd && pct exec 110 -- systemctl is-active etcd && pct exec 111 -- systemctl is-active etcd

# Patroni
echo "=== Patroni ===" && pct exec 102 -- systemctl is-active patroni && pct exec 103 -- systemctl is-active patroni && pct exec 104 -- systemctl is-active patroni

# PostgreSQL
echo "=== PostgreSQL ===" && pct exec 102 -- systemctl is-active postgresql-18 && pct exec 103 -- systemctl is-active postgresql-18 && pct exec 104 -- systemctl is-active postgresql-18

# HAProxy
echo "=== HAProxy ===" && pct exec 100 -- systemctl is-active haproxy && pct exec 101 -- systemctl is-active haproxy

# Keepalived
echo "=== Keepalived ===" && pct exec 100 -- systemctl is-active keepalived && pct exec 101 -- systemctl is-active keepalived
```

---

## Полезные команды для диагностики

### Проверка сетевой связности
```bash
# Проверка доступности etcd с PostgreSQL узлов
pct exec 102 -- curl -s http://192.168.50.51:2379/health
pct exec 102 -- curl -s http://192.168.50.52:2379/health
pct exec 102 -- curl -s http://192.168.50.53:2379/health

# Проверка доступности Patroni API с HAProxy узлов
pct exec 100 -- curl -s http://192.168.50.21:8008/patroni | head -20
pct exec 100 -- curl -s http://192.168.50.22:8008/patroni | head -20
pct exec 100 -- curl -s http://192.168.50.23:8008/patroni | head -20
```

### Проверка конфигурационных файлов
```bash
# Patroni конфигурация
pct exec 102 -- cat /etc/patroni/patroni.yml

# etcd конфигурация
pct exec 109 -- cat /etc/etcd/etcd.conf

# HAProxy конфигурация
pct exec 100 -- cat /etc/haproxy/haproxy.cfg
```

### Проверка ресурсов
```bash
# Использование памяти и CPU
pct exec 102 -- top -bn1 | head -20

# Использование диска
pct exec 102 -- df -h

# Размер данных PostgreSQL
pct exec 102 -- du -sh /var/lib/pgsql/18/data
```

