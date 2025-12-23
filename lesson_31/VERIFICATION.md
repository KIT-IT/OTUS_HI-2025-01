# Примеры проверки работы системы

Этот документ содержит примеры команд и ожидаемых результатов для проверки работоспособности всех компонентов системы.

## 1. Проверка инфраструктуры

### Проверка виртуальных машин

```bash
cd lesson_31/terraform
terraform output

# Ожидаемый результат:
# master_public_ip = "130.193.51.xxx"
# worker_public_ips = [
#   "130.193.51.xxx",
#   "130.193.51.xxx",
# ]
# frontend_lb_ip = [
#   "158.160.176.25",
# ]
```

### Проверка доступности узлов

```bash
# Проверка доступности master узла
ssh ubuntu@$(terraform output -raw master_public_ip) "hostname"

# Ожидаемый результат:
# k8s-master-1

# Проверка доступности worker узлов
for ip in $(terraform output -json worker_public_ips | jq -r '.[]'); do
  echo "Checking $ip:"
  ssh ubuntu@$ip "hostname"
done

# Ожидаемый результат:
# k8s-worker-1
# k8s-worker-2
```

## 2. Проверка Kubernetes кластера

### Проверка узлов кластера

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
sudo kubectl get nodes -o wide
EOF

# Ожидаемый результат:
# NAME           STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
# k8s-master-1   Ready    control-plane   1h    v1.29.0   10.128.0.10    <none>        Ubuntu 22.04 LTS     5.15.0-xxx          containerd://1.7.x
# k8s-worker-1   Ready    <none>          1h    v1.29.0   10.128.0.11    <none>        Ubuntu 22.04 LTS     5.15.0-xxx          containerd://1.7.x
# k8s-worker-2   Ready    <none>          1h    v1.29.0   10.128.0.12    <none>        Ubuntu 22.04 LTS     5.15.0-xxx          containerd://1.7.x
```

### Проверка системных Pod'ов

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
sudo kubectl get pods -A
EOF

# Ожидаемый результат (пример):
# NAMESPACE      NAME                                       READY   STATUS    RESTARTS   AGE
# ingress-nginx  ingress-nginx-controller-xxx               1/1     Running   0          1h
# kube-system    calico-kube-controllers-xxx               1/1     Running   0          1h
# kube-system    calico-node-xxx                           1/1     Running   0          1h
# kube-system    calico-node-xxx                           1/1     Running   0          1h
# kube-system    calico-node-xxx                           1/1     Running   0          1h
# kube-system    coredns-xxx                                1/1     Running   0          1h
# kube-system    coredns-xxx                                1/1     Running   0          1h
# kube-system    etcd-k8s-master-1                          1/1     Running   0          1h
# kube-system    kube-apiserver-k8s-master-1                1/1     Running   0          1h
# kube-system    kube-controller-manager-k8s-master-1       1/1     Running   0          1h
# kube-system    kube-proxy-xxx                             1/1     Running   0          1h
# kube-system    kube-proxy-xxx                             1/1     Running   0          1h
# kube-system    kube-proxy-xxx                             1/1     Running   0          1h
# kube-system    kube-scheduler-k8s-master-1                1/1     Running   0          1h
```

## 3. Проверка веб-приложения

### Проверка Pod'ов приложения

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
sudo kubectl -n web get pods -o wide
EOF

# Ожидаемый результат:
# NAME                        READY   STATUS    RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
# backend-xxx-xxx             1/1     Running   0          1h    10.244.1.6   k8s-worker-1   <none>           <none>
# backend-xxx-xxx             1/1     Running   0          1h    10.244.2.4   k8s-worker-2   <none>           <none>
# frontend-xxx-xxx            1/1     Running   0          1h    10.244.1.5   k8s-worker-1   <none>           <none>
# frontend-xxx-xxx            1/1     Running   0          1h    10.244.2.3   k8s-worker-2   <none>           <none>
# postgres-xxx-xxx            1/1     Running   0          1h    10.244.1.7   k8s-worker-1   <none>           <none>
```

### Проверка Services

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
sudo kubectl -n web get svc
EOF

# Ожидаемый результат:
# NAME       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
# backend    ClusterIP   10.102.83.216   <none>        80/TCP         1h
# frontend   NodePort    10.107.46.234   <none>        80:32080/TCP   1h
# postgres   ClusterIP   10.107.46.235   <none>        5432/TCP       1h
```

### Проверка доступа к Frontend через Load Balancer

```bash
FRONTEND_IP=$(cd terraform && terraform output -raw frontend_lb_ip | jq -r '.[0]')

# Проверка главной страницы
curl -v http://${FRONTEND_IP}/

# Ожидаемый результат:
# < HTTP/1.1 200 OK
# < Server: nginx/1.25.1
# < Content-Type: text/html
# < 
# <!DOCTYPE html>
# <html>
# <head>
#   <title>Welcome to OTUS K8s Frontend!</title>
#   ...
# </html>

# Проверка Backend API
curl -v http://${FRONTEND_IP}/api/

# Ожидаемый результат:
# < HTTP/1.1 200 OK
# < Content-Type: application/json
# < 
# {
#   "host": {
#     "hostname": "backend-xxx-xxx",
#     "ip": ["10.244.1.6"],
#     ...
#   },
#   "http": {
#     "method": "GET",
#     "path": "/",
#     ...
#   },
#   ...
# }
```

### Проверка ConfigMap

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
sudo kubectl -n web get configmap
sudo kubectl -n web describe configmap frontend-nginx-conf
EOF

# Ожидаемый результат:
# NAME                  DATA   AGE
# frontend-nginx-conf   2      1h
# frontend-index-html   1      1h
```

## 4. Проверка Vault

### Проверка статуса Vault сервиса

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
systemctl status vault
EOF

# Ожидаемый результат:
# ● vault.service - HashiCorp Vault (dev mode)
#      Loaded: loaded (/etc/systemd/system/vault.service; enabled; vendor preset: enabled)
#      Active: active (running) since ...
```

### Проверка статуса Vault API

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault status
EOF

# Ожидаемый результат:
# Key             Value
# ---             -----
# Seal Type       shamir
# Initialized     true
# Sealed          false
# Total Shares    1
# Threshold       1
# Version         1.21.1
# Storage Type    inmem
# Cluster Name    vault-cluster-xxx
# Cluster ID      xxx-xxx-xxx
# HA Enabled      false
```

### Проверка Database Secrets Engine

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault secrets list
EOF

# Ожидаемый результат:
# Path          Type         Accessor              Description
# ----          ----         --------              -----------
# cubbyhole/    cubbyhole    cubbyhole_xxx         per-token private secret storage
# database/     database     database_xxx         database secrets engine
# identity/     identity     identity_xxx          identity store
# secret/       kv           kv_xxx                key/value secret storage
# sys/          system        system_xxx           system endpoints used for control, policy and debugging
```

### Проверка конфигурации Database Secrets Engine

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/config/appdb
EOF

# Ожидаемый результат:
# Key                                  Value
# ---                                  -----
# allowed_roles                        [app-role]
# connection_url                      postgresql://{{username}}:{{password}}@158.160.176.25:5432/appdb
# plugin_name                         postgresql-database-plugin
# username                            postgres
```

### Проверка роли для генерации учетных данных

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/roles/app-role
EOF

# Ожидаемый результат:
# Key                      Value
# ---                      -----
# creation_statements     [CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT CONNECT ON DATABASE appdb TO "{{name}}";]
# db_name                 appdb
# default_ttl            2m
# max_ttl                5m
# renewal_statements     []
# revocation_statements  []
```

### Генерация динамических учетных данных (первый раз)

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/creds/app-role
EOF

# Ожидаемый результат (пример):
# Key                Value
# ---                -----
# lease_id           database/creds/app-role/xxxxx-xxxxx-xxxxx
# lease_duration     2m
# lease_renewable    true
# password           xxxxx-xxxxx-xxxxx-xxxxx
# username           v-token-app-role-xxxxx
```

### Проверка обновления паролей (через 2 минуты)

```bash
# Первая генерация
FIRST_CREDS=$(ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) \
  'VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read -format=json database/creds/app-role')

FIRST_USERNAME=$(echo $FIRST_CREDS | jq -r '.data.username')
FIRST_PASSWORD=$(echo $FIRST_CREDS | jq -r '.data.password')

echo "First credentials:"
echo "Username: $FIRST_USERNAME"
echo "Password: $FIRST_PASSWORD"

# Подождать 2 минуты
echo "Waiting 2 minutes for TTL expiration..."
sleep 120

# Вторая генерация
SECOND_CREDS=$(ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) \
  'VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read -format=json database/creds/app-role')

SECOND_USERNAME=$(echo $SECOND_CREDS | jq -r '.data.username')
SECOND_PASSWORD=$(echo $SECOND_CREDS | jq -r '.data.password')

echo "Second credentials:"
echo "Username: $SECOND_USERNAME"
echo "Password: $SECOND_PASSWORD"

# Проверка, что учетные данные изменились
if [ "$FIRST_USERNAME" != "$SECOND_USERNAME" ] || [ "$FIRST_PASSWORD" != "$SECOND_PASSWORD" ]; then
  echo "✓ SUCCESS: Credentials have been updated!"
else
  echo "✗ FAILED: Credentials are the same"
fi

# Ожидаемый результат:
# ✓ SUCCESS: Credentials have been updated!
```

### Проверка подключения к Postgres с учетными данными из Vault

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
# Получение учетных данных из Vault
CREDS=$(VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read -format=json database/creds/app-role)
USERNAME=$(echo $CREDS | jq -r '.data.username')
PASSWORD=$(echo $CREDS | jq -r '.data.password')

echo "Testing connection with Vault credentials:"
echo "Username: $USERNAME"

# Проверка подключения (требуется установленный psql или использование PGPASSWORD)
export PGPASSWORD="$PASSWORD"
psql -h 158.160.176.25 -U "$USERNAME" -d appdb -c "SELECT current_user, current_database();" || echo "Connection test completed"
EOF

# Ожидаемый результат:
# Testing connection with Vault credentials:
# Username: v-token-app-role-xxxxx
#  current_user   | current_database 
# ----------------+------------------
#  v-token-app-role-xxxxx | appdb
```

## 5. Проверка резервного копирования

### Проверка CronJob'ов

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
sudo kubectl -n kube-system get cronjob
EOF

# Ожидаемый результат:
# NAME               SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
# backup-etcd        0 */12 * * *  False     0        <none>          1h
# backup-manifests   0 */6 * * *   False     0        <none>          1h
```

### Проверка выполненных Job'ов

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
sudo kubectl -n kube-system get jobs --sort-by=.metadata.creationTimestamp | tail -5
EOF

# Ожидаемый результат (пример):
# NAME                          COMPLETIONS   DURATION   AGE
# backup-manifests-xxxxx        1/1           5s         1h
# backup-etcd-xxxxx             1/1           10s        1h
```

### Просмотр логов бэкапа манифестов

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
LATEST_JOB=$(sudo kubectl -n kube-system get jobs -l job-name --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' | grep backup-manifests)
if [ -n "$LATEST_JOB" ]; then
  sudo kubectl -n kube-system logs job/$LATEST_JOB
else
  echo "No backup-manifests job found"
fi
EOF

# Ожидаемый результат:
# Saved /tmp/cluster-20241223-120000.yaml
```

### Просмотр логов бэкапа etcd

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
LATEST_JOB=$(sudo kubectl -n kube-system get jobs -l job-name --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}' | grep backup-etcd)
if [ -n "$LATEST_JOB" ]; then
  sudo kubectl -n kube-system logs job/$LATEST_JOB
else
  echo "No backup-etcd job found"
fi
EOF

# Ожидаемый результат:
# Saved snapshot to /backup/etcd-20241223-120000.db
# S3 creds not set, skipping upload
```

### Проверка файлов etcd backup на master узле

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
ls -lh /var/lib/etcd/backups/ 2>/dev/null || echo "Backup directory not found or empty"
EOF

# Ожидаемый результат (пример):
# total 2.0M
# -rw-r--r-- 1 root root 1.5M Dec 23 12:00 etcd-20241223-120000.db
```

## 6. Комплексная проверка работоспособности

### Скрипт полной проверки

```bash
#!/bin/bash
# Сохранить как lesson_31/scripts/verify-all.sh

set -e

cd "$(dirname "$0")/.."
MASTER_IP=$(cd terraform && terraform output -raw master_public_ip)
FRONTEND_IP=$(cd terraform && terraform output -raw frontend_lb_ip | jq -r '.[0]')

echo "=== Проверка инфраструктуры ==="
echo "Master IP: $MASTER_IP"
echo "Frontend LB IP: $FRONTEND_IP"

echo -e "\n=== Проверка Kubernetes кластера ==="
ssh ubuntu@$MASTER_IP "sudo kubectl get nodes"

echo -e "\n=== Проверка Pod'ов приложения ==="
ssh ubuntu@$MASTER_IP "sudo kubectl -n web get pods"

echo -e "\n=== Проверка доступа к Frontend ==="
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://${FRONTEND_IP}/

echo -e "\n=== Проверка Backend API ==="
curl -s http://${FRONTEND_IP}/api/ | jq -r '.host.hostname' || echo "Backend check failed"

echo -e "\n=== Проверка Vault ==="
ssh ubuntu@$MASTER_IP "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault status | grep -E 'Sealed|Version'"

echo -e "\n=== Проверка Database Secrets Engine ==="
ssh ubuntu@$MASTER_IP "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/config/appdb | grep -E 'plugin_name|allowed_roles'"

echo -e "\n=== Генерация динамических учетных данных ==="
ssh ubuntu@$MASTER_IP "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault read database/creds/app-role | grep -E 'username|lease_duration'"

echo -e "\n=== Проверка CronJob'ов бэкапов ==="
ssh ubuntu@$MASTER_IP "sudo kubectl -n kube-system get cronjob"

echo -e "\n✓ Все проверки завершены!"
```

## 7. Примеры логов

### Логи Frontend Pod'а

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
sudo kubectl -n web logs -l app=frontend --tail=20
EOF

# Ожидаемый результат (пример):
# 10.244.1.5 - - [23/Dec/2024:12:00:00 +0000] "GET / HTTP/1.1" 200 1234 "-" "curl/7.68.0"
# 10.244.1.5 - - [23/Dec/2024:12:00:05 +0000] "GET /api/ HTTP/1.1" 200 567 "-" "curl/7.68.0"
```

### Логи Backend Pod'а

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
sudo kubectl -n web logs -l app=backend --tail=20
EOF

# Ожидаемый результат (пример):
# {"level":"info","timestamp":"2024-12-23T12:00:00Z","message":"Request received","method":"GET","path":"/"}
```

### Логи Vault

```bash
ssh ubuntu@$(cd terraform && terraform output -raw master_public_ip) << 'EOF'
journalctl -u vault -n 50 --no-pager
EOF

# Ожидаемый результат (пример):
# Dec 23 12:00:00 k8s-master-1 vault[1234]: 2024-12-23T12:00:00.123Z [INFO]  core: vault started successfully
# Dec 23 12:00:05 k8s-master-1 vault[1234]: 2024-12-23T12:00:05.456Z [INFO]  expiration: revoked lease: lease_id=database/creds/app-role/xxxxx
```

