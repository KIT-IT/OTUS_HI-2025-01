#!/bin/bash

# Скрипт для тестирования отказоустойчивости PostgreSQL кластера с Patroni

HAPROXY_IP="192.168.50.12"
HAPROXY_PORT="5432"
HAPROXY_STATS_PORT="8404"
PG_USER="postgres"
PG_PASSWORD="Qwe1234!"
PG_DATABASE="postgres"

echo "=========================================="
echo "Тестирование отказоустойчивости кластера"
echo "=========================================="

# Функция для проверки подключения
check_connection() {
    PGPASSWORD=$PG_PASSWORD psql -h $HAPROXY_IP -p $HAPROXY_PORT -U $PG_USER -d $PG_DATABASE -c "SELECT version();" > /dev/null 2>&1
    return $?
}

# Функция для получения текущего мастера
get_master() {
    PGPASSWORD=$PG_PASSWORD psql -h $HAPROXY_IP -p $HAPROXY_PORT -U $PG_USER -d $PG_DATABASE -t -c "SELECT inet_server_addr() || ':' || inet_server_port();" | tr -d ' '
}

# Функция для проверки статуса через Patroni API
check_patroni_status() {
    local ip=$1
    curl -s http://${ip}:8008/patroni | jq -r '.state' 2>/dev/null || echo "unknown"
}

echo ""
echo "1. Проверка начального состояния кластера"
echo "-------------------------------------------"

# Проверка статуса через HAProxy stats
echo "Статус через HAProxy (http://$HAPROXY_IP:$HAPROXY_STATS_PORT/stats):"
echo "Логин: admin, Пароль: admin123"
echo ""

# Проверка подключения
if check_connection; then
    echo "✓ Подключение к кластеру через HAProxy успешно"
    MASTER=$(get_master)
    echo "  Текущий мастер: $MASTER"
else
    echo "✗ Не удалось подключиться к кластеру"
    exit 1
fi

echo ""
echo "Статус узлов Patroni:"
for ip in 192.168.50.21 192.168.50.22; do
    status=$(check_patroni_status $ip)
    echo "  $ip: $status"
done

echo ""
echo "2. Тест записи данных"
echo "-------------------------------------------"
PGPASSWORD=$PG_PASSWORD psql -h $HAPROXY_IP -p $HAPROXY_PORT -U $PG_USER -d $PG_DATABASE <<EOF
CREATE TABLE IF NOT EXISTS test_ha (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    message TEXT
);
INSERT INTO test_ha (message) VALUES ('Test message before failover');
SELECT * FROM test_ha ORDER BY id DESC LIMIT 5;
EOF

if [ $? -eq 0 ]; then
    echo "✓ Запись данных успешна"
else
    echo "✗ Ошибка при записи данных"
fi

echo ""
echo "3. Инструкции для тестирования failover"
echo "-------------------------------------------"
echo "Для тестирования отказоустойчивости выполните следующие шаги:"
echo ""
echo "1. Остановите текущий мастер (например, на pg104):"
echo "   pct exec 104 -- systemctl stop patroni"
echo ""
echo "2. Подождите 30-60 секунд для переключения"
echo ""
echo "3. Проверьте новый мастер:"
echo "   PGPASSWORD=$PG_PASSWORD psql -h $HAPROXY_IP -p $HAPROXY_PORT -U $PG_USER -d $PG_DATABASE -c \"SELECT inet_server_addr();\""
echo ""
echo "4. Проверьте, что данные сохранились:"
echo "   PGPASSWORD=$PG_PASSWORD psql -h $HAPROXY_IP -p $HAPROXY_PORT -U $PG_USER -d $PG_DATABASE -c \"SELECT * FROM test_ha;\""
echo ""
echo "5. Запишите новые данные:"
echo "   PGPASSWORD=$PG_PASSWORD psql -h $HAPROXY_IP -p $HAPROXY_PORT -U $PG_USER -d $PG_DATABASE -c \"INSERT INTO test_ha (message) VALUES ('Test message after failover');\""
echo ""
echo "6. Восстановите остановленный узел:"
echo "   pct exec 104 -- systemctl start patroni"
echo ""
echo "7. Проверьте, что узел присоединился как реплика:"
echo "   curl http://192.168.50.21:8008/patroni | jq"
echo ""

echo "=========================================="
echo "Тестирование завершено"
echo "=========================================="

