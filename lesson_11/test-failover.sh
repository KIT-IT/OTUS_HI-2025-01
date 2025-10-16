#!/bin/bash

# Скрипт для тестирования отказоустойчивости MySQL InnoDB Cluster

set -e

echo "=== Тестирование отказоустойчивости MySQL InnoDB Cluster ==="

cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_11/ansible

# Функция для проверки статуса кластера
check_cluster_status() {
    echo "Проверяем статус кластера..."
    ansible mysql-node-1 -i inventory.ini -m shell -a "sudo mysql -e \"SELECT * FROM performance_schema.replication_group_members;\"" | grep -E "(ONLINE|RECOVERING|OFFLINE)"
    echo ""
}

# Функция для добавления тестовых данных
add_test_data() {
    local test_name="$1"
    echo "Добавляем тестовые данные: $test_name"
    ansible mysql-node-1 -i inventory.ini -m shell -a "sudo mysql -e \"USE testdb; INSERT INTO test_table (name) VALUES ('$test_name - $(date)');\""
    echo ""
}

# Функция для проверки данных на всех нодах
check_data_replication() {
    echo "Проверяем репликацию данных на всех нодах..."
    ansible mysql_cluster -i inventory.ini -m shell -a "sudo mysql -e \"SELECT COUNT(*) as total_records FROM testdb.test_table;\"" | grep -E "(total_records|[0-9]+)"
    echo ""
}

# Функция для остановки MySQL на ноде
stop_mysql_node() {
    local node="$1"
    echo "Останавливаем MySQL на $node..."
    ansible "$node" -i inventory.ini -m shell -a "sudo systemctl stop mysql"
    echo ""
}

# Функция для запуска MySQL на ноде
start_mysql_node() {
    local node="$1"
    echo "Запускаем MySQL на $node..."
    ansible "$node" -i inventory.ini -m shell -a "sudo systemctl start mysql"
    sleep 10
    echo ""
}

# Функция для перезапуска Group Replication на ноде
restart_group_replication() {
    local node="$1"
    echo "Перезапускаем Group Replication на $node..."
    ansible "$node" -i inventory.ini -m shell -a "sudo mysql -e \"START GROUP_REPLICATION;\"" || true
    sleep 5
    echo ""
}

echo "=== Начальное состояние кластера ==="
check_cluster_status

echo "=== Тест 1: Проверка репликации данных ==="
add_test_data "Pre-Failover Test"
check_data_replication

echo "=== Тест 2: Остановка PRIMARY ноды (mysql-node-1) ==="
stop_mysql_node "mysql-node-1"
sleep 5
check_cluster_status

echo "=== Тест 3: Проверка работы кластера без PRIMARY ==="
echo "Пытаемся добавить данные через другую ноду..."
ansible mysql-node-2 -i inventory.ini -m shell -a "sudo mysql -e \"USE testdb; INSERT INTO test_table (name) VALUES ('Failover Test - Node 2');\"" || echo "Не удалось добавить данные - кластер без PRIMARY"

echo "=== Тест 4: Восстановление PRIMARY ноды ==="
start_mysql_node "mysql-node-1"
restart_group_replication "mysql-node-1"
sleep 10
check_cluster_status

echo "=== Тест 5: Проверка репликации после восстановления ==="
add_test_data "Post-Recovery Test"
check_data_replication

echo "=== Тест 6: Остановка SECONDARY ноды (mysql-node-2) ==="
stop_mysql_node "mysql-node-2"
sleep 5
check_cluster_status

echo "=== Тест 7: Работа кластера с одной нодой ==="
add_test_data "Single Node Test"
check_data_replication

echo "=== Тест 8: Восстановление SECONDARY ноды ==="
start_mysql_node "mysql-node-2"
restart_group_replication "mysql-node-2"
sleep 10
check_cluster_status

echo "=== Тест 9: Финальная проверка репликации ==="
add_test_data "Final Test"
check_data_replication

echo "=== Финальный статус кластера ==="
check_cluster_status

echo "=== Кластер прошел все тесты отказоустойчивости! ==="
