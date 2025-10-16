# Архитектурная диаграмма системы

## Общая схема

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Yandex Cloud VPC                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                        Public Subnet (10.20.0.0/24)                    │   │
│  │                                                                         │   │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │   │
│  │  │   HAProxy   │    │   Saleor    │    │ Storefront  │                 │   │
│  │  │   (LB)      │    │   (API)     │    │ (Frontend)  │                 │   │
│  │  │ 89.169.134  │    │ 89.169.133  │    │ 62.84.112   │                 │   │
│  │  │    .241     │    │    .249     │    │    .133     │                 │   │
│  │  └─────────────┘    └─────────────┘    └─────────────┘                 │   │
│  │         │                   │                   │                      │   │
│  │         │                   │                   │                      │   │
│  │         └───────────────────┼───────────────────┘                      │   │
│  │                             │                                          │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│  │  │                    Private Subnet (10.20.0.0/24)               │   │   │
│  │  │                                                                 │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │   │
│  │  │  │   Patroni   │  │   Patroni   │  │   Patroni   │             │   │   │
│  │  │  │   Node 1    │  │   Node 2    │  │   Node 3    │             │   │   │
│  │  │  │  (Master)   │  │ (Replica)   │  │ (Replica)   │             │   │   │
│  │  │  │ 89.169.149  │  │ 62.84.126   │  │ 89.169.135  │             │   │   │
│  │  │  │    .16      │  │    .202     │  │    .103     │             │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘             │   │   │
│  │  │         │                 │                 │                   │   │   │
│  │  │         └─────────────────┼─────────────────┘                   │   │   │
│  │  │                           │                                     │   │   │
│  │  │  ┌─────────────────────────┴─────────────────────────┐         │   │   │
│  │  │  │                  etcd Cluster                    │         │   │   │
│  │  │  │            (Coordination Store)                  │         │   │   │
│  │  │  │              Port: 2379                          │         │   │   │
│  │  │  └─────────────────────────────────────────────────┘         │   │   │
│  │  └─────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Детальная схема взаимодействия

```
                    ┌─────────────────────────────────────────────────┐
                    │                Internet                         │
                    └─────────────┬───────────────────────────────────┘
                                  │
                    ┌─────────────┴───────────────────────────────────┐
                    │            Yandex Cloud                         │
                    │                                                 │
                    │  ┌─────────────────────────────────────────┐   │
                    │  │         Security Groups                 │   │
                    │  │  • SSH (22)                            │   │
                    │  │  • HTTP (80)                           │   │
                    │  │  • HTTPS (443)                         │   │
                    │  │  • PostgreSQL (5432)                   │   │
                    │  │  • Saleor API (8000)                   │   │
                    │  │  • Saleor Dashboard (9000)             │   │
                    │  │  • Storefront (3000)                   │   │
                    │  │  • HAProxy Stats (8080)                │   │
                    │  └─────────────────────────────────────────┘   │
                    │                                                 │
                    │  ┌─────────────────────────────────────────┐   │
                    │  │              HAProxy                    │   │
                    │  │         (Load Balancer)                 │   │
                    │  │                                         │   │
                    │  │  Frontend: 80    → Backend: 8000       │   │
                    │  │  Frontend: 9000  → Backend: 9000       │   │
                    │  │  Frontend: 5432  → Backend: 5432       │   │
                    │  │  Stats: 8080                           │   │
                    │  └─────────────────────────────────────────┘   │
                    │                         │                     │
                    │  ┌─────────────────────┼─────────────────────┐ │
                    │  │                     │                     │ │
                    │  │  ┌─────────────┐    │    ┌─────────────┐  │ │
                    │  │  │   Saleor    │    │    │ Storefront  │  │ │
                    │  │  │   Stack     │    │    │   (Next.js) │  │ │
                    │  │  │             │    │    │             │  │ │
                    │  │  │ ┌─────────┐ │    │    │ ┌─────────┐ │  │ │
                    │  │  │ │   API   │ │    │    │ │ Frontend│ │  │ │
                    │  │  │ │(Django) │ │    │    │ │ (React) │ │  │ │
                    │  │  │ └─────────┘ │    │    │ └─────────┘ │  │ │
                    │  │  │ ┌─────────┐ │    │    │             │  │ │
                    │  │  │ │Dashboard│ │    │    │             │  │ │
                    │  │  │ │(React)  │ │    │    │             │  │ │
                    │  │  │ └─────────┘ │    │    │             │  │ │
                    │  │  │ ┌─────────┐ │    │    │             │  │ │
                    │  │  │ │  Redis  │ │    │    │             │  │ │
                    │  │  │ │ (Cache) │ │    │    │             │  │ │
                    │  │  │ └─────────┘ │    │    │             │  │ │
                    │  │  └─────────────┘    │    └─────────────┘  │ │
                    │  └─────────────────────┼─────────────────────┘ │
                    │                         │                     │
                    │  ┌─────────────────────┼─────────────────────┐ │
                    │  │                     │                     │ │
                    │  │  ┌─────────────┐    │    ┌─────────────┐  │ │
                    │  │  │ PostgreSQL  │    │    │ PostgreSQL  │  │ │
                    │  │  │   Master    │◄───┼───►│  Replica 1  │  │ │
                    │  │  │  (Patroni)  │    │    │  (Patroni)  │  │ │
                    │  │  └─────────────┘    │    └─────────────┘  │ │
                    │  │         │           │           │         │ │
                    │  │         │           │           │         │ │
                    │  │         └───────────┼───────────┘         │ │
                    │  │                     │                     │ │
                    │  │  ┌─────────────┐    │                     │ │
                    │  │  │ PostgreSQL  │    │                     │ │
                    │  │  │  Replica 2  │    │                     │ │
                    │  │  │  (Patroni)  │    │                     │ │
                    │  │  └─────────────┘    │                     │ │
                    │  └─────────────────────┼─────────────────────┘ │
                    │                         │                     │
                    │  ┌─────────────────────┼─────────────────────┐ │
                    │  │                     │                     │ │
                    │  │  ┌─────────────┐    │                     │ │
                    │  │  │    etcd     │◄───┼─────────────────────┘ │
                    │  │  │ (Coordination)   │                     │ │
                    │  │  │   Store          │                     │ │
                    │  │  └─────────────┘    │                     │ │
                    │  └─────────────────────┼─────────────────────┘ │
                    └─────────────────────────┼─────────────────────┘
                                              │
                    ┌─────────────────────────┴─────────────────────┐
                    │              External Services                │
                    │  • Yandex Cloud API                          │
                    │  • Terraform State                           │
                    │  • Ansible Inventory                         │
                    └─────────────────────────────────────────────┘
```

## Потоки данных

### 1. Клиентский запрос
```
User Browser
    ↓ HTTP/HTTPS
Internet
    ↓ Port 80/443
HAProxy (Load Balancer)
    ↓ Port 80 → 8000
Saleor API (Django + GraphQL)
    ↓ Port 5432
HAProxy (PostgreSQL Proxy)
    ↓ Port 5432
PostgreSQL Master (Patroni)
    ↓ Streaming Replication
PostgreSQL Replicas (Patroni)
```

### 2. Административный запрос
```
Admin Browser
    ↓ HTTP/HTTPS
Internet
    ↓ Port 9000
HAProxy (Load Balancer)
    ↓ Port 9000
Saleor Dashboard (React)
    ↓ GraphQL Query
Saleor API (Django + GraphQL)
    ↓ Port 5432
HAProxy (PostgreSQL Proxy)
    ↓ Port 5432
PostgreSQL Master (Patroni)
```

### 3. Прямое подключение к БД
```
Database Client
    ↓ PostgreSQL Protocol
Internet
    ↓ Port 5432
HAProxy (PostgreSQL Proxy)
    ↓ Health Check + Load Balance
PostgreSQL Master (Patroni)
    ↓ Automatic Failover
PostgreSQL Replica (Patroni) [if master fails]
```

## Компоненты и их роли

| Компонент | Роль | Порт | Протокол | Назначение |
|-----------|------|------|----------|------------|
| **HAProxy** | Load Balancer | 80, 9000, 5432, 8080 | HTTP, TCP | Маршрутизация и балансировка |
| **Saleor API** | Backend Service | 8000 | HTTP | GraphQL API для e-commerce |
| **Saleor Dashboard** | Admin Interface | 9000 | HTTP | Административная панель |
| **Storefront** | Frontend | 3000 | HTTP | Клиентский интерфейс магазина |
| **PostgreSQL Master** | Primary Database | 5432 | TCP | Основная база данных |
| **PostgreSQL Replicas** | Read Replicas | 5432 | TCP | Реплики для чтения |
| **etcd** | Coordination Store | 2379 | HTTP | Координация кластера Patroni |
| **Redis** | Cache Store | 6379 | TCP | Кэширование данных |

## Отказоустойчивость

### Уровни отказоустойчивости

1. **Application Level**
   - Saleor API: Автоматический restart при сбоях
   - Storefront: PM2 process manager
   - Redis: Persistence + replication

2. **Load Balancer Level**
   - HAProxy: Health checks + automatic failover
   - Multiple backend servers support

3. **Database Level**
   - Patroni: Automatic master election
   - Streaming replication: Real-time data sync
   - etcd: Cluster coordination

4. **Infrastructure Level**
   - Multiple availability zones
   - Auto-scaling groups
   - Backup and recovery procedures

### Время восстановления (RTO)

- **PostgreSQL Failover**: 30-60 секунд
- **Application Restart**: 10-30 секунд
- **Load Balancer Switch**: 5-10 секунд
- **Full System Recovery**: 5-15 минут

## Мониторинг и наблюдаемость

### Метрики системы
- **HAProxy**: Connections, response time, error rate
- **PostgreSQL**: Query performance, replication lag, connections
- **Saleor**: Request rate, response time, error rate
- **System**: CPU, memory, disk I/O, network

### Логирование
- **Application Logs**: Saleor, Storefront
- **Database Logs**: PostgreSQL, Patroni
- **System Logs**: HAProxy, systemd
- **Access Logs**: HTTP requests, database connections

### Алерты
- **Database**: Master down, replication lag
- **Application**: High error rate, slow responses
- **Infrastructure**: High CPU/memory usage, disk space
- **Network**: Connection failures, timeouts
