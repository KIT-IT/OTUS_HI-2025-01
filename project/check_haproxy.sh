#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# IP адреса и контейнеры
HAPROXY_HOSTS=(100 101)
HAPROXY_IPS=("192.168.50.11" "192.168.50.12")
VIP="192.168.50.10"
VIP_NETMASK="24"
STATS_PORT=8404
STATS_USER="admin"
STATS_PASS="admin123"

# PostgreSQL узлы
PG_HOSTS=(102 103 104)
PG_IPS=("192.168.50.21" "192.168.50.22" "192.168.50.23")
PG_PORT=5432
PG_USER="postgres"
PG_DB="postgres"

# Docker Swarm узлы
DOCKER_HOSTS=(105 106)
DOCKER_IPS=("192.168.50.31" "192.168.50.32")
DOCKER_PORT=2377

# Функция для выполнения команды в контейнере
pct_exec_cmd() {
    local ct_id=$1
    shift
    pct exec "$ct_id" -- bash -c "$@" 2>/dev/null
}

# Функция для проверки статуса сервиса
check_service() {
    local ct_id=$1
    local service=$2
    local status=$(pct_exec_cmd $ct_id "systemctl is-active $service 2>/dev/null")
    if [ "$status" = "active" ]; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# Функция для проверки порта
check_port() {
    local ip=$1
    local port=$2
    if timeout 1 bash -c "cat < /dev/null > /dev/tcp/$ip/$port" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# Функция для получения IP адреса контейнера
get_ct_ip() {
    local ct_id=$1
    pct config $ct_id 2>/dev/null | grep "ip=" | awk -F'ip=' '{print $2}' | awk -F',' '{print $1}' | awk -F'/' '{print $1}'
}

# Функция для проверки VIP
check_vip() {
    local ct_id=$1
    local ip=$(get_ct_ip $ct_id)
    local vip_check=$(pct_exec_cmd $ct_id "ip addr show 2>/dev/null | grep '$VIP' | wc -l")
    if [ "$vip_check" -gt 0 ]; then
        echo -e "${GREEN}✓ MASTER${NC}"
        return 0
    else
        echo -e "${YELLOW}○ BACKUP${NC}"
        return 1
    fi
}

# Функция для получения статистики HAProxy
get_haproxy_stats() {
    local ip=$1
    curl -s -u "$STATS_USER:$STATS_PASS" "http://$ip:$STATS_PORT/stats;csv" 2>/dev/null
}

# Функция для отображения статуса HAProxy узлов
show_haproxy_nodes() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Статус HAProxy узлов                             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    printf "%-8s %-18s %-12s %-12s %-15s\n" "CT ID" "IP адрес" "HAProxy" "Keepalived" "VIP статус"
    echo "────────────────────────────────────────────────────────────────────────"
    
    for i in "${!HAPROXY_HOSTS[@]}"; do
        local ct_id=${HAPROXY_HOSTS[$i]}
        local ip=${HAPROXY_IPS[$i]}
        local haproxy_status=$(check_service $ct_id "haproxy")
        local keepalived_status=$(check_service $ct_id "keepalived")
        local vip_status=$(check_vip $ct_id)
        
        printf "%-8s %-18s %-12s %-12s %-15s\n" "CT $ct_id" "$ip" "$haproxy_status" "$keepalived_status" "$vip_status"
    done
    echo ""
}

# Функция для отображения IP адресов Keepalived
show_keepalived_ips() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              IP адреса Keepalived                             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    for i in "${!HAPROXY_HOSTS[@]}"; do
        local ct_id=${HAPROXY_HOSTS[$i]}
        local ip=${HAPROXY_IPS[$i]}
        local vip_check=$(pct_exec_cmd $ct_id "ip addr show 2>/dev/null | grep '$VIP'")
        
        echo -e "${BLUE}CT $ct_id ($ip):${NC}"
        echo -e "  Основной IP: $ip"
        if [ -n "$vip_check" ]; then
            echo -e "  ${GREEN}VIP: $VIP/$VIP_NETMASK (MASTER)${NC}"
            local vip_interface=$(echo "$vip_check" | awk '{print $NF}')
            echo -e "  Интерфейс VIP: $vip_interface"
        else
            echo -e "  ${YELLOW}VIP: отсутствует (BACKUP)${NC}"
        fi
        echo ""
    done
    
    echo -e "${MAGENTA}Виртуальный IP (VIP): $VIP/$VIP_NETMASK${NC}"
    echo ""
}

# Функция для отображения статуса серверов в HAProxy
show_haproxy_servers() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Статус серверов в HAProxy                           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Используем VIP для получения статистики
    local stats=$(get_haproxy_stats $VIP)
    
    if [ -z "$stats" ]; then
        # Если VIP недоступен, пробуем прямой IP
        stats=$(get_haproxy_stats ${HAPROXY_IPS[0]})
    fi
    
    if [ -z "$stats" ]; then
        echo -e "${RED}✗ Не удалось получить статистику HAProxy${NC}"
        return 1
    fi
    
    echo -e "${BLUE}PostgreSQL серверы:${NC}"
    echo "────────────────────────────────────────────────────────────────────────"
    printf "%-20s %-15s %-10s %-10s %-10s\n" "Сервер" "IP:Порт" "Статус" "Сессии" "Ошибки"
    echo "────────────────────────────────────────────────────────────────────────"
    
    for i in "${!PG_IPS[@]}"; do
        local pg_ip=${PG_IPS[$i]}
        local server_name="pg${PG_HOSTS[$i]}"
        # Пробуем найти по имени сервера или по IP
        local server_line=$(echo "$stats" | grep -E "^$server_name,|,$pg_ip:$PG_PORT," | head -1)
        
        if [ -z "$server_line" ]; then
            # Пробуем найти по IP в любом месте строки
            server_line=$(echo "$stats" | grep "$pg_ip:$PG_PORT" | head -1)
        fi
        
        if [ -n "$server_line" ]; then
            # Парсим CSV формат HAProxy статистики
            # Формат: pxname,svname,qcur,qmax,scur,smax,slim,stot,bin,bout,dreq,dresp,ereq,econ,eresp,wretr,wredis,status,weight,act,bck,chkfail,chkdown,lastchg,downtime,qlimit,pid,iid,sid,throttle,lbtot,tracked,type,rate,rate_max,check_status,check_code,check_duration,hrsp_1xx,hrsp_2xx,hrsp_3xx,hrsp_4xx,hrsp_5xx,hrsp_other,hanafail,req_rate,req_rate_max,req_tot,cli_abrt,srv_abrt,comp_in,comp_out,comp_byp,comp_rsp,lastsess,last_chk,last_agt,qtime,ctime,rtime,ttime
            local status=$(echo "$server_line" | cut -d',' -f18)
            local sessions=$(echo "$server_line" | cut -d',' -f5)
            local errors=$(echo "$server_line" | cut -d',' -f13)
            
            if [ "$status" = "UP" ] || [ "$status" = "OPEN" ]; then
                status_display="${GREEN}UP${NC}"
            else
                status_display="${RED}DOWN${NC}"
            fi
            
            printf "%-20s %-15s %-10s %-10s %-10s\n" "$server_name" "$pg_ip:$PG_PORT" "$status_display" "$sessions" "$errors"
        else
            # Если не нашли в статистике, проверяем напрямую
            if check_port $pg_ip $PG_PORT > /dev/null 2>&1; then
                printf "%-20s %-15s %-10s %-10s %-10s\n" "$server_name" "$pg_ip:$PG_PORT" "${GREEN}UP${NC}" "N/A" "N/A"
            else
                printf "%-20s %-15s %-10s %-10s %-10s\n" "$server_name" "$pg_ip:$PG_PORT" "${RED}DOWN${NC}" "N/A" "N/A"
            fi
        fi
    done
    
    echo ""
    echo -e "${BLUE}Docker Swarm Manager серверы:${NC}"
    echo "────────────────────────────────────────────────────────────────────────"
    printf "%-20s %-15s %-10s %-10s %-10s\n" "Сервер" "IP:Порт" "Статус" "Сессии" "Ошибки"
    echo "────────────────────────────────────────────────────────────────────────"
    
    for i in "${!DOCKER_IPS[@]}"; do
        local docker_ip=${DOCKER_IPS[$i]}
        local server_name="docker_mgr$((i+1))"
        # Пробуем найти по имени сервера или по IP
        local server_line=$(echo "$stats" | grep -E "^$server_name,|,$docker_ip:$DOCKER_PORT," | head -1)
        
        if [ -z "$server_line" ]; then
            # Пробуем найти по IP в любом месте строки
            server_line=$(echo "$stats" | grep "$docker_ip:$DOCKER_PORT" | head -1)
        fi
        
        if [ -n "$server_line" ]; then
            local status=$(echo "$server_line" | cut -d',' -f18)
            local sessions=$(echo "$server_line" | cut -d',' -f5)
            local errors=$(echo "$server_line" | cut -d',' -f13)
            
            if [ "$status" = "UP" ] || [ "$status" = "OPEN" ]; then
                status_display="${GREEN}UP${NC}"
            else
                status_display="${RED}DOWN${NC}"
            fi
            
            printf "%-20s %-15s %-10s %-10s %-10s\n" "$server_name" "$docker_ip:$DOCKER_PORT" "$status_display" "$sessions" "$errors"
        else
            # Если не нашли в статистике, проверяем напрямую
            if check_port $docker_ip $DOCKER_PORT > /dev/null 2>&1; then
                printf "%-20s %-15s %-10s %-10s %-10s\n" "$server_name" "$docker_ip:$DOCKER_PORT" "${GREEN}UP${NC}" "N/A" "N/A"
            else
                printf "%-20s %-15s %-10s %-10s %-10s\n" "$server_name" "$docker_ip:$DOCKER_PORT" "${RED}DOWN${NC}" "N/A" "N/A"
            fi
        fi
    done
    echo ""
}

# Функция для проверки балансировки PostgreSQL
check_postgresql_balancing() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Проверка балансировки PostgreSQL                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}Выполняю 10 запросов через VIP ($VIP) для проверки балансировки...${NC}"
    echo ""
    
    local results=()
    local pg102_count=0
    local pg103_count=0
    local pg104_count=0
    
    # Используем один из PostgreSQL узлов для выполнения запросов
    local pg_node=${PG_HOSTS[0]}  # Используем первый PostgreSQL узел
    
    echo -e "${YELLOW}Используем CT $pg_node для выполнения запросов${NC}"
    echo ""
    
    for i in {1..10}; do
        # Выполняем запрос через PostgreSQL узел к VIP
        local result=$(pct exec $pg_node -- bash -c "PGPASSWORD=Qwe1234! /usr/pgsql-18/bin/psql -h $VIP -U $PG_USER -d $PG_DB -t -c 'SELECT inet_server_addr();' 2>/dev/null" | tr -d ' \n\r')
        
        if [ -n "$result" ] && [ "$result" != "" ] && [ "$result" != "inet_server_addr" ]; then
            results+=("$result")
            case "$result" in
                ${PG_IPS[0]})
                    ((pg102_count++))
                    ;;
                ${PG_IPS[1]})
                    ((pg103_count++))
                    ;;
                ${PG_IPS[2]})
                    ((pg104_count++))
                    ;;
            esac
            echo -e "  Запрос $i: ${GREEN}✓${NC} → $result"
        else
            echo -e "  Запрос $i: ${RED}✗${NC} Ошибка подключения"
        fi
        
        sleep 0.5
    done
    
    # Альтернативный метод через прямой psql (если доступен)
    if command -v psql &> /dev/null; then
        echo ""
        echo -e "${BLUE}Также проверяю через локальный psql...${NC}"
        echo ""
        
        for i in {1..5}; do
            local result=$(PGPASSWORD=Qwe1234! psql -h $VIP -U $PG_USER -d $PG_DB -t -c "SELECT inet_server_addr();" 2>/dev/null | tr -d ' \n\r')
            
            if [ -n "$result" ] && [ "$result" != "" ] && [ "$result" != "inet_server_addr" ]; then
                results+=("$result")
                case "$result" in
                    ${PG_IPS[0]})
                        ((pg102_count++))
                        ;;
                    ${PG_IPS[1]})
                        ((pg103_count++))
                        ;;
                    ${PG_IPS[2]})
                        ((pg104_count++))
                        ;;
                esac
                echo -e "  Запрос $((10+i)): ${GREEN}✓${NC} → $result"
            fi
            sleep 0.5
        done
    fi
    
    echo ""
    echo -e "${BLUE}Результаты балансировки:${NC}"
    echo "────────────────────────────────────────────────────────────────────────"
    printf "%-20s %-10s %-10s\n" "Сервер" "Запросов" "Процент"
    echo "────────────────────────────────────────────────────────────────────────"
    
    local total=$((pg102_count + pg103_count + pg104_count))
    if [ $total -gt 0 ]; then
        local pg102_percent=$((pg102_count * 100 / total))
        local pg103_percent=$((pg103_count * 100 / total))
        local pg104_percent=$((pg104_count * 100 / total))
        
        printf "%-20s %-10s %-10s\n" "pg102 (${PG_IPS[0]})" "$pg102_count" "$pg102_percent%"
        printf "%-20s %-10s %-10s\n" "pg103 (${PG_IPS[1]})" "$pg103_count" "$pg103_percent%"
        printf "%-20s %-10s %-10s\n" "pg104 (${PG_IPS[2]})" "$pg104_count" "$pg104_percent%"
    else
        echo -e "${RED}✗ Не удалось выполнить запросы${NC}"
    fi
    echo ""
}

# Функция для проверки портов
check_ports() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Проверка портов                                  ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}Проверка портов через VIP ($VIP):${NC}"
    echo "────────────────────────────────────────────────────────────────────────"
    
    local pg_port=$(check_port $VIP $PG_PORT)
    local docker_port=$(check_port $VIP $DOCKER_PORT)
    local stats_port=$(check_port $VIP $STATS_PORT)
    
    printf "%-30s %-10s\n" "PostgreSQL ($PG_PORT)" "$pg_port"
    printf "%-30s %-10s\n" "Docker Swarm ($DOCKER_PORT)" "$docker_port"
    printf "%-30s %-10s\n" "HAProxy Stats ($STATS_PORT)" "$stats_port"
    echo ""
    
    echo -e "${BLUE}Проверка портов на HAProxy узлах:${NC}"
    echo "────────────────────────────────────────────────────────────────────────"
    
    for i in "${!HAPROXY_HOSTS[@]}"; do
        local ct_id=${HAPROXY_HOSTS[$i]}
        local ip=${HAPROXY_IPS[$i]}
        echo -e "${BLUE}CT $ct_id ($ip):${NC}"
        
        local pg_port_direct=$(check_port $ip $PG_PORT)
        local docker_port_direct=$(check_port $ip $DOCKER_PORT)
        local stats_port_direct=$(check_port $ip $STATS_PORT)
        
        printf "  %-30s %-10s\n" "PostgreSQL ($PG_PORT)" "$pg_port_direct"
        printf "  %-30s %-10s\n" "Docker Swarm ($DOCKER_PORT)" "$docker_port_direct"
        printf "  %-30s %-10s\n" "HAProxy Stats ($STATS_PORT)" "$stats_port_direct"
        echo ""
    done
}

# Функция для отображения ссылок на мониторинг
show_monitoring_links() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              Ссылки на мониторинг                              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${GREEN}HAProxy Статистика:${NC}"
    echo -e "  ${BLUE}http://$VIP:$STATS_PORT/stats${NC} (через VIP)"
    echo -e "  ${BLUE}http://${HAPROXY_IPS[0]}:$STATS_PORT/stats${NC} (HAProxy 1)"
    echo -e "  ${BLUE}http://${HAPROXY_IPS[1]}:$STATS_PORT/stats${NC} (HAProxy 2)"
    echo -e "  Логин: $STATS_USER"
    echo -e "  Пароль: $STATS_PASS"
    echo ""
}

# Главное меню
show_menu() {
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     Скрипт проверки HAProxy и Keepalived                     ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${BLUE}Выберите опцию:${NC}"
    echo "  1. Статус HAProxy узлов"
    echo "  2. IP адреса Keepalived"
    echo "  3. Статус серверов в HAProxy"
    echo "  4. Проверка балансировки PostgreSQL"
    echo "  5. Проверка портов"
    echo "  6. Ссылки на мониторинг"
    echo "  7. Полная проверка (все вышеперечисленное)"
    echo "  0. Выход"
    echo -n "Ваш выбор: "
}

# Главная функция
main() {
    if [ "$1" = "--full" ] || [ "$1" = "-f" ]; then
        show_haproxy_nodes
        show_keepalived_ips
        show_haproxy_servers
        check_postgresql_balancing
        check_ports
        show_monitoring_links
        exit 0
    fi
    
    if [ "$1" = "--nodes" ] || [ "$1" = "-n" ]; then
        show_haproxy_nodes
        exit 0
    fi
    
    if [ "$1" = "--ips" ] || [ "$1" = "-i" ]; then
        show_keepalived_ips
        exit 0
    fi
    
    if [ "$1" = "--servers" ] || [ "$1" = "-s" ]; then
        show_haproxy_servers
        exit 0
    fi
    
    if [ "$1" = "--balance" ] || [ "$1" = "-b" ]; then
        check_postgresql_balancing
        exit 0
    fi
    
    if [ "$1" = "--ports" ] || [ "$1" = "-p" ]; then
        check_ports
        exit 0
    fi
    
    if [ "$1" = "--links" ] || [ "$1" = "-l" ]; then
        show_monitoring_links
        exit 0
    fi
    
    # Интерактивное меню
    while true; do
        show_menu
        read -r choice
        case $choice in
            1)
                show_haproxy_nodes
                ;;
            2)
                show_keepalived_ips
                ;;
            3)
                show_haproxy_servers
                ;;
            4)
                check_postgresql_balancing
                ;;
            5)
                check_ports
                ;;
            6)
                show_monitoring_links
                ;;
            7)
                show_haproxy_nodes
                show_keepalived_ips
                show_haproxy_servers
                check_postgresql_balancing
                check_ports
                show_monitoring_links
                ;;
            0)
                echo "Выход..."
                exit 0
                ;;
            *)
                echo -e "${RED}Неверный выбор${NC}"
                ;;
        esac
        echo ""
        echo "Нажмите Enter для продолжения..."
        read -r
    done
}

# Запуск скрипта
main "$@"

