# Инструкция по развертыванию

## Предпосылки

- Yandex Cloud CLI настроен (переменные окружения: `YC_TOKEN`, `YC_CLOUD_ID`, `YC_FOLDER_ID`)
- Terraform установлен (версия >= 1.0)
- Ansible установлен (версия >= 2.9)
- SSH ключ доступен (`~/.ssh/id_ed25519.pub`)
- kubectl установлен на локальной машине (для проверки после bootstrap)

## Шаги развертывания

### 1. Создание инфраструктуры (Terraform)

```bash
cd lesson_31/terraform

# Инициализация Terraform
terraform init

# Планирование изменений
terraform plan

# Применение конфигурации
terraform apply

# Сохранение outputs
terraform output -json > ../terraform-outputs.json
```

**Результат:**
- Созданы VM: `k8s-master-1`, `k8s-worker-1`, `k8s-worker-2`
- Настроены Security Groups
- Создан Network Load Balancer с внешним IP
- Сгенерирован Ansible inventory файл

**Важно:** Сохраните IP адреса из `terraform output` для дальнейшего использования.

### 2. Bootstrap Kubernetes кластера (Ansible)

```bash
cd lesson_31

# Проверка доступности хостов
ansible all -i terraform/inventory -m ping

# Развертывание кластера
ansible-playbook -i terraform/inventory ansible/playbooks/bootstrap.yml

# Ожидаемое время выполнения: 10-15 минут
```

**Что происходит:**
- Установка containerd, kubeadm, kubelet, kubectl
- Настройка системных параметров (swap, sysctl)
- Инициализация master узла (`kubeadm init`)
- Присоединение worker узлов (`kubeadm join`)
- Установка Calico CNI
- Установка ingress-nginx controller
- Копирование `admin.conf` на master узел

**Проверка после bootstrap:**
```bash
# Подключение к master узлу
ssh ubuntu@<master-ip>

# Проверка узлов
sudo kubectl get nodes

# Проверка Pod'ов системных компонентов
sudo kubectl get pods -A
```

### 3. Деплой веб-приложения (Ansible)

```bash
cd lesson_31

# Развертывание приложения
ansible-playbook -i terraform/inventory ansible/playbooks/deploy-app.yml

# Ожидаемое время выполнения: 2-3 минуты
```

**Что происходит:**
- Создание namespace `web`
- Применение манифестов:
  - ConfigMap для Nginx (конфигурация + HTML)
  - Deployment и Service для Frontend (nginx)
  - Deployment и Service для Backend (echo-server)
  - Deployment, Service и Secret для Postgres
  - Ingress ресурс

**Проверка после деплоя:**
```bash
# Подключение к master узлу
ssh ubuntu@<master-ip>

# Проверка Pod'ов приложения
sudo kubectl -n web get pods

# Проверка Services
sudo kubectl -n web get svc

# Проверка ConfigMap
sudo kubectl -n web get configmap

# Получение IP Load Balancer
cd /path/to/lesson_31/terraform
terraform output frontend_lb_ip

# Проверка доступа к Frontend
curl http://<frontend_lb_ip>/

# Проверка Backend API
curl http://<frontend_lb_ip>/api/
```

### 4. Установка и настройка Vault (Ansible)

```bash
cd lesson_31

# Развертывание Vault
ansible-playbook -i terraform/inventory ansible/playbooks/deploy-vault.yml

# Ожидаемое время выполнения: 2-3 минуты
```

**Что происходит:**
- Установка Vault binary на master узел
- Настройка systemd сервиса для Vault (dev mode)
- Запуск Vault сервера
- Включение Database Secrets Engine
- Настройка подключения к Postgres
- Создание роли с TTL 2 минуты

**Проверка Vault:**
```bash
# Подключение к master узлу
ssh ubuntu@<master-ip>

# Проверка статуса Vault
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault status

# Проверка Database Secrets Engine
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/config/appdb

# Генерация динамических учетных данных
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/creds/app-role

# Проверка обновления паролей (подождать 2 минуты и повторить)
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/creds/app-role
```

### 5. Деплой системы резервного копирования (Ansible)

```bash
cd lesson_31

# Развертывание CronJob'ов для бэкапов
ansible-playbook -i terraform/inventory ansible/playbooks/deploy-backup.yml

# Ожидаемое время выполнения: 1 минута
```

**Что происходит:**
- Создание ServiceAccount и RBAC для бэкапов
- Деплой CronJob для бэкапа манифестов (каждые 6 часов)
- Деплой CronJob для бэкапа etcd (каждые 12 часов)

**Проверка бэкапов:**
```bash
# Подключение к master узлу
ssh ubuntu@<master-ip>

# Проверка CronJob'ов
sudo kubectl -n kube-system get cronjob

# Проверка выполненных Job'ов
sudo kubectl -n kube-system get jobs

# Просмотр логов последнего бэкапа манифестов
sudo kubectl -n kube-system logs -l job-name=backup-manifests-<timestamp> --tail=50

# Просмотр логов последнего бэкапа etcd
sudo kubectl -n kube-system logs -l job-name=backup-etcd-<timestamp> --tail=50

# Проверка файлов etcd backup на master узле
ls -lh /var/lib/etcd/backups/
```

## Полная проверка системы

### Проверка инфраструктуры

```bash
# Проверка VM в Yandex Cloud
yc compute instance list

# Проверка Load Balancer
yc load-balancer network-load-balancer list
yc load-balancer target-group list

# Проверка Security Groups
yc vpc security-group list
```

### Проверка Kubernetes кластера

```bash
# На master узле
ssh ubuntu@<master-ip>

# Узлы кластера
sudo kubectl get nodes -o wide

# Все Pod'ы
sudo kubectl get pods -A

# Services
sudo kubectl get svc -A

# Ingress
sudo kubectl get ingress -A
```

### Проверка приложения

```bash
# Получение IP Load Balancer
cd lesson_31/terraform
FRONTEND_IP=$(terraform output -raw frontend_lb_ip)

# Проверка Frontend
curl -v http://${FRONTEND_IP}/

# Проверка Backend API
curl -v http://${FRONTEND_IP}/api/

# Проверка через браузер
# Откройте http://<FRONTEND_IP>/ в браузере
```

### Проверка Vault интеграции

```bash
# На master узле
ssh ubuntu@<master-ip>

# Статус Vault
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault status

# Список секретов
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault secrets list

# Конфигурация Database Secrets Engine
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/config/appdb

# Роль для генерации учетных данных
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/roles/app-role

# Генерация учетных данных (первый раз)
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/creds/app-role

# Записать username и password

# Подождать 2 минуты

# Генерация учетных данных (второй раз - должны быть новые)
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/creds/app-role

# Проверка подключения к Postgres с новыми учетными данными
psql -h 158.160.176.25 -U <vault-username> -d appdb
# Ввести пароль из Vault
```

### Проверка резервного копирования

```bash
# На master узле
ssh ubuntu@<master-ip>

# CronJob'ы
sudo kubectl -n kube-system get cronjob

# Последние Job'ы
sudo kubectl -n kube-system get jobs --sort-by=.metadata.creationTimestamp | tail -5

# Логи бэкапа манифестов
LATEST_MANIFEST_JOB=$(sudo kubectl -n kube-system get jobs -l job-name --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' | grep backup-manifests)
sudo kubectl -n kube-system logs job/${LATEST_MANIFEST_JOB}

# Логи бэкапа etcd
LATEST_ETCD_JOB=$(sudo kubectl -n kube-system get jobs -l job-name --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' | grep backup-etcd)
sudo kubectl -n kube-system logs job/${LATEST_ETCD_JOB}

# Файлы etcd backup
ls -lh /var/lib/etcd/backups/
```

## Устранение неполадок

### Проблема: Pod'ы не запускаются

```bash
# Проверка описания Pod'а
sudo kubectl -n web describe pod <pod-name>

# Проверка логов Pod'а
sudo kubectl -n web logs <pod-name>

# Проверка событий
sudo kubectl -n web get events --sort-by=.metadata.creationTimestamp
```

### Проблема: Frontend недоступен через Load Balancer

```bash
# Проверка статуса Load Balancer
yc load-balancer network-load-balancer get <lb-id> --format json | jq '.listeners'

# Проверка целевых групп
yc load-balancer target-group get <tg-id> --format json | jq '.targets'

# Проверка Pod'ов на worker узлах
sudo kubectl -n web get pods -o wide

# Проверка hostPort на worker узлах
ssh ubuntu@<worker-ip> "sudo netstat -tlnp | grep 30080"
```

### Проблема: Vault не подключается к Postgres

```bash
# Проверка статуса Vault
ssh ubuntu@<master-ip> "systemctl status vault"

# Проверка логов Vault
ssh ubuntu@<master-ip> "journalctl -u vault -n 50"

# Проверка подключения к Postgres с master узла
ssh ubuntu@<master-ip> "nc -zv 158.160.176.25 5432"

# Проверка Postgres Pod'а
sudo kubectl -n web get pods -l app=postgres
sudo kubectl -n web logs -l app=postgres --tail=50
```

### Проблема: CronJob'ы не выполняются

```bash
# Проверка CronJob'ов
sudo kubectl -n kube-system get cronjob

# Проверка последних Job'ов
sudo kubectl -n kube-system get jobs --sort-by=.metadata.creationTimestamp

# Проверка событий
sudo kubectl -n kube-system get events --sort-by=.metadata.creationTimestamp | grep backup

# Ручной запуск Job'а из CronJob
sudo kubectl -n kube-system create job --from=cronjob/backup-manifests manual-backup-$(date +%s)
```

## Очистка ресурсов

### Удаление приложения и Vault

```bash
cd lesson_31

# Удаление бэкапов
ansible-playbook -i terraform/inventory ansible/playbooks/deploy-backup.yml --tags destroy

# Удаление Vault
ansible-playbook -i terraform/inventory ansible/playbooks/deploy-vault.yml --tags destroy

# Удаление приложения
ansible-playbook -i terraform/inventory ansible/playbooks/deploy-app.yml --tags destroy
```

### Удаление инфраструктуры

```bash
cd lesson_31/terraform

# Удаление всех ресурсов
terraform destroy

# Подтвердить удаление: yes
```

**Внимание:** Это удалит все созданные ресурсы в Yandex Cloud, включая VM, Load Balancer, Security Groups.

## Дополнительные команды

### Масштабирование приложения

```bash
# Увеличение количества реплик Frontend
sudo kubectl -n web scale deployment frontend --replicas=3

# Увеличение количества реплик Backend
sudo kubectl -n web scale deployment backend --replicas=3

# Проверка изменений
sudo kubectl -n web get pods
```

### Обновление конфигурации

```bash
# Редактирование ConfigMap
sudo kubectl -n web edit configmap frontend-nginx-conf

# Перезапуск Deployment для применения изменений
sudo kubectl -n web rollout restart deployment/frontend

# Проверка статуса обновления
sudo kubectl -n web rollout status deployment/frontend
```

### Просмотр логов

```bash
# Логи Frontend
sudo kubectl -n web logs -l app=frontend --tail=50 -f

# Логи Backend
sudo kubectl -n web logs -l app=backend --tail=50 -f

# Логи Postgres
sudo kubectl -n web logs -l app=postgres --tail=50 -f

# Логи всех Pod'ов в namespace
sudo kubectl -n web logs --all-containers=true --tail=50
```

## Контакты и документация

- **Kubernetes документация:** https://kubernetes.io/docs/
- **Vault документация:** https://www.vaultproject.io/docs
- **Yandex Cloud документация:** https://cloud.yandex.ru/docs/
- **Terraform Yandex Provider:** https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs
- **Ansible документация:** https://docs.ansible.com/
