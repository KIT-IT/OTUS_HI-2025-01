#!/bin/bash

# Скрипт для добавления нод в MySQL InnoDB Cluster

set -e

echo "=== Добавление нод в MySQL InnoDB Cluster ==="

# Проверяем, что первая нода работает
echo "Проверяем статус первой ноды..."
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_11/ansible

# Получаем статус кластера
ansible mysql-node-1 -i inventory.ini -m shell -a "sudo mysql -e \"SELECT * FROM performance_schema.replication_group_members;\"" | grep -E "(ONLINE|OFFLINE)"

echo ""
echo "Текущий статус кластера:"
ansible mysql_cluster -i inventory.ini -m shell -a "sudo /usr/local/bin/cluster-status.sh"

echo ""
echo "=== Попытка добавления mysql-node-2 ==="

# Останавливаем Group Replication на второй ноде
echo "Останавливаем Group Replication на mysql-node-2..."
ansible mysql-node-2 -i inventory.ini -m shell -a "sudo mysql -e \"STOP GROUP_REPLICATION;\"" || true

# Создаем пользователя для репликации на второй ноде
echo "Создаем пользователя для репликации на mysql-node-2..."
ansible mysql-node-2 -i inventory.ini -m shell -a "sudo mysql -e \"CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'replpass'; GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'; FLUSH PRIVILEGES;\"" || true

# Пытаемся добавить вторую ноду
echo "Добавляем mysql-node-2 в кластер..."
ansible mysql-node-2 -i inventory.ini -m shell -a "sudo mysql -e \"CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='replpass' FOR CHANNEL 'group_replication_recovery'; START GROUP_REPLICATION;\"" || echo "Ошибка при добавлении mysql-node-2"

# Ждем немного
sleep 5

# Проверяем статус
echo ""
echo "Проверяем статус после добавления mysql-node-2..."
ansible mysql-node-1 -i inventory.ini -m shell -a "sudo mysql -e \"SELECT * FROM performance_schema.replication_group_members;\"" | grep -E "(ONLINE|OFFLINE)"

echo ""
echo "=== Попытка добавления mysql-node-3 ==="

# Останавливаем Group Replication на третьей ноде
echo "Останавливаем Group Replication на mysql-node-3..."
ansible mysql-node-3 -i inventory.ini -m shell -a "sudo mysql -e \"STOP GROUP_REPLICATION;\"" || true

# Создаем пользователя для репликации на третьей ноде
echo "Создаем пользователя для репликации на mysql-node-3..."
ansible mysql-node-3 -i inventory.ini -m shell -a "sudo mysql -e \"CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'replpass'; GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'; FLUSH PRIVILEGES;\"" || true

# Пытаемся добавить третью ноду
echo "Добавляем mysql-node-3 в кластер..."
ansible mysql-node-3 -i inventory.ini -m shell -a "sudo mysql -e \"CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='replpass' FOR CHANNEL 'group_replication_recovery'; START GROUP_REPLICATION;\"" || echo "Ошибка при добавлении mysql-node-3"

# Ждем немного
sleep 5

# Финальная проверка статуса
echo ""
echo "=== Финальный статус кластера ==="
ansible mysql-node-1 -i inventory.ini -m shell -a "sudo mysql -e \"SELECT * FROM performance_schema.replication_group_members;\"" | grep -E "(ONLINE|OFFLINE)"

echo ""
echo "Детальный статус всех нод:"
ansible mysql_cluster -i inventory.ini -m shell -a "sudo /usr/local/bin/cluster-status.sh"

echo ""
echo "=== Тестирование репликации ==="
echo "Добавляем тестовые данные на PRIMARY ноду..."
ansible mysql-node-1 -i inventory.ini -m shell -a "sudo mysql -e \"USE testdb; INSERT INTO test_table (name) VALUES ('Replication Test - $(date)');\""

echo "Проверяем данные на всех нодах..."
ansible mysql_cluster -i inventory.ini -m shell -a "sudo mysql -e \"SELECT * FROM testdb.test_table ORDER BY id DESC LIMIT 3;\"" | grep -E "(id|Replication Test)"

echo ""
echo "=== Готово! ==="
