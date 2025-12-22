#!/bin/bash
# Скрипт для просмотра информации о etcd кластере и Patroni

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Endpoints etcd кластера
ENDPOINTS="http://192.168.50.51:2379,http://192.168.50.52:2379,http://192.168.50.53:2379"
ETCD_CT=109

# Функция для выполнения команд etcdctl
etcdctl_cmd() {
    pct exec $ETCD_CT -- /usr/local/bin/etcdctl --endpoints=$ENDPOINTS "$@" 2>/dev/null
}

# Функция для проверки здоровья etcd
check_etcd_health() {
    echo -e "${BLUE}=== ПРОВЕРКА ЗДОРОВЬЯ etcd КЛАСТЕРА ===${NC}"
    etcdctl_cmd endpoint health
    echo ""
}

# Функция для просмотра всех ключей
show_all_keys() {
    echo -e "${BLUE}=== ВСЕ КЛЮЧИ В etcd ===${NC}"
    etcdctl_cmd get --prefix / --keys-only
    echo ""
}

# Функция для просмотра информации о Patroni кластере
show_patroni_cluster() {
    echo -e "${BLUE}=== ИНФОРМАЦИЯ О КЛАСТЕРЕ PATRONI ===${NC}"
    
    # Получаем лидера
    LEADER=$(etcdctl_cmd get /patroni/postgres/leader 2>/dev/null | tail -1)
    if [ -n "$LEADER" ]; then
        echo -e "${GREEN}Лидер кластера: ${LEADER}${NC}"
    else
        echo -e "${RED}Лидер не определен${NC}"
    fi
    echo ""
    
    # Таблица с информацией о членах кластера
    echo -e "${YELLOW}Члены кластера:${NC}"
    printf "%-12s | %-10s | %-12s | %-15s | %-8s | %-15s\n" "Узел" "Роль" "Состояние" "IP адрес" "Timeline" "XLog Location"
    printf "%-12s-+-%-10s-+-%-12s-+-%-15s-+-%-8s-+-%-15s\n" "------------" "----------" "------------" "---------------" "--------" "---------------"
    
    for member in pg102 pg103 pg104; do
        DATA=$(etcdctl_cmd get /patroni/postgres/members/$member 2>/dev/null | tail -1)
        if [ -n "$DATA" ]; then
            ROLE=$(echo "$DATA" | grep -o '"role":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
            STATE=$(echo "$DATA" | grep -o '"state":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
            IP=$(echo "$DATA" | grep -o '"conn_url":"[^"]*"' | cut -d'"' -f4 | sed 's|postgres://||' | cut -d':' -f1 || echo "unknown")
            TIMELINE=$(echo "$DATA" | grep -o '"timeline":[0-9]*' | cut -d':' -f2 || echo "unknown")
            XLOG=$(echo "$DATA" | grep -o '"xlog_location":[0-9]*' | cut -d':' -f2 || echo "unknown")
            
            # Цвет для роли
            if [ "$ROLE" = "master" ]; then
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
            
            printf "%-12s | %-10s | %-12s | %-15s | %-8s | %-15s\n" \
                "$member" "$ROLE_COLOR" "$STATE_COLOR" "$IP" "$TIMELINE" "$XLOG"
        else
            printf "%-12s | %-10s | %-12s | %-15s | %-8s | %-15s\n" \
                "$member" "unknown" "unknown" "unknown" "unknown" "unknown"
        fi
    done
    echo ""
}

# Функция для просмотра конфигурации кластера
show_cluster_config() {
    echo -e "${BLUE}=== КОНФИГУРАЦИЯ КЛАСТЕРА ===${NC}"
    CONFIG=$(etcdctl_cmd get /patroni/postgres/config 2>/dev/null | tail -1)
    if [ -n "$CONFIG" ]; then
        echo "$CONFIG" | python3 -m json.tool 2>/dev/null || echo "$CONFIG"
    else
        echo -e "${RED}Конфигурация не найдена${NC}"
    fi
    echo ""
}

# Функция для просмотра статуса кластера
show_cluster_status() {
    echo -e "${BLUE}=== СТАТУС КЛАСТЕРА ===${NC}"
    STATUS=$(etcdctl_cmd get /patroni/postgres/status 2>/dev/null | tail -1)
    if [ -n "$STATUS" ]; then
        echo "$STATUS" | python3 -m json.tool 2>/dev/null || echo "$STATUS"
    else
        echo -e "${RED}Статус не найден${NC}"
    fi
    echo ""
}

# Функция для просмотра истории кластера
show_cluster_history() {
    echo -e "${BLUE}=== ИСТОРИЯ КЛАСТЕРА (последние 5 записей) ===${NC}"
    HISTORY=$(etcdctl_cmd get /patroni/postgres/history 2>/dev/null | tail -1)
    if [ -n "$HISTORY" ]; then
        echo "$HISTORY" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for entry in data[-5:]:
        if len(entry) >= 2:
            timeline = entry[0]
            lsn = entry[1]
            reason = entry[2] if len(entry) > 2 else 'N/A'
            timestamp = entry[3] if len(entry) > 3 else 'N/A'
            leader = entry[4] if len(entry) > 4 else 'N/A'
            print(f'Timeline: {timeline}, LSN: {lsn}, Reason: {reason}, Time: {timestamp}, Leader: {leader}')
except:
    print(sys.stdin.read())
" 2>/dev/null || echo "$HISTORY"
    else
        echo -e "${RED}История не найдена${NC}"
    fi
    echo ""
}

# Функция для просмотра всех данных Patroni
show_all_patroni_data() {
    echo -e "${BLUE}=== ВСЕ ДАННЫЕ PATRONI В etcd ===${NC}"
    etcdctl_cmd get --prefix /patroni/
    echo ""
}

# Главное меню
show_menu() {
    echo -e "${BLUE}=== МЕНЮ ===${NC}"
    echo "1. Проверка здоровья etcd кластера"
    echo "2. Просмотр всех ключей в etcd"
    echo "3. Информация о Patroni кластере (таблица)"
    echo "4. Конфигурация кластера"
    echo "5. Статус кластера"
    echo "6. История кластера"
    echo "7. Все данные Patroni"
    echo "8. Полная информация (все вышеперечисленное)"
    echo "0. Выход"
    echo ""
}

# Основная функция
main() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Скрипт просмотра информации etcd и Patroni       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ "$1" = "--full" ] || [ "$1" = "-f" ]; then
        # Полный вывод
        check_etcd_health
        show_all_keys
        show_patroni_cluster
        show_cluster_config
        show_cluster_status
        show_cluster_history
    elif [ "$1" = "--patroni" ] || [ "$1" = "-p" ]; then
        # Только информация о Patroni
        show_patroni_cluster
    elif [ "$1" = "--health" ] || [ "$1" = "-h" ]; then
        # Только здоровье
        check_etcd_health
    elif [ "$1" = "--keys" ] || [ "$1" = "-k" ]; then
        # Только ключи
        show_all_keys
    else
        # Интерактивное меню
        while true; do
            show_menu
            read -p "Выберите пункт меню: " choice
            case $choice in
                1)
                    check_etcd_health
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                2)
                    show_all_keys
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                3)
                    show_patroni_cluster
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                4)
                    show_cluster_config
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                5)
                    show_cluster_status
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                6)
                    show_cluster_history
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                7)
                    show_all_patroni_data
                    read -p "Нажмите Enter для продолжения..."
                    clear
                    ;;
                8)
                    check_etcd_health
                    show_all_keys
                    show_patroni_cluster
                    show_cluster_config
                    show_cluster_status
                    show_cluster_history
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


