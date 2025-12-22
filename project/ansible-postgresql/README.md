# Ansible Playbook для PostgreSQL HA Cluster

Автоматизация развертывания PostgreSQL High Availability кластера с использованием Patroni, etcd и HAProxy.

## Компоненты

- **PostgreSQL 18** - база данных с поддержкой streaming replication
- **Patroni** - система управления HA для PostgreSQL
- **etcd** - распределенное хранилище для координации (3 узла)
- **HAProxy** - балансировщик нагрузки (2 узла)

## Архитектура

```
Клиенты → HAProxy → PostgreSQL (Patroni) ↔ etcd
```

- **PostgreSQL узлы:** CT 102, 103, 104 (1 master + 2 replicas)
- **etcd узлы:** CT 109, 110, 111 (кластер из 3 узлов)
- **HAProxy узлы:** CT 100, 101 (балансировка)

Подробная документация: [docs/patroni_etcd_postgresql_setup.md](docs/patroni_etcd_postgresql_setup.md)

## Быстрый старт

### Предварительные требования

1. Proxmox LXC контейнеры настроены
2. Пользователь `sedunovsv` с правами sudo без пароля
3. Сеть: все контейнеры в подсети 192.168.50.0/24

### Установка

```bash
cd /root/ansible-postgresql
ansible-playbook -i inventory/hosts.yml playbook.yml
```

### Проверка

```bash
# Проверка etcd
/root/view_etcd.sh --full

# Проверка PostgreSQL и Patroni
/root/check_postgres_patroni.sh --full
```

## Документация

- **[Полная документация](docs/patroni_etcd_postgresql_setup.md)** - Подробное описание архитектуры, настройки и управления
- **[Схема кластера](docs/cluster_architecture.txt)** - ASCII схема архитектуры
- **[Краткий справочник](docs/quick_reference.md)** - Быстрые команды для управления

## Структура проекта

```
ansible-postgresql/
├── docs/                          # Документация
│   ├── patroni_etcd_postgresql_setup.md
│   ├── cluster_architecture.txt
│   └── quick_reference.md
├── inventory/
│   └── hosts.yml                  # Инвентарь хостов
├── group_vars/
│   └── etcd.yml                   # Переменные для etcd
├── roles/
│   ├── etcd/                      # Роль установки etcd
│   ├── postgresql18/              # Роль установки PostgreSQL
│   ├── patroni/                   # Роль установки Patroni
│   └── haproxy/                   # Роль установки HAProxy
└── playbook.yml                   # Главный playbook
```

## Инвентарь

### PostgreSQL + Patroni
- CT 102 (pg102): 192.168.50.21
- CT 103 (pg103): 192.168.50.22
- CT 104 (pg104): 192.168.50.23

### etcd
- CT 109 (etcd1): 192.168.50.51
- CT 110 (etcd2): 192.168.50.52
- CT 111 (etcd3): 192.168.50.53

### HAProxy
- CT 100 (haproxy1): 192.168.50.11
- CT 101 (haproxy2): 192.168.50.12

## Управление

### Запуск playbook

```bash
# Полная установка
ansible-playbook -i inventory/hosts.yml playbook.yml

# Только etcd
ansible-playbook -i inventory/hosts.yml playbook.yml --limit etcd

# Только PostgreSQL + Patroni
ansible-playbook -i inventory/hosts.yml playbook.yml --limit postgresql

# Только HAProxy
ansible-playbook -i inventory/hosts.yml playbook.yml --limit haproxy
```

### Мониторинг

```bash
# Просмотр информации etcd
/root/view_etcd.sh

# Проверка PostgreSQL и Patroni
/root/check_postgres_patroni.sh
```

## Версии компонентов

- PostgreSQL: 18.1
- Patroni: 3.3.0
- etcd: 3.5.13
- HAProxy: последняя стабильная версия

## Поддержка

Подробная документация и troubleshooting: [docs/patroni_etcd_postgresql_setup.md](docs/patroni_etcd_postgresql_setup.md)

---

*Обновлено: 2025-12-17*
