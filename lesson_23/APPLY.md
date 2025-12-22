# Инструкция по применению Salt States

Этот документ описывает пошаговый процесс развертывания инфраструктуры и применения Salt States.

## Предварительные требования

1. Установлен `yc` CLI и выполнена инициализация (`yc init`)
2. Установлен Terraform >= 0.13
3. Настроен SSH ключ (`~/.ssh/id_ed25519.pub`)
4. Существует VPC сеть `otus-network` и подсеть `otus-subnet` в Яндекс.Облаке

## Шаг 1: Развертывание инфраструктуры

### 1.1 Экспорт переменных Яндекс.Облака

```bash
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
```

### 1.2 Запуск развертывания

```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_23
./start.sh
```

Или вручную:

```bash
cd terraform
terraform init
terraform apply
```

После развертывания будут созданы:
- 1 Salt Master (с публичным IP)
- 2 Nginx сервера (с публичными IP)
- 2 Backend сервера (только внутренние IP)

### 1.3 Получение IP адресов

```bash
cd terraform
terraform output
```

Сохраните IP адрес Salt Master - он понадобится для следующих шагов.

## Шаг 2: Установка Salt через Ansible

**Примечание**: Если вы использовали `./start.sh`, этот шаг уже выполнен автоматически!

### 2.1 Автоматическая установка (рекомендуется)

Скрипт `./start.sh` автоматически:
1. Развернет инфраструктуру через Terraform
2. Запустит Ansible playbook для установки Salt Master и Minion
3. Скопирует Salt States и Pillar на Salt Master
4. Примет ключи Minion

### 2.2 Ручная установка через Ansible

Если нужно установить Salt вручную:

```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_23/ansible

# Проверка подключения
ansible all -m ping

# Установка Salt Master и Minion
ansible-playbook playbooks/site.yml
```

Этот playbook:
- Установит Salt Master на сервере salt-master
- Установит Salt Minion на всех серверах
- Скопирует Salt States и Pillar на Salt Master
- Автоматически примет ключи Minion

### 2.3 Проверка установки

После выполнения Ansible playbook:

```bash
# На Salt Master проверить статус
ssh ubuntu@$(cd terraform && terraform output -raw salt_master_external_ip)
sudo salt '*' test.ping
```

## Шаг 3: Обновление Pillar данных

Обновите pillar данные с реальными IP адресами:

```bash
# На Salt Master
SALT_MASTER_INTERNAL_IP=$(hostname -I | awk '{print $1}')

sudo tee /srv/pillar/common.sls > /dev/null <<EOF
nginx_subnet: '192.168.0.0/16'
salt_master_internal_ip: '$SALT_MASTER_INTERNAL_IP'
EOF

# Обновить pillar данные
sudo salt '*' saltutil.refresh_pillar
```

Или через Ansible:

```bash
cd ansible
ansible-playbook playbooks/apply-salt-states.yml
```

## Шаг 4: Применение Salt States

### 4.1 Применение через Ansible (рекомендуется)

```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_23/ansible
ansible-playbook playbooks/apply-salt-states.yml
```

### 4.2 Применение напрямую через Salt

На Salt Master:

```bash
# Тестирование (dry-run)
sudo salt '*' state.apply --test

# Применить ко всем серверам
sudo salt '*' state.apply

# Или к конкретным группам
sudo salt 'nginx-*' state.apply
sudo salt 'backend-*' state.apply
sudo salt 'salt-master' state.apply
```

### 4.3 Проверка результатов

```bash
# Проверить статус сервисов
sudo salt '*' service.status nginx
sudo salt '*' service.status salt-minion

# Проверить правила iptables
sudo salt '*' cmd.run 'iptables -L -n -v'

# Проверить доступность Nginx
sudo salt 'nginx-*' cmd.run 'curl -s http://localhost/health'
```

## Шаг 5: Проверка работы

### 5.1 Проверка Nginx

```bash
# Получить публичные IP Nginx серверов
cd terraform
NGINX_IPS=$(terraform output -json nginx_external_ips | jq -r '.[]')

# Проверить доступность
for ip in $NGINX_IPS; do
  echo "Checking $ip..."
  curl -s http://$ip/health
  curl -s http://$ip/
done
```

### 5.2 Проверка iptables

На каждом сервере:

```bash
# Просмотр правил
sudo iptables -L -n -v

# Проверка логов заблокированных пакетов
sudo tail -f /var/log/kern.log | grep IPTABLES-DROPPED
```

## Полезные команды Salt

```bash
# Просмотр всех minion
sudo salt '*' test.ping

# Выполнение команды на всех серверах
sudo salt '*' cmd.run 'uptime'

# Просмотр grains (информация о серверах)
sudo salt '*' grains.items

# Применение конкретного state
sudo salt '*' state.sls nginx

# Просмотр изменений
sudo salt '*' state.show_highstate

# Обновление pillar данных
sudo salt '*' saltutil.refresh_pillar

# Перезапуск minion
sudo salt '*' service.restart salt-minion
```

## Устранение проблем

### Minion не подключается к Master

1. Проверить, что порты 4505 и 4506 открыты в Security Group
2. Проверить, что в `/etc/salt/minion` указан правильный IP Master
3. Проверить логи: `sudo tail -f /var/log/salt/minion`

### States не применяются

1. Проверить синтаксис: `sudo salt '*' state.show_top`
2. Проверить логи: `sudo tail -f /var/log/salt/master`
3. Применить с подробным выводом: `sudo salt '*' state.apply -l debug`

### iptables блокирует трафик

1. Проверить правила: `sudo iptables -L -n -v`
2. Временно отключить iptables для тестирования: `sudo iptables -F && sudo iptables -P INPUT ACCEPT`
3. Проверить логи: `sudo tail -f /var/log/kern.log`

## Очистка инфраструктуры

Для удаления всех созданных ресурсов:

```bash
cd terraform
terraform destroy
```

---

**Примечание**: В продакшене рекомендуется:
- Отключить `auto_accept` в Salt Master и принимать ключи вручную
- Использовать более строгие правила iptables
- Настроить мониторинг Salt Master и Minion
- Регулярно обновлять Salt States и проверять их работоспособность

