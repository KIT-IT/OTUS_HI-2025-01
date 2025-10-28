# HAProxy: Руководство по балансировке нагрузки и проксированию

## Что такое HAProxy и зачем он нужен

**HAProxy** (High Availability Proxy) - это высокопроизводительный балансировщик нагрузки и прокси-сервер, который обеспечивает:

- **Балансировку нагрузки** между несколькими серверами
- **Health checking** - проверку состояния серверов
- **Failover** - автоматическое переключение при сбоях
- **SSL termination** - обработку SSL/TLS соединений
- **Маршрутизацию** - направление трафика по правилам

## Архитектура HAProxy в нашем проекте

```
┌─────────────────────────────────────────────────────────────┐
│                    HAProxy Server                          │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                Frontend Rules                       │   │
│  │                                                     │   │
│  │  Port 80   → Saleor API Backend                    │   │
│  │  Port 9000 → Saleor Dashboard Backend              │   │
│  │  Port 5432 → PostgreSQL Backend                    │   │
│  │  Port 8080 → Statistics Page                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                             │                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                Backend Servers                      │   │
│  │                                                     │   │
│  │  Saleor API:    10.20.0.20:8000                    │   │
│  │  Saleor Dashboard: 10.20.0.20:9000                 │   │
│  │  PostgreSQL:    10.20.0.10:5432 (Master)          │   │
│  │  PostgreSQL:    10.20.0.11:5432 (Replica)         │   │
│  │  PostgreSQL:    10.20.0.12:5432 (Replica)         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Конфигурация HAProxy

### Основной файл конфигурации
```haproxy
# /etc/haproxy/haproxy.cfg
global
    log /dev/log    local0
    log /dev/log    local1 notice
    daemon
    maxconn 4096
    user haproxy
    group haproxy

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5s
    timeout client  50s
    timeout server  50s
    retries 3

# Статистика HAProxy
listen stats
    bind *:8080
    mode http
    stats enable
    stats uri /haproxy_stats
    stats refresh 10s
    stats auth admin:password
    stats admin if TRUE

# PostgreSQL балансировка
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

# Saleor API проксирование
frontend saleor_api
    bind *:80
    mode http
    default_backend saleor_backend

backend saleor_backend
    mode http
    balance roundrobin
    option httpchk GET /graphql/
    http-check expect status 200
    default-server inter 3s fall 3 rise 2
    server saleor-1 10.20.0.20:8000 check

# Saleor Dashboard проксирование
frontend saleor_dashboard
    bind *:9000
    mode http
    default_backend saleor_dashboard_backend

backend saleor_dashboard_backend
    mode http
    balance roundrobin
    option httpchk GET /
    http-check expect status 200
    default-server inter 3s fall 3 rise 2
    server saleor-1 10.20.0.20:9000 check
```

## Типы балансировки

### 1. Round Robin (по умолчанию)
```haproxy
backend servers
    balance roundrobin
    server web1 10.0.0.1:80 check
    server web2 10.0.0.2:80 check
    server web3 10.0.0.3:80 check
```

### 2. Least Connections
```haproxy
backend servers
    balance leastconn
    server web1 10.0.0.1:80 check
    server web2 10.0.0.2:80 check
```

### 3. Source IP Hash
```haproxy
backend servers
    balance source
    server web1 10.0.0.1:80 check
    server web2 10.0.0.2:80 check
```

### 4. URI Hash
```haproxy
backend servers
    balance uri
    server web1 10.0.0.1:80 check
    server web2 10.0.0.2:80 check
```

## Health Checks

### TCP Health Check
```haproxy
backend postgres
    option tcp-check
    tcp-check connect port 5432
    server db1 10.0.0.1:5432 check
    server db2 10.0.0.2:5432 check
```

### HTTP Health Check
```haproxy
backend web
    option httpchk GET /health
    http-check expect status 200
    server web1 10.0.0.1:80 check
    server web2 10.0.0.2:80 check
```

### Custom Health Check
```haproxy
backend custom
    option httpchk GET /api/health
    http-check expect status 200
    http-check expect string "OK"
    server app1 10.0.0.1:8080 check
```

## SSL/TLS Termination

### Базовая SSL конфигурация
```haproxy
frontend https_frontend
    bind *:443 ssl crt /etc/ssl/certs/server.pem
    default_backend web_servers

backend web_servers
    server web1 10.0.0.1:80 check
    server web2 10.0.0.2:80 check
```

### SSL с несколькими сертификатами
```haproxy
frontend https_frontend
    bind *:443 ssl crt /etc/ssl/certs/
    default_backend web_servers
```

### HTTP to HTTPS Redirect
```haproxy
frontend http_frontend
    bind *:80
    redirect scheme https code 301 if !{ ssl_fc }

frontend https_frontend
    bind *:443 ssl crt /etc/ssl/certs/server.pem
    default_backend web_servers
```

## ACL (Access Control Lists)

### Базовые ACL
```haproxy
frontend web
    bind *:80
    
    # Блокировка по IP
    acl blocked_ips src 192.168.1.100
    http-request deny if blocked_ips
    
    # Разрешение только для определенных IP
    acl allowed_ips src 10.0.0.0/8
    http-request deny unless allowed_ips
    
    # Блокировка по User-Agent
    acl bad_user_agent hdr(User-Agent) -i bot
    http-request deny if bad_user_agent
    
    default_backend web_servers
```

### Сложные ACL
```haproxy
frontend web
    bind *:80
    
    # Разные backend'ы по URL
    acl api_path path_beg /api/
    acl admin_path path_beg /admin/
    acl static_path path_beg /static/
    
    use_backend api_servers if api_path
    use_backend admin_servers if admin_path
    use_backend static_servers if static_path
    
    default_backend web_servers
```

## Мониторинг и статистика

### Включение статистики
```haproxy
listen stats
    bind *:8080
    mode http
    stats enable
    stats uri /haproxy_stats
    stats refresh 10s
    stats auth admin:password
    stats admin if TRUE
```

### Доступ к статистике
- **URL**: http://haproxy_ip:8080/haproxy_stats
- **Логин**: admin
- **Пароль**: password

### Ключевые метрики
- **Sessions**: Количество активных сессий
- **Bytes**: Переданные данные
- **Denied**: Заблокированные запросы
- **Errors**: Ошибки соединения
- **Response Time**: Время отклика

## Логирование

### Настройка логов
```bash
# В /etc/rsyslog.d/49-haproxy.conf
$ModLoad imudp
$UDPServerRun 514
$UDPServerAddress 127.0.0.1

local0.*    /var/log/haproxy.log
local1.*    /var/log/haproxy-errors.log
```

### Формат логов
```
# TCP лог
Jan 16 12:00:00 localhost haproxy[1234]: 10.0.0.1:5432 [16/Jan/2024:12:00:00.123] postgres postgres/patroni-1 0/0/0/0/0 200 0 - - ---- 1/1/0/0/0 0/0 ""

# HTTP лог
Jan 16 12:00:00 localhost haproxy[1234]: 10.0.0.1:80 [16/Jan/2024:12:00:00.123] saleor_api saleor_backend/saleor-1 0/0/0/0/0 200 0 - - ---- 1/1/0/0/0 0/0 "GET /graphql/ HTTP/1.1"
```

## Управление HAProxy

### Основные команды
```bash
# Проверка конфигурации
haproxy -c -f /etc/haproxy/haproxy.cfg

# Запуск HAProxy
systemctl start haproxy

# Остановка HAProxy
systemctl stop haproxy

# Перезапуск HAProxy
systemctl restart haproxy

# Перезагрузка конфигурации
systemctl reload haproxy

# Статус HAProxy
systemctl status haproxy
```

### Runtime управление
```bash
# Включить/выключить сервер
echo "enable server backend/server1" | socat stdio /var/run/haproxy/admin.sock
echo "disable server backend/server1" | socat stdio /var/run/haproxy/admin.sock

# Получить статистику
echo "show stat" | socat stdio /var/run/haproxy/admin.sock

# Получить информацию о сессиях
echo "show sess" | socat stdio /var/run/haproxy/admin.sock
```

## Производительность

### Оптимизация для высокой нагрузки
```haproxy
global
    maxconn 4096
    tune.ssl.default-dh-param 2048
    tune.bufsize 32768
    tune.maxrewrite 1024

defaults
    timeout connect 5s
    timeout client 50s
    timeout server 50s
    option httplog
    option dontlognull
    option redispatch
    retries 3
    maxconn 2000
```

### Настройка для PostgreSQL
```haproxy
backend postgres
    mode tcp
    option tcp-check
    tcp-check connect port 5432
    balance roundrobin
    timeout server 30s
    timeout connect 5s
    server db1 10.0.0.1:5432 check
    server db2 10.0.0.2:5432 check
```

## Безопасность

### Ограничение доступа
```haproxy
frontend web
    bind *:80
    
    # Ограничение по IP
    acl local_net src 10.0.0.0/8
    http-request deny unless local_net
    
    # Rate limiting
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src
    http-request deny if { sc_http_req_rate(0) gt 10 }
    
    default_backend web_servers
```

### Защита от DDoS
```haproxy
frontend web
    bind *:80
    
    # Ограничение соединений
    stick-table type ip size 100k expire 30s store conn_rate(10s)
    http-request track-sc0 src
    http-request deny if { sc_conn_rate(0) gt 10 }
    
    # Ограничение запросов
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc1 src
    http-request deny if { sc_http_req_rate(1) gt 20 }
    
    default_backend web_servers
```

## Устранение неполадок

### Диагностика проблем
```bash
# Проверка конфигурации
haproxy -c -f /etc/haproxy/haproxy.cfg

# Проверка статуса серверов
echo "show stat" | socat stdio /var/run/haproxy/admin.sock

# Проверка логов
tail -f /var/log/haproxy.log

# Проверка сетевых соединений
netstat -tlnp | grep haproxy
```

### Частые проблемы

1. **Сервер недоступен**
   ```bash
   # Проверить статус сервера
   echo "show stat" | socat stdio /var/run/haproxy/admin.sock | grep server_name
   
   # Проверить health check
   curl http://server_ip:port/health
   ```

2. **Проблемы с SSL**
   ```bash
   # Проверить сертификат
   openssl x509 -in /etc/ssl/certs/server.pem -text -noout
   
   # Проверить SSL соединение
   openssl s_client -connect haproxy_ip:443
   ```

3. **Высокая нагрузка**
   ```bash
   # Мониторинг соединений
   echo "show stat" | socat stdio /var/run/haproxy/admin.sock | grep -E "(sess|conn)"
   
   # Проверка логов на ошибки
   grep -i error /var/log/haproxy.log
   ```

## Мониторинг

### Prometheus метрики
```haproxy
frontend stats
    bind *:8404
    stats enable
    stats uri /metrics
    stats refresh 10s
```

### Grafana дашборд
- **HAProxy Overview**: Общая статистика
- **Backend Health**: Состояние серверов
- **Response Times**: Время отклика
- **Error Rates**: Частота ошибок

### Алерты
- **Server Down**: Сервер недоступен
- **High Error Rate**: Высокая частота ошибок
- **High Response Time**: Высокое время отклика
- **Connection Limit**: Превышение лимита соединений
