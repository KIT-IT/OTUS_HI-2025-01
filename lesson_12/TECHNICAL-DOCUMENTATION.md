# Техническая документация: Saleor E-commerce Platform с PostgreSQL HA

## Обзор архитектуры

Данная система представляет собой высокодоступную платформу электронной коммерции, построенную на микросервисной архитектуре с использованием современных технологий для обеспечения отказоустойчивости и масштабируемости.

## Компоненты системы

### 1. PostgreSQL + Patroni кластер

#### Назначение
PostgreSQL служит основной базой данных для хранения всей информации о товарах, заказах, пользователях и конфигурации системы Saleor.

#### Patroni - что это и зачем нужен
**Patroni** - это система управления PostgreSQL кластером, которая обеспечивает:
- **Автоматический failover** при отказе master узла
- **Автоматическое восстановление** после сбоев
- **Координацию** между узлами кластера
- **Мониторинг** состояния узлов

#### Принцип работы Patroni
1. **Leader Election**: Patroni использует etcd для выбора лидера кластера
2. **Health Checks**: Постоянно проверяет состояние PostgreSQL на каждом узле
3. **Failover**: При обнаружении проблем с master автоматически переключает на replica
4. **Replication**: Настраивает streaming replication между master и replica узлами

#### Конфигурация кластера
```yaml
# /etc/patroni/patroni.yml
scope: saleor-cluster
name: patroni-1
restapi:
  listen: 0.0.0.0:8008
  connect_address: 10.20.0.X:8008
etcd3:
  host: 10.20.0.X:2379
postgresql:
  listen: 0.0.0.0:5432
  connect_address: 10.20.0.X:5432
  data_dir: /var/lib/postgresql/15/main
  pg_hba.conf:
    - host all all 0.0.0.0/0 md5
    - host all all 10.20.0.0/24 md5
```

### 2. etcd - Distributed Configuration Store

#### Назначение
etcd используется как распределенное хранилище конфигурации для:
- Хранения метаданных кластера Patroni
- Координации выборов лидера
- Синхронизации состояния между узлами

#### Принцип работы
- **Raft Consensus Algorithm**: Обеспечивает консистентность данных
- **Key-Value Store**: Хранит конфигурацию в формате ключ-значение
- **Watch API**: Уведомляет о изменениях в реальном времени

### 3. HAProxy - Load Balancer и Proxy

#### Назначение
HAProxy выполняет несколько критически важных функций:

1. **Балансировка PostgreSQL трафика**:
   - Маршрутизирует запросы только к активному master узлу
   - Проверяет здоровье узлов через health checks
   - Автоматически исключает неработающие узлы

2. **Проксирование Saleor сервисов**:
   - API запросы на порт 80 → Saleor API (порт 8000)
   - Dashboard запросы на порт 9000 → Saleor Dashboard (порт 9000)

#### Конфигурация HAProxy

```haproxy
# PostgreSQL балансировка
frontend postgres
  bind *:5432
  default_backend patroni_pg

backend patroni_pg
  option tcp-check
  tcp-check connect port 5432
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
  server saleor-1 10.20.0.20:9000 check
```

### 4. Saleor - E-commerce Platform

#### Архитектура Saleor
Saleor построен на Django + GraphQL и состоит из:

1. **API (Backend)**:
   - GraphQL API для всех операций
   - Django ORM для работы с БД
   - Celery для фоновых задач
   - Redis для кэширования

2. **Dashboard (Admin Panel)**:
   - React приложение для управления
   - Администрирование товаров, заказов, пользователей
   - Аналитика и отчеты

#### Конфигурация подключения к БД
```python
# DATABASE_URL для Saleor
DATABASE_URL = "postgresql://saleor:saleor_password@haproxy_ip:5432/saleor"
```

### 5. Storefront - Клиентский интерфейс

#### Технологии
- **Next.js** - React фреймворк для SSR
- **Apollo Client** - GraphQL клиент
- **TypeScript** - Типизированный JavaScript

#### Конфигурация
```javascript
// .env.local
NEXT_PUBLIC_SALEOR_API_URL=http://haproxy_ip/graphql/
NEXT_PUBLIC_SALEOR_DASHBOARD_URL=http://haproxy_ip:9000/
NEXT_PUBLIC_DEFAULT_COUNTRY=US
NEXT_PUBLIC_DEFAULT_CURRENCY=USD
```

## Схема взаимодействия компонентов

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Storefront    │    │   Saleor API    │    │  Saleor Admin   │
│   (Next.js)     │    │   (Django)      │    │   (React)       │
│   Port: 3000    │    │   Port: 8000    │    │   Port: 9000    │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │        HAProxy            │
                    │   (Load Balancer)         │
                    │   Ports: 80, 9000, 5432   │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │    PostgreSQL Cluster     │
                    │        (Patroni)          │
                    │                           │
                    │  ┌─────────┐ ┌─────────┐  │
                    │  │ Master  │ │Replica 1│  │
                    │  │ Node 1  │ │ Node 2  │  │
                    │  └─────────┘ └─────────┘  │
                    │                           │
                    │  ┌─────────┐              │
                    │  │Replica 2│              │
                    │  │ Node 3  │              │
                    │  └─────────┘              │
                    └───────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │         etcd              │
                    │  (Coordination Store)     │
                    │    Port: 2379             │
                    └───────────────────────────┘
```

## Потоки данных

### 1. Клиентский запрос к Storefront
```
Browser → Storefront (3000) → GraphQL Query → HAProxy (80) → Saleor API (8000) → HAProxy (5432) → PostgreSQL Master
```

### 2. Административный запрос к Dashboard
```
Browser → HAProxy (9000) → Saleor Dashboard (9000) → GraphQL Query → Saleor API (8000) → HAProxy (5432) → PostgreSQL Master
```

### 3. Прямое подключение к БД
```
Application → HAProxy (5432) → PostgreSQL Master (5432)
```

## Отказоустойчивость

### 1. PostgreSQL Failover
1. **Обнаружение сбоя**: Patroni мониторит master узел
2. **Выбор нового лидера**: etcd координирует выбор
3. **Переключение**: HAProxy автоматически направляет трафик на новый master
4. **Время восстановления**: ~30-60 секунд

### 2. HAProxy Health Checks
- **PostgreSQL**: TCP проверка на порт 5432
- **Saleor API**: HTTP GET /graphql/ (ожидает 200 OK)
- **Saleor Dashboard**: HTTP GET / (ожидает 200 OK)

### 3. Мониторинг
- **HAProxy Stats**: http://haproxy_ip:8080/haproxy_stats
- **Patroni Status**: `patronictl list` на любом узле
- **PostgreSQL**: Логи в `/var/log/postgresql/`

## Масштабирование

### Горизонтальное масштабирование
1. **PostgreSQL**: Добавление replica узлов
2. **Saleor**: Добавление API узлов с балансировкой
3. **Storefront**: Добавление frontend узлов

### Вертикальное масштабирование
1. **Увеличение ресурсов ВМ** (CPU, RAM, Disk)
2. **Оптимизация PostgreSQL** (shared_buffers, work_mem)
3. **Кэширование** (Redis, Memcached)

## Безопасность

### Сетевая безопасность
- **Security Groups**: Ограничение доступа по портам и IP
- **Private Subnet**: ВМ в изолированной сети
- **NAT Gateway**: Только исходящий интернет трафик

### Аутентификация
- **SSH**: Доступ только по ключам
- **PostgreSQL**: Пароли и pg_hba.conf
- **Saleor**: JWT токены и Django сессии

### Шифрование
- **TLS/SSL**: Для HTTPS трафика (рекомендуется)
- **Database**: Шифрование соединений (рекомендуется)

## Резервное копирование

### Стратегия бэкапов
1. **PostgreSQL**: Ежедневные pg_dump
2. **Конфигурация**: Git репозиторий с Ansible
3. **Медиа файлы**: Отдельное хранилище

### Восстановление
1. **Point-in-time recovery**: WAL архивы
2. **Disaster recovery**: Полное восстановление из бэкапа
3. **Blue-green deployment**: Переключение на резервную среду

## Производительность

### Оптимизация PostgreSQL
- **Индексы**: На часто используемых полях
- **VACUUM**: Автоматическая очистка
- **Connection pooling**: PgBouncer (рекомендуется)

### Оптимизация Saleor
- **Redis кэш**: Для часто запрашиваемых данных
- **CDN**: Для статических файлов
- **Database queries**: Оптимизация GraphQL запросов

### Мониторинг производительности
- **PostgreSQL**: pg_stat_statements, slow query log
- **HAProxy**: Статистика соединений и времени отклика
- **System**: CPU, RAM, Disk I/O мониторинг
