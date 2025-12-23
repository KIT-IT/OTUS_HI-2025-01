# ДЗ: Деплой веб-проекта в Kubernetes с Vault (Yandex Cloud)

## Обзор проекта

Проект представляет собой полноценное развертывание веб-приложения в Kubernetes кластере на базе Yandex Cloud с интеграцией HashiCorp Vault для централизованного управления секретами и динамической генерации паролей для базы данных.

## Архитектура решения

### Общая схема

```
┌─────────────────────────────────────────────────────────────────┐
│                        Yandex Cloud                             │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Network Load Balancer (NLB)                  │  │
│  │  External IP: 158.160.176.25                            │  │
│  │  - Port 80 → Frontend (NodePort 30080)                  │  │
│  │  - Port 5432 → Postgres (HostPort 5432)                 │  │
│  └──────────────┬───────────────────────┬───────────────────┘  │
│                 │                       │                       │
│  ┌──────────────▼──────────┐  ┌────────▼──────────────┐       │
│  │   k8s-master-1          │  │  k8s-worker-1         │       │
│  │   (Control Plane)       │  │  k8s-worker-2         │       │
│  │                         │  │                       │       │
│  │  ┌──────────────────┐   │  │  ┌─────────────────┐ │       │
│  │  │  Vault Server    │   │  │  │  Frontend Pods  │ │       │
│  │  │  (Dev Mode)      │   │  │  │  (nginx:2)      │ │       │
│  │  │  :8200           │   │  │  │  :30080         │ │       │
│  │  └──────────────────┘   │  │  └─────────────────┘ │       │
│  │                         │  │                       │       │
│  │  ┌──────────────────┐   │  │  ┌─────────────────┐ │       │
│  │  │  etcd            │   │  │  │  Backend Pods   │ │       │
│  │  │  kube-apiserver  │   │  │  │  (echo-server)  │ │       │
│  │  │  kube-scheduler  │   │  │  └─────────────────┘ │       │
│  │  │  kube-controller │   │  │                       │       │
│  │  └──────────────────┘   │  │  ┌─────────────────┐ │       │
│  │                         │  │  │  Postgres Pod   │ │       │
│  │                         │  │  │  :5432          │ │       │
│  │                         │  │  └─────────────────┘ │       │
│  │                         │  │                       │       │
│  │                         │  │  ┌─────────────────┐ │       │
│  │                         │  │  │  Ingress-NGINX  │ │       │
│  │                         │  │  │  Controller     │ │       │
│  │                         │  │  └─────────────────┘ │       │
│  └─────────────────────────┘  └───────────────────────┘       │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Yandex Object Storage (S3)                   │  │
│  │  - Backup manifests                                      │  │
│  │  - etcd snapshots                                        │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Компоненты системы

#### 1. Инфраструктура (Terraform)

**Виртуальные машины:**
- **k8s-master-1**: Control Plane узел Kubernetes
  - Публичный IP для доступа
  - Установлен Vault в dev-режиме
  - Хранит etcd данные кластера
  
- **k8s-worker-1, k8s-worker-2**: Worker узлы Kubernetes
  - Запускают Pod'ы приложений
  - Frontend (nginx) с hostPort 30080
  - Backend (echo-server)
  - Postgres с hostPort 5432

**Сеть:**
- Используется существующая VPC и подсеть в Yandex Cloud
- Security Groups настроены для:
  - SSH (22)
  - Kubernetes API (6443)
  - NodePort диапазон (30000-32767)
  - Vault HTTP (8200)
  - Postgres (5432)

**Load Balancer:**
- Network Load Balancer с внешним IP
- Слушатель на порту 80 → Worker узлы:30080 (Frontend)
- Слушатель на порту 5432 → Worker узлы:5432 (Postgres)

#### 2. Kubernetes кластер (Ansible + kubeadm)

**Версия:** Kubernetes 1.29.0

**Компоненты Control Plane:**
- `kube-apiserver` - API сервер Kubernetes
- `etcd` - хранилище состояния кластера
- `kube-scheduler` - планировщик Pod'ов
- `kube-controller-manager` - контроллеры кластера

**Сетевое решение:**
- **Calico CNI** (v3.27.3)
  - Pod Network CIDR: `10.244.0.0/16`
  - Обеспечивает сетевое взаимодействие между Pod'ами

**Ingress Controller:**
- **ingress-nginx** (v1.9.6)
  - Развернут в namespace `ingress-nginx`
  - Обеспечивает маршрутизацию HTTP/HTTPS трафика

#### 3. Веб-приложение (Kubernetes Manifests)

**Namespace:** `web`

**Frontend (Nginx):**
- **Deployment:** 2 реплики
- **Image:** `nginx:1.25-alpine`
- **ConfigMap:** 
  - Конфигурация Nginx (`default.conf`)
  - Кастомная HTML страница (`index.html`)
- **Service:** NodePort (32080)
- **HostPort:** 30080 (для прямого доступа через NLB)
- **Функции:**
  - Статический контент на `/`
  - Проксирование API запросов на `/api/` к backend

**Backend (Echo Server):**
- **Deployment:** 2 реплики
- **Image:** `ealen/echo-server:latest`
- **Service:** ClusterIP
- **Функции:**
  - Возвращает JSON с информацией о запросе
  - Обрабатывает API запросы от frontend

**Postgres:**
- **Deployment:** 1 реплика
- **Image:** `postgres:14-alpine`
- **Database:** `appdb`
- **Secret:** `postgres-secret` с паролем
- **Service:** ClusterIP
- **HostPort:** 5432 (для доступа через NLB)
- **Volume:** `emptyDir` (для демо, в продакшене - PersistentVolume)

#### 4. HashiCorp Vault (Ansible)

**Режим:** Dev Mode (для демонстрации)

**Установка:**
- Бинарный файл Vault 1.21.1 установлен на master узле
- Запущен как systemd сервис
- Root token: `root`
- HTTP API: `http://127.0.0.1:8200`

**Database Secrets Engine:**
- **Плагин:** `postgresql-database-plugin`
- **Подключение:** Postgres через внешний NLB IP
- **Роль:** `app-role`
- **TTL:** 120 секунд (2 минуты)
- **Max TTL:** 300 секунд (5 минут)

**Функциональность:**
- Динамическая генерация учетных записей БД
- Автоматическое обновление паролей каждые 2 минуты
- Создание ролей PostgreSQL с временными паролями

#### 5. Система резервного копирования (CronJobs)

**Backup Manifests:**
- **CronJob:** `backup-manifests`
- **Расписание:** Каждые 6 часов (`0 */6 * * *`)
- **Действие:** `kubectl get all --all-namespaces -o yaml`
- **Результат:** YAML файл со всеми ресурсами кластера

**Backup etcd:**
- **CronJob:** `backup-etcd`
- **Расписание:** Каждые 12 часов (`0 */12 * * *`)
- **Действие:** `etcdctl snapshot save`
- **Результат:** Снимок состояния etcd
- **Опционально:** Загрузка в Yandex Object Storage (S3)

## Технологический стек

| Компонент | Технология | Версия/Назначение |
|-----------|-----------|-------------------|
| **Инфраструктура** | Terraform | IaC для Yandex Cloud |
| **Автоматизация** | Ansible | Configuration Management |
| **Оркестрация** | Kubernetes | 1.29.0 |
| **Инициализация** | kubeadm | Bootstrap кластера |
| **CNI** | Calico | 3.27.3 |
| **Ingress** | ingress-nginx | 1.9.6 |
| **Frontend** | Nginx | 1.25-alpine |
| **Backend** | echo-server | latest |
| **База данных** | PostgreSQL | 14-alpine |
| **Secrets Management** | HashiCorp Vault | 1.21.1 |
| **Container Runtime** | containerd | Latest |
| **Load Balancer** | Yandex NLB | Network Load Balancer |
| **Storage** | Yandex Object Storage | S3-совместимое API |

## Потоки данных

### 1. Запрос к Frontend

```
Internet → NLB (158.160.176.25:80) → Worker Node:30080 → Frontend Pod → Nginx
                                                                        ↓
                                                                    /api/ → Backend Service → Backend Pod
```

### 2. Vault → Postgres

```
Vault (master-1) → NLB (158.160.176.25:5432) → Worker Node:5432 → Postgres Pod
```

### 3. Динамическая генерация паролей

```
Vault API → database/creds/app-role → Postgres Connection → CREATE ROLE → Return Credentials
```

## Проверка работы системы

### 1. Проверка кластера

```bash
# Проверка узлов
kubectl get nodes -o wide

# Ожидаемый результат:
# NAME           STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP
# k8s-master-1   Ready    control-plane   1h    v1.29.0   10.128.0.10    <none>
# k8s-worker-1   Ready    <none>          1h    v1.29.0   10.128.0.11    <none>
# k8s-worker-2   Ready    <none>          1h    v1.29.0   10.128.0.12    <none>
```

### 2. Проверка Pod'ов приложения

```bash
# Проверка Pod'ов в namespace web
kubectl -n web get pods -o wide

# Ожидаемый результат:
# NAME                        READY   STATUS    RESTARTS   AGE   IP           NODE
# frontend-xxxxxxxxxx-xxxxx   1/1     Running   0          1h    10.244.1.5   k8s-worker-1
# frontend-xxxxxxxxxx-xxxxx   1/1     Running   0          1h    10.244.2.3   k8s-worker-2
# backend-xxxxxxxxxx-xxxxx    1/1     Running   0          1h    10.244.1.6   k8s-worker-1
# backend-xxxxxxxxxx-xxxxx    1/1     Running   0          1h    10.244.2.4   k8s-worker-2
# postgres-xxxxxxxxxx-xxxxx   1/1     Running   0          1h    10.244.1.7   k8s-worker-1
```

### 3. Проверка доступа к Frontend

```bash
# Получение IP Load Balancer
terraform -chdir=terraform output frontend_lb_ip

# Проверка Frontend
curl http://158.160.176.25/

# Ожидаемый результат: HTML страница с приветствием

# Проверка Backend API
curl http://158.160.176.25/api/

# Ожидаемый результат: JSON с информацией о запросе
```

### 4. Проверка Vault

```bash
# Подключение к master узлу
ssh ubuntu@<master-ip>

# Проверка статуса Vault
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault status

# Ожидаемый результат:
# Key             Value
# ---             -----
# Seal Type       shamir
# Initialized     true
# Sealed          false
# Total Shares    1
# Version         1.21.1
# Storage Type    inmem
# Cluster Name    vault-cluster-xxx
# Cluster ID      xxx-xxx-xxx
# HA Enabled      false

# Проверка Database Secrets Engine
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/config/appdb

# Ожидаемый результат:
# Key                                  Value
# ---                                  -----
# allowed_roles                        [app-role]
# connection_url                      postgresql://{{username}}:{{password}}@158.160.176.25:5432/appdb
# plugin_name                         postgresql-database-plugin
# username                            postgres

# Генерация динамических учетных данных
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/creds/app-role

# Ожидаемый результат:
# Key                Value
# ---                -----
# lease_id           database/creds/app-role/xxxxx
# lease_duration     2m
# lease_renewable    true
# password           xxxxx-xxxxx-xxxxx
# username           v-token-app-role-xxxxx
```

### 5. Проверка обновления паролей

```bash
# Первая генерация
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/creds/app-role
# Записать username и password

# Подождать 2 минуты

# Вторая генерация (новые учетные данные)
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/creds/app-role
# Убедиться, что username и password изменились
```

### 6. Проверка резервного копирования

```bash
# Проверка CronJob'ов
kubectl -n kube-system get cronjob

# Ожидаемый результат:
# NAME               SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
# backup-etcd        0 */12 * * *  False     0        <none>          1h
# backup-manifests   0 */6 * * *   False     0        <none>          1h

# Проверка выполненных Job'ов
kubectl -n kube-system get jobs

# Просмотр логов последнего backup
kubectl -n kube-system logs -l job-name=backup-manifests-xxxxx --tail=50
kubectl -n kube-system logs -l job-name=backup-etcd-xxxxx --tail=50

# Проверка файлов на master узле (для etcd backup)
ssh ubuntu@<master-ip> "ls -lh /var/lib/etcd/backups/"
```

## Структура проекта

```
lesson_31/
├── terraform/                    # Инфраструктура Yandex Cloud
│   ├── main.tf                   # Основная конфигурация (VM, NLB, SG)
│   ├── variables.tf              # Переменные Terraform
│   ├── outputs.tf                # Выводы (IP адреса, NLB IP)
│   └── templates/
│       └── inventory.tpl         # Шаблон Ansible inventory
│
├── ansible/                      # Автоматизация через Ansible
│   ├── ansible.cfg               # Конфигурация Ansible
│   ├── inventory                 # Инвентарь хостов (генерируется)
│   ├── group_vars/
│   │   └── all/
│   │       └── main.yml          # Глобальные переменные
│   ├── playbooks/
│   │   ├── bootstrap.yml         # Bootstrap Kubernetes кластера
│   │   ├── deploy-app.yml        # Деплой веб-приложения
│   │   ├── deploy-vault.yml      # Установка и настройка Vault
│   │   └── deploy-backup.yml     # Деплой CronJob'ов для бэкапов
│   └── roles/
│       ├── common/               # Общие настройки (swap, sysctl, containerd)
│       ├── k8s-master/           # Инициализация master узла
│       ├── k8s-worker/           # Присоединение worker узлов
│       ├── app-base/             # Базовые манифесты (namespace)
│       ├── app-web/              # Манифесты веб-приложения
│       ├── vault/                # Установка и настройка Vault
│       └── backup/               # Деплой CronJob'ов бэкапов
│
├── k8s/                          # Kubernetes манифесты
│   ├── base/
│   │   └── namespace.yaml        # Namespace web
│   ├── web/
│   │   ├── configmap-frontend.yaml    # ConfigMap для Nginx
│   │   ├── deployment-frontend.yaml   # Deployment Frontend
│   │   ├── service-frontend.yaml      # Service Frontend
│   │   ├── deployment-backend.yaml    # Deployment Backend
│   │   ├── service-backend.yaml       # Service Backend
│   │   ├── postgres.yaml              # Deployment/Service/Secret Postgres
│   │   └── ingress.yaml               # Ingress ресурс
│   └── jobs/
│       ├── backup-manifests.yaml      # CronJob для бэкапа манифестов
│       ├── backup-etcd.yaml          # CronJob для бэкапа etcd
│       └── backup-s3-secret.example.yaml  # Пример Secret для S3
│
├── vault/                        # Конфигурация Vault
│   ├── values.yaml               # Helm values (не используется, Vault через binary)
│   └── vault_1.21.1_linux_amd64.zip  # Бинарный файл Vault
│
├── scripts/                      # Вспомогательные скрипты
│
├── README.md                     # Этот файл (документация)
├── APPLY.md                      # Инструкции по развертыванию
└── ДЗ.md                         # Описание домашнего задания
```

## Ключевые особенности реализации

### 1. Разделение ответственности
- **Terraform**: Только создание инфраструктуры (VM, сеть, Load Balancer)
- **Ansible**: Вся автоматизация (установка ПО, настройка, деплой)

### 2. Доступность приложения
- Frontend доступен через внешний Network Load Balancer
- Использование `hostPort` для прямого доступа к Pod'ам
- Postgres доступен через NLB для интеграции с Vault

### 3. Управление секретами
- Vault в dev-режиме для демонстрации функциональности
- Database Secrets Engine с динамической генерацией паролей
- TTL 2 минуты для демонстрации автоматического обновления

### 4. Резервное копирование
- Автоматические CronJob'ы для бэкапа манифестов и etcd
- Возможность загрузки в Yandex Object Storage
- Регулярное выполнение по расписанию

### 5. Масштабируемость
- Frontend и Backend развернуты с 2 репликами
- Возможность горизонтального масштабирования через `kubectl scale`
- Load Balancer распределяет нагрузку между worker узлами

## Безопасность

### Реализовано:
- Security Groups в Yandex Cloud ограничивают доступ
- Kubernetes RBAC для CronJob'ов бэкапов
- Secrets хранятся в Kubernetes Secrets
- Vault root token защищен (только локальный доступ)

### Рекомендации для продакшена:
- Vault в production режиме с HA
- TLS для всех соединений
- Использование PersistentVolume для Postgres
- Регулярное ротирование паролей и сертификатов
- Мониторинг и алертинг
- Network Policies для ограничения трафика между Pod'ами

## Производительность

- **Frontend**: 2 реплики Nginx для высокой доступности
- **Backend**: 2 реплики echo-server для балансировки нагрузки
- **Postgres**: 1 реплика (для демо, в продакшене - HA кластер)
- **Load Balancer**: Распределение трафика между worker узлами

## Мониторинг и логирование

Для проверки состояния системы используются стандартные команды Kubernetes:
- `kubectl get` для проверки ресурсов
- `kubectl logs` для просмотра логов Pod'ов
- `kubectl describe` для диагностики проблем
- Логи Vault через systemd (`journalctl -u vault`)
