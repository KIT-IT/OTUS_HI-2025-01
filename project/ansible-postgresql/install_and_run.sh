#!/bin/bash
# Скрипт для установки Ansible и запуска playbook

echo "=== Установка Ansible ==="
apt-get update -qq
apt-get install -y ansible python3-psycopg2 python3-pip

echo ""
echo "=== Проверка установки ==="
ansible --version

echo ""
echo "=== Проверка подключения к хостам ==="
cd /root/ansible-postgresql
ansible all -i inventory/hosts.yml -m ping

echo ""
echo "=== Запуск playbook ==="
ansible-playbook -i inventory/hosts.yml playbook.yml


