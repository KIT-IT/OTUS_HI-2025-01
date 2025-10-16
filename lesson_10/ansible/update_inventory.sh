#!/bin/bash

# Скрипт для обновления inventory.ini с IP адресами из Terraform

echo "Обновление inventory.ini с IP адресами из Terraform..."

# Переходим в директорию с Terraform
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_10

# Получаем IP адреса из Terraform output
NGINX_1_IP=$(terraform output -raw nginx_1_external_ip 2>/dev/null)
NGINX_2_IP=$(terraform output -raw nginx_2_external_ip 2>/dev/null)
BACKEND_1_IP=$(terraform output -raw backend_1_external_ip 2>/dev/null)
BACKEND_2_IP=$(terraform output -raw backend_2_external_ip 2>/dev/null)
DATABASE_IP=$(terraform output -raw database_external_ip 2>/dev/null)

# Проверяем, что IP адреса получены
if [ -z "$NGINX_1_IP" ] || [ -z "$NGINX_2_IP" ]; then
    echo "Ошибка: Не удалось получить IP адреса nginx серверов из Terraform"
    echo "Убедитесь, что инфраструктура развернута: terraform apply"
    exit 1
fi

# Создаем новый inventory файл
cat > ansible/inventory.ini << EOF
[nginx_servers]
# Nginx серверы для балансировки нагрузки
nginx-1 ansible_host=$NGINX_1_IP ansible_ssh_user=sedunovsv ansible_ssh_private_key_file=/home/sedunovsv/.ssh/id_ed25519
nginx-2 ansible_host=$NGINX_2_IP ansible_ssh_user=sedunovsv ansible_ssh_private_key_file=/home/sedunovsv/.ssh/id_ed25519

[backend_servers]
# Backend серверы
backend-1 ansible_host=$BACKEND_1_IP ansible_ssh_user=sedunovsv ansible_ssh_private_key_file=/home/sedunovsv/.ssh/id_ed25519
backend-2 ansible_host=$BACKEND_2_IP ansible_ssh_user=sedunovsv ansible_ssh_private_key_file=/home/sedunovsv/.ssh/id_ed25519

[database_servers]
# Database серверы
database ansible_host=$DATABASE_IP ansible_ssh_user=sedunovsv ansible_ssh_private_key_file=/home/sedunovsv/.ssh/id_ed25519

[nginx_servers:vars]
# Общие переменные для nginx серверов
keepalived_priority_master=100
keepalived_priority_backup=90
virtual_ip=192.168.10.100
virtual_router_id=51

[all:vars]
# Общие переменные для всех серверов
ansible_python_interpreter=/usr/bin/python3
EOF

echo "Inventory обновлен:"
echo "Nginx-1: $NGINX_1_IP"
echo "Nginx-2: $NGINX_2_IP"
echo "Backend-1: $BACKEND_1_IP"
echo "Backend-2: $BACKEND_2_IP"
echo "Database: $DATABASE_IP"
echo ""
echo "Теперь можно запустить Ansible:"
echo "cd ansible"
echo "ansible-playbook -i inventory.ini nginx_keepalived_setup.yml"
