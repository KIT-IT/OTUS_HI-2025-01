#!/bin/bash
# Скрипт для проверки PostgreSQL и Patroni кластера

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Узлы PostgreSQL
PG_NODES=(102 103 104)
PG_IPS=("192.168.50.21" "192.168.50.22" "192.168.50.23")
PG_NAMES=("pg102" "pg103" "pg104")

# Функция для получения IP адреса узла
get_node_ip() {
    local ct_id=$1
    pct config $ct_id | grep "ip=" | awk -F'ip=' '{print $2}' | awk -F',' '{print $1}' | awk -F'/' '{print $1}'
}

# Функция для проверки статуса PostgreSQL
check_postgres_status() {
    local ct_id=$1
    local node_name=$2
    echo -e "${CYAN}=== Проверка PostgreSQL на CT $ct_id ($node_name) ===${NC}"
    
    # Проверка статуса сервиса
    # Примечание: при использовании Patroni сервис PostgreSQL отключен (disabled),
    # так как Patroni сам управляет процессом PostgreSQL
    STATUS=$(pct exec $ct_id -- systemctl is-active postgresql-18 2>/dev/null | tr -d '\n' || echo "inactive")
    ENABLED=$(pct exec $ct_id -- systemctl is-enabled postgresql-18 2>/dev/null | tr -d '\n' || echo "disabled")
    if [ "$STATUS" = "active" ]; then
        echo -e "  Сервис PostgreSQL: ${GREEN}✓ активен${NC}"
    else
        if [ "$ENABLED" = "disabled" ]; then
            echo -e "  Сервис PostgreSQL: ${YELLOW}○ отключен (управляется Patroni)${NC}"
        else
            echo -e "  Сервис PostgreSQL: ${RED}✗ не активен${NC}"
        fi
    fi
    
    # Проверка процесса
    PG_PROCESS=$(pct exec $ct_id -- ps aux | grep "[p]ostgres.*-D" | wc -l)
    if [ "$PG_PROCESS" -gt 0 ]; then
        echo -e "  Процесс PostgreSQL: ${GREEN}✓ запущен${NC}"
        pct exec $ct_id -- ps aux | grep "[p]ostgres.*-D" | head -1 | awk '{print "    PID: " $2 ", Команда: " $11 " " $12 " " $13}'
    else
        echo -e "  Процесс PostgreSQL: ${RED}✗ не найден${NC}"
    fi
    
    # Проверка порта
    PORT_CHECK=$(pct exec $ct_id -- ss -tlnp | grep ":5432" | wc -l)
    if [ "$PORT_CHECK" -gt 0 ]; then
        echo -e "  Порт 5432: ${GREEN}✓ слушает${NC}"
        pct exec $ct_id -- ss -tlnp | grep ":5432" | head -1
    else
        echo -e "  Порт 5432: ${RED}✗ не слушает${NC}"
    fi
    
    echo ""
}

# Функция для проверки статуса Patroni
check_patroni_status() {
    local ct_id=$1
    local node_name=$2
    local node_ip=$3
    echo -e "${CYAN}=== Проверка Patroni на CT $ct_id ($node_name) ===${NC}"
    
    # Проверка статуса сервиса
    STATUS=$(pct exec $ct_id -- systemctl is-active patroni 2>/dev/null || echo "inactive")
    if [ "$STATUS" = "active" ]; then
        echo -e "  Сервис Patroni: ${GREEN}✓ активен${NC}"
    else
        echo -e "  Сервис Patroni: ${RED}✗ не активен${NC}"
        # Показываем последние ошибки
        echo -e "  ${YELLOW}Последние ошибки:${NC}"
        pct exec $ct_id -- journalctl -u patroni --no-pager -n 3 2>/dev/null | tail -3 | sed 's/^/    /'
    fi
    
    # Проверка процесса
    PATRONI_PROCESS=$(pct exec $ct_id -- ps aux | grep "[p]atroni" | wc -l)
    if [ "$PATRONI_PROCESS" -gt 0 ]; then
        echo -e "  Процесс Patroni: ${GREEN}✓ запущен${NC}"
    else
        echo -e "  Процесс Patroni: ${RED}✗ не найден${NC}"
    fi
    
    # Проверка REST API
    REST_API=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 http://$node_ip:8008/patroni 2>/dev/null)
    if [ "$REST_API" = "200" ]; then
        echo -e "  REST API (8008): ${GREEN}✓ доступен${NC}"
        # Получаем информацию о роли через python для правильного парсинга JSON
        API_RESPONSE=$(curl -s http://$node_ip:8008/patroni 2>/dev/null)
        if [ -n "$API_RESPONSE" ]; then
            ROLE=$(echo "$API_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('role', 'unknown'))" 2>/dev/null || echo "unknown")
            STATE=$(echo "$API_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('state', 'unknown'))" 2>/dev/null || echo "unknown")
            if [ "$ROLE" = "master" ] || [ "$ROLE" = "leader" ]; then
                echo -e "  Роль: ${GREEN}$ROLE${NC}, Состояние: ${GREEN}$STATE${NC}"
            else
                echo -e "  Роль: ${YELLOW}$ROLE${NC}, Состояние: ${GREEN}$STATE${NC}"
            fi
        fi
    else
        echo -e "  REST API (8008): ${RED}✗ недоступен (код: $REST_API)${NC}"
    fi
    
    echo ""
}

# Функция для проверки подключения к PostgreSQL
check_postgres_connection() {
    local ct_id=$1
    local node_name=$2
    local node_ip=$3
    echo -e "${CYAN}=== Проверка подключения к PostgreSQL на CT $ct_id ($node_name) ===${NC}"
    
    # Проверка подключения через psql
    CONNECTION=$(pct exec $ct_id -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres -c "SELECT version();" 2>&1)
    if echo "$CONNECTION" | grep -qi "PostgreSQL"; then
        echo -e "  Подключение: ${GREEN}✓ успешно${NC}"
        VERSION=$(echo "$CONNECTION" | grep -i "PostgreSQL" | head -1)
        echo -e "  Версия: $VERSION"
        
        # Проверка статуса репликации (если это реплика)
        REPLICATION=$(pct exec $ct_id -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres -c "SELECT pg_is_in_recovery();" -t 2>/dev/null | tr -d ' ')
        if [ "$REPLICATION" = "t" ]; then
            echo -e "  Режим: ${YELLOW}replica (hot standby)${NC}"
            
            # Получаем информацию о репликации
            REPL_INFO=$(pct exec $ct_id -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres -c "SELECT client_addr, state, sync_state, sync_priority FROM pg_stat_replication;" 2>/dev/null)
            if [ -n "$REPL_INFO" ] && ! echo "$REPL_INFO" | grep -q "0 rows"; then
                echo -e "  ${GREEN}Это master, есть реплики:${NC}"
                echo "$REPL_INFO" | tail -n +3 | sed 's/^/    /'
            fi
        else
            echo -e "  Режим: ${GREEN}master${NC}"
            
            # Получаем информацию о репликации
            REPL_INFO=$(pct exec $ct_id -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres -c "SELECT client_addr, state, sync_state, sync_priority FROM pg_stat_replication;" 2>/dev/null)
            if [ -n "$REPL_INFO" ] && ! echo "$REPL_INFO" | grep -q "0 rows"; then
                echo -e "  ${GREEN}Активные реплики:${NC}"
                echo "$REPL_INFO" | tail -n +3 | sed 's/^/    /'
            else
                echo -e "  ${YELLOW}Реплики не найдены${NC}"
            fi
        fi
        
        # Проверка статуса репликации (если это реплика)
        if [ "$REPLICATION" = "t" ]; then
            REPL_STATE=$(pct exec $ct_id -- sudo -u postgres /usr/pgsql-18/bin/psql -h localhost -U postgres -d postgres -c "SELECT state FROM pg_stat_wal_receiver;" -t 2>/dev/null | tr -d ' ')
            if [ -n "$REPL_STATE" ] && [ "$REPL_STATE" != "" ]; then
                echo -e "  Состояние репликации: ${GREEN}$REPL_STATE${NC}"
            fi
        fi
    else
        echo -e "  Подключение: ${RED}✗ неудачно${NC}"
        echo -e "  Ошибка: $CONNECTION" | head -1 | sed 's/^/    /'
    fi
    
    echo ""
}

# Функция для проверки информации о кластере через Patroni API
check_patroni_cluster_info() {
    echo -e "${BLUE}=== ИНФОРМАЦИЯ О КЛАСТЕРЕ ЧЕРЕЗ PATRONI API ===${NC}"
    printf "%-12s | %-10s | %-12s | %-15s | %-8s | %-20s\n" "Узел" "Роль" "Состояние" "IP адрес" "Timeline" "Lag (байт)"
    printf "%-12s-+-%-10s-+-%-12s-+-%-15s-+-%-8s-+-%-20s\n" "------------" "----------" "------------" "---------------" "--------" "--------------------"
    
    for i in "${!PG_NODES[@]}"; do
        ct_id=${PG_NODES[$i]}
        node_name=${PG_NAMES[$i]}
        node_ip=${PG_IPS[$i]}
        
        # Получаем информацию через REST API
        API_RESPONSE=$(curl -s http://$node_ip:8008/patroni 2>/dev/null)
        if [ -n "$API_RESPONSE" ] && echo "$API_RESPONSE" | grep -q "role"; then
            ROLE=$(echo "$API_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('role', 'unknown'))" 2>/dev/null || echo "unknown")
            STATE=$(echo "$API_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('state', 'unknown'))" 2>/dev/null || echo "unknown")
            TIMELINE=$(echo "$API_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('timeline', 'unknown'))" 2>/dev/null || echo "unknown")
            LAG=$(echo "$API_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('lag', 0))" 2>/dev/null || echo "0")
            
            # Цвет для роли
            if [ "$ROLE" = "master" ] || [ "$ROLE" = "leader" ]; then
                ROLE_COLOR="${GREEN}${ROLE}${NC}"
            else
                ROLE_COLOR="${YELLOW}${ROLE}${NC}"
            fi
            
            # Цвет для состояния
            if [ "$STATE" = "running" ]; then
                STATE_COLOR="${GREEN}${STATE}${NC}"
            else
                STATE_COLOR="${RED}${STATE}${NC}"
            fi
            
            printf "%-12s | %-10s | %-12s | %-15s | %-8s | %-20s\n" \
                "$node_name" "$ROLE_COLOR" "$STATE_COLOR" "$node_ip" "$TIMELINE" "$LAG"
        else
            printf "%-12s | %-10s | %-12s | %-15s | %-8s | %-20s\n" \
                "$node_name" "${RED}unknown${NC}" "${RED}unknown${NC}" "$node_ip" "unknown" "unknown"
        fi
    done
    echo ""
}

# Функция для проверки логов Patroni
check_patroni_logs() {
    local ct_id=$1
    local node_name=$2
    echo -e "${CYAN}=== Последние логи Patroni на CT $ct_id ($node_name) ===${NC}"
    pct exec $ct_id -- journalctl -u patroni --no-pager -n 5 2>/dev/null | tail -5 | sed 's/^/  /'
    echo ""
}

# Функция для проверки логов PostgreSQL
check_postgres_logs() {
    local ct_id=$1
    local node_name=$2
    echo -e "${CYAN}=== Последние логи PostgreSQL на CT $ct_id ($node_name) ===${NC}"
    # Ищем последние логи PostgreSQL
    LOG_FILE=$(pct exec $ct_id -- find /var/lib/pgsql/18/data/log -type f -name "*.log" 2>/dev/null | sort -r | head -1)
    if [ -n "$LOG_FILE" ]; then
        pct exec $ct_id -- tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'
    else
        echo -e "  ${YELLOW}Логи не найдены${NC}"
    fi
    echo ""
}

# Главное меню
show_menu() {
    echo -e "${BLUE}=== МЕНЮ ===${NC}"
    echo "1. Проверка статуса PostgreSQL на всех узлах"
    echo "2. Проверка статуса Patroni на всех узлах"
    echo "3. Проверка подключения к PostgreSQL"
    echo "4. Информация о кластере через Patroni API"
    echo "5. Проверка репликации"
    echo "6. Логи Patroni (последние 5 строк)"
    echo "7. Логи PostgreSQL (последние 5 строк)"
    echo "8. Полная проверка (все вышеперечисленное)"
    echo "0. Выход"
    echo ""
}

# Основная функция
main() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Скрипт проверки PostgreSQL и Patroni кластера      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ "$1" = "--full" ] || [ "$1" = "-f" ]; then
        # Полная проверка
        for i in "${!PG_NODES[@]}"; do
            ct_id=${PG_NODES[$i]}
            node_name=${PG_NAMES[$i]}
            node_ip=${PG_IPS[$i]}
            check_postgres_status $ct_id $node_name
            check_patroni_status $ct_id $node_name $node_ip
            check_postgres_connection $ct_id $node_name $node_ip
        done
        check_patroni_cluster_info
    elif [ "$1" = "--postgres" ] || [ "$1" = "-p" ]; then
        # Только PostgreSQL
        for i in "${!PG_NODES[@]}"; do
            ct_id=${PG_NODES[$i]}
            node_name=${PG_NAMES[$i]}
            check_postgres_status $ct_id $node_name
        done
    elif [ "$1" = "--patroni" ] || [ "$1" = "-P" ]; then
        # Только Patroni
        for i in "${!PG_NODES[@]}"; do
            ct_id=${PG_NODES[$i]}
            node_name=${PG_NAMES[$i]}
            node_ip=${PG_IPS[$i]}
            check_patroni_status $ct_id $node_name $node_ip
        done
    elif [ "$1" = "--cluster" ] || [ "$1" = "-c" ]; then
        # Только информация о кластере
        check_patroni_cluster_info
    else
        # Интерактивное меню
        while true; do
            show_menu
            read -p "Выберите пункт меню: " choice
            case $choice in
                1)
                    for i in "${!PG_NODES[@]}"; do
                        ct_id=${PG_NODES[$i]}
                        node_name=${PG_NAMES[$i]}
                        check_postgres_status $ct_id $node_name
                    done
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                2)
                    for i in "${!PG_NODES[@]}"; do
                        ct_id=${PG_NODES[$i]}
                        node_name=${PG_NAMES[$i]}
                        node_ip=${PG_IPS[$i]}
                        check_patroni_status $ct_id $node_name $node_ip
                    done
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                3)
                    for i in "${!PG_NODES[@]}"; do
                        ct_id=${PG_NODES[$i]}
                        node_name=${PG_NAMES[$i]}
                        node_ip=${PG_IPS[$i]}
                        check_postgres_connection $ct_id $node_name $node_ip
                    done
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                4)
                    check_patroni_cluster_info
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                5)
                    for i in "${!PG_NODES[@]}"; do
                        ct_id=${PG_NODES[$i]}
                        node_name=${PG_NAMES[$i]}
                        node_ip=${PG_IPS[$i]}
                        check_postgres_connection $ct_id $node_name $node_ip
                    done
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                6)
                    for i in "${!PG_NODES[@]}"; do
                        ct_id=${PG_NODES[$i]}
                        node_name=${PG_NAMES[$i]}
                        check_patroni_logs $ct_id $node_name
                    done
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                7)
                    for i in "${!PG_NODES[@]}"; do
                        ct_id=${PG_NODES[$i]}
                        node_name=${PG_NAMES[$i]}
                        check_postgres_logs $ct_id $node_name
                    done
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                8)
                    for i in "${!PG_NODES[@]}"; do
                        ct_id=${PG_NODES[$i]}
                        node_name=${PG_NAMES[$i]}
                        node_ip=${PG_IPS[$i]}
                        check_postgres_status $ct_id $node_name
                        check_patroni_status $ct_id $node_name $node_ip
                        check_postgres_connection $ct_id $node_name $node_ip
                    done
                    check_patroni_cluster_info
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                0)
                    echo "Выход..."
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Неверный выбор${NC}"
                    sleep 1
                    clear
                    ;;
            esac
        done
    fi
}

# Запуск скрипта
main "$@"

