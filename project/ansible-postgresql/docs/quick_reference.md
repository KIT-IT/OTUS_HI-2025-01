# Краткий справочник команд

## Быстрый доступ

### Скрипты мониторинга

```bash
# Просмотр информации etcd
/root/view_etcd.sh --full

# Проверка PostgreSQL и Patroni
/root/check_postgres_patroni.sh --full
```

---

## etcd

### Проверка здоровья

```bash
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 endpoint health
```

### Просмотр данных

```bash
# Все ключи
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 get --prefix / --keys-only

# Данные Patroni
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 get --prefix /patroni/

# Лидер кластера
pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 get /patroni/postgres/leader
```

### Управление

```bash
# Перезапуск
pct exec 109 -- systemctl restart etcd

# Статус
pct exec 109 -- systemctl status etcd
```

---

## Patroni

### Проверка статуса

```bash
# Статус узла
curl http://192.168.50.22:8008/patroni | python3 -m json.tool

# История кластера
curl http://192.168.50.22:8008/history | python3 -m json.tool

# Здоровье
curl http://192.168.50.22:8008/health
```

### Управление

```bash
# Перезапуск Patroni
pct exec 103 -- systemctl restart patroni

# Переключение лидера (failover)
curl -X POST http://192.168.50.22:8008/failover

# Перезагрузка конфигурации PostgreSQL
curl -X POST http://192.168.50.22:8008/reload

# Перезапуск PostgreSQL
curl -X POST http://192.168.50.22:8008/restart
```

### Логи

```bash
# Просмотр логов
pct exec 103 -- journalctl -u patroni -f

# Последние 50 строк
pct exec 103 -- journalctl -u patroni -n 50
```

---

## PostgreSQL

### Подключение

```bash
# К master через HAProxy
psql -h 192.168.50.11 -U postgres -d postgres

# Напрямую к узлу
psql -h 192.168.50.22 -U postgres -d postgres
```

### Проверка репликации

```bash
# На master - активные реплики
pct exec 103 -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres -c "SELECT * FROM pg_stat_replication;"

# На replica - режим репликации
pct exec 102 -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres -c "SELECT pg_is_in_recovery();"

# Слоты репликации
pct exec 103 -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres -c "SELECT * FROM pg_replication_slots;"
```

### Резервное копирование

```bash
# pg_dump
pct exec 103 -- sudo -u postgres /usr/pgsql-18/bin/pg_dump -h localhost -U postgres -d postgres > backup.sql

# pg_basebackup
pct exec 103 -- sudo -u postgres /usr/pgsql-18/bin/pg_basebackup -h 192.168.50.22 -U replicator -D /backup/postgres -Ft -z -P
```

---

## HAProxy

### Статистика

```bash
# Веб-интерфейс статистики
curl http://192.168.50.11:8404/stats

# Или в браузере
# http://192.168.50.11:8404/stats
# Логин: admin, Пароль: admin
```

### Управление

```bash
# Перезапуск
pct exec 100 -- systemctl restart haproxy

# Статус
pct exec 100 -- systemctl status haproxy
```

---

## Полезные команды для всех узлов

### PostgreSQL + Patroni

```bash
# Перезапуск всех узлов Patroni
for ct in 102 103 104; do
  pct exec $ct -- systemctl restart patroni
done

# Проверка статуса на всех узлах
for ct in 102 103 104; do
  ip=$(pct config $ct | grep "ip=" | awk -F'ip=' '{print $2}' | awk -F',' '{print $1}' | awk -F'/' '{print $1}')
  echo "CT $ct ($ip):"
  curl -s http://$ip:8008/patroni | python3 -m json.tool | grep -E "role|state" | head -2
done
```

### etcd

```bash
# Перезапуск всех узлов etcd
for ct in 109 110 111; do
  pct exec $ct -- systemctl restart etcd
done

# Проверка статуса на всех узлах
for ct in 109 110 111; do
  echo "CT $ct:"
  pct exec $ct -- systemctl status etcd --no-pager | head -3
done
```

---

## Алиасы (добавить в ~/.bashrc)

```bash
alias view-etcd='/root/view_etcd.sh'
alias check-pg='/root/check_postgres_patroni.sh'
alias etcd-health='pct exec 109 -- /usr/local/bin/etcdctl --endpoints=http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379 endpoint health'
alias patroni-status='curl -s http://192.168.50.22:8008/patroni | python3 -m json.tool'
```

---

*Обновлено: 2025-12-17*


