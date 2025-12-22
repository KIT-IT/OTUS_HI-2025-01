# HAProxy с Keepalived для PostgreSQL и Docker Swarm

## Обзор

Настройка HAProxy с Keepalived обеспечивает высокую доступность балансировщика нагрузки для:
- **PostgreSQL кластера** (порт 5432)
- **Docker Swarm Manager** (порт 2377)

## Архитектура

```
                    ┌─────────────────────────┐
                    │   Виртуальный IP (VIP)  │
                    │   192.168.50.10         │
                    └───────────┬─────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
            ┌───────▼────────┐    ┌─────────▼────────┐
            │   HAProxy 1     │    │   HAProxy 2      │
            │ 192.168.50.11  │    │ 192.168.50.12    │
            │    CT 100      │    │    CT 101        │
            │  MASTER (100)  │    │  BACKUP (90)     │
            │  Keepalived    │    │  Keepalived      │
            └───────┬────────┘    └─────────┬────────┘
                    │                       │
        ┌───────────┴───────────┐  ┌────────┴──────────┐
        │                       │  │                   │
        ▼                       ▼  ▼                   ▼
  PostgreSQL              Docker Swarm Manager
  (5432)                  (2377)
```

## Компоненты

### HAProxy

**Узлы:**
- CT 100 (haproxy1): 192.168.50.11 - MASTER
- CT 101 (haproxy2): 192.168.50.12 - BACKUP

**Порты:**
- 5432 - PostgreSQL балансировка
- 2377 - Docker Swarm Manager балансировка
- 8404 - Статистика HAProxy

### Keepalived

**Назначение:** Обеспечивает высокую доступность HAProxy через виртуальный IP (VIP)

**Виртуальный IP:** 192.168.50.10

**Приоритеты:**
- CT 100: priority 100 (MASTER)
- CT 101: priority 90 (BACKUP)

**Механизм работы:**
1. Keepalived проверяет здоровье HAProxy через скрипт `check_haproxy.sh`
2. Если HAProxy на MASTER узле падает, VIP автоматически переключается на BACKUP
3. При восстановлении MASTER, VIP может вернуться обратно (в зависимости от приоритета)

## Конфигурация

### HAProxy

#### Балансировка PostgreSQL

```haproxy
frontend postgresql_frontend
    bind *:5432
    default_backend postgresql_backend

backend postgresql_backend
    balance roundrobin
    option httpchk GET /patroni
    http-check expect status 200
    server pg102 192.168.50.21:5432 check port 8008 inter 3s fall 3 rise 3
    server pg103 192.168.50.22:5432 check port 8008 inter 3s fall 3 rise 3
    server pg104 192.168.50.23:5432 check port 8008 inter 3s fall 3 rise 3
```

#### Балансировка Docker Swarm Manager

```haproxy
frontend docker_swarm_frontend
    bind *:2377
    default_backend docker_swarm_backend

backend docker_swarm_backend
    balance roundrobin
    mode tcp
    option tcplog
    server docker_mgr1 192.168.50.31:2377 check inter 3s fall 3 rise 3
    server docker_mgr2 192.168.50.32:2377 check inter 3s fall 3 rise 3
```

### Keepalived

#### Конфигурация (`/etc/keepalived/keepalived.conf`)

```conf
global_defs {
    router_id LVS_DEVEL
    script_user root
    enable_script_security
}

vrrp_script check_haproxy {
    script "/usr/local/bin/check_haproxy.sh"
    interval 2
    fall 2
    rise 2
    timeout 2
    weight -2
}

vrrp_instance VI_1 {
    state MASTER  # или BACKUP
    interface eth0
    virtual_router_id 50
    priority 100  # или 90 для BACKUP
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass KeepAlive123!
    }
    virtual_ipaddress {
        192.168.50.10/24
    }
    track_script {
        check_haproxy
    }
    notify_master "/usr/local/bin/keepalived_notify.sh master"
    notify_backup "/usr/local/bin/keepalived_notify.sh backup"
    notify_fault "/usr/local/bin/keepalived_notify.sh fault"
}
```

#### Скрипт проверки здоровья HAProxy

```bash
#!/bin/bash
# Скрипт проверки здоровья HAProxy для Keepalived

# Проверка процесса HAProxy
if ! systemctl is-active --quiet haproxy; then
    exit 1
fi

# Проверка порта статистики HAProxy
if ! ss -tlnp | grep -q ":8404"; then
    exit 1
fi

# Проверка порта PostgreSQL (если настроен)
if ! ss -tlnp | grep -q ":5432"; then
    exit 1
fi

exit 0
```

## Установка

### Через Ansible Playbook

```bash
cd /root/ansible-postgresql
ansible-playbook -i inventory/hosts.yml playbook.yml --limit haproxy
```

### Ручная установка

#### 1. Установка HAProxy

```bash
# На CT 100 и CT 101
pct exec 100 -- dnf install -y haproxy
pct exec 101 -- dnf install -y haproxy
```

#### 2. Установка Keepalived

```bash
# На CT 100 и CT 101
pct exec 100 -- dnf install -y keepalived
pct exec 101 -- dnf install -y keepalived
```

#### 3. Настройка конфигурации

Скопируйте конфигурационные файлы из ролей Ansible или создайте вручную.

## Управление

### Проверка статуса HAProxy

```bash
# Статус сервиса
pct exec 100 -- systemctl status haproxy
pct exec 101 -- systemctl status haproxy

# Статистика
curl http://192.168.50.11:8404/stats
curl http://192.168.50.12:8404/stats
# Или через VIP
curl http://192.168.50.10:8404/stats
```

### Проверка статуса Keepalived

```bash
# Статус сервиса
pct exec 100 -- systemctl status keepalived
pct exec 101 -- systemctl status keepalived

# Проверка VIP
ip addr show | grep 192.168.50.10
# На MASTER узле должен быть VIP

# Логи
pct exec 100 -- journalctl -u keepalived -f
pct exec 101 -- journalctl -u keepalived -f
```

### Перезапуск сервисов

```bash
# HAProxy
pct exec 100 -- systemctl restart haproxy
pct exec 101 -- systemctl restart haproxy

# Keepalived
pct exec 100 -- systemctl restart keepalived
pct exec 101 -- systemctl restart keepalived
```

## Тестирование

### Тестирование балансировки PostgreSQL

```bash
# Подключение через VIP
psql -h 192.168.50.10 -U postgres -d postgres

# Проверка распределения нагрузки
for i in {1..10}; do
  psql -h 192.168.50.10 -U postgres -d postgres -c "SELECT inet_server_addr();"
done
```

### Тестирование балансировки Docker Swarm

```bash
# Подключение к Docker Swarm через VIP
docker -H tcp://192.168.50.10:2377 info

# Проверка узлов Swarm
docker -H tcp://192.168.50.10:2377 node ls
```

### Тестирование failover Keepalived

1. **Проверьте текущий MASTER:**
```bash
# На CT 100
pct exec 100 -- ip addr show | grep 192.168.50.10
# Если VIP есть - это MASTER

# На CT 101
pct exec 101 -- ip addr show | grep 192.168.50.10
# Если VIP нет - это BACKUP
```

2. **Остановите HAProxy на MASTER:**
```bash
pct exec 100 -- systemctl stop haproxy
```

3. **Подождите 5-10 секунд** и проверьте VIP:
```bash
# VIP должен переключиться на CT 101
pct exec 101 -- ip addr show | grep 192.168.50.10
```

4. **Восстановите HAProxy:**
```bash
pct exec 100 -- systemctl start haproxy
```

5. **Проверьте, вернулся ли VIP на MASTER** (зависит от приоритета)

## Мониторинг

### Ключевые метрики

1. **HAProxy:**
   - Статус серверов (UP/DOWN)
   - Количество активных подключений
   - Распределение нагрузки

2. **Keepalived:**
   - Состояние узла (MASTER/BACKUP/FAULT)
   - Наличие VIP
   - Результаты health checks

### Логи

```bash
# HAProxy логи
pct exec 100 -- journalctl -u haproxy -f

# Keepalived логи
pct exec 100 -- journalctl -u keepalived -f
pct exec 100 -- tail -f /var/log/keepalived.log
```

## Troubleshooting

### Проблема: VIP не переключается

**Причины:**
- Keepalived не запущен
- Скрипт проверки здоровья возвращает ошибку
- Проблемы с сетью между узлами

**Решение:**
1. Проверьте статус Keepalived: `systemctl status keepalived`
2. Проверьте логи: `journalctl -u keepalived -n 50`
3. Проверьте скрипт проверки здоровья: `/usr/local/bin/check_haproxy.sh`
4. Проверьте сетевую связность между узлами

### Проблема: HAProxy не балансирует

**Причины:**
- Неправильная конфигурация
- Серверы недоступны
- Проблемы с health checks

**Решение:**
1. Проверьте конфигурацию: `haproxy -f /etc/haproxy/haproxy.cfg -c`
2. Проверьте статистику: `curl http://192.168.50.10:8404/stats`
3. Проверьте доступность серверов: `ping`, `telnet`

### Проблема: Docker Swarm не подключается через VIP

**Причины:**
- Порт 2377 не открыт
- Docker Swarm Manager не настроен для прослушивания на всех интерфейсах
- Проблемы с балансировкой

**Решение:**
1. Проверьте, что Docker Swarm слушает на 0.0.0.0:2377
2. Проверьте firewall правила
3. Проверьте конфигурацию HAProxy для Docker Swarm

## Переменные Ansible

### group_vars/haproxy.yml

```yaml
haproxy_listen_port: 5432
haproxy_stats_port: 8404
haproxy_stats_user: "admin"
haproxy_stats_password: "admin123"
docker_swarm_port: 2377

keepalived_virtual_ip: "192.168.50.10"
keepalived_interface: "eth0"
keepalived_virtual_router_id: 50
keepalived_authentication_password: "KeepAlive123!"
keepalived_health_check_script: "/usr/local/bin/check_haproxy.sh"
keepalived_health_check_interval: 2
keepalived_health_check_fallback: 2
keepalived_health_check_rise: 2
```

### inventory/hosts.yml

```yaml
haproxy:
  hosts:
    haproxy1:
      ct_id: 100
      ct_ip: 192.168.50.11
      keepalived_priority: 100
      keepalived_state: MASTER
    haproxy2:
      ct_id: 101
      ct_ip: 192.168.50.12
      keepalived_priority: 90
      keepalived_state: BACKUP
docker_swarm:
  hosts:
    docker_mgr1:
      ct_id: 105
      ct_ip: 192.168.50.31
    docker_mgr2:
      ct_id: 106
      ct_ip: 192.168.50.32
```

## Безопасность

### Рекомендации

1. **Пароли:** Используйте сильные пароли для Keepalived authentication
2. **Сеть:** Ограничьте доступ к VIP только необходимым IP
3. **Firewall:** Настройте правила firewall для портов HAProxy
4. **SSL/TLS:** Для Docker Swarm рекомендуется использовать TLS

### Текущие настройки безопасности

- **HAProxy статистика:** Защищена паролем (admin/admin123)
- **Keepalived:** Аутентификация через пароль (KeepAlive123!)
- **VIP:** Доступен в подсети 192.168.50.0/24

---

*Документация обновлена: 2025-12-17*


