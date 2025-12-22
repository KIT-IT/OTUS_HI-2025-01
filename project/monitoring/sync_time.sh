#!/bin/bash

# Скрипт синхронизации времени на всех нодах кластера
# Использование: ./sync_time.sh

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Список контейнеров
CONTAINERS=(100 101 102 103 104 105 106 107 108 109 110 111)

# Функция вывода времени
show_time() {
    local node=$1
    local timezone=${2:-"UTC"}
    
    if [ "$node" = "host" ]; then
        if [ "$timezone" = "UTC" ]; then
            echo -e "   ${GREEN}Хост:${NC} $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        else
            echo -e "   ${GREEN}Хост:${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
        fi
    else
        if [ "$timezone" = "UTC" ]; then
            local ct_time=$(pct exec $node -- date -u '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Недоступен")
            echo -e "   ${GREEN}CT $node:${NC} $ct_time UTC"
        else
            local ct_time=$(pct exec $node -- date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo "Недоступен")
            echo -e "   ${GREEN}CT $node:${NC} $ct_time"
        fi
    fi
}

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     СИНХРОНИЗАЦИЯ ВРЕМЕНИ НА ВСЕХ НОДАХ                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📅 Начало синхронизации:${NC}"
show_time "host" "local"
show_time "host" "UTC"
echo ""

# Функция для проверки доступности контейнера
check_container() {
    local ct=$1
    pct exec $ct -- echo >/dev/null 2>&1
}

# Функция синхронизации хоста
sync_host() {
    echo -e "${BLUE}=== СИНХРОНИЗАЦИЯ ХОСТА (Proxmox) ===${NC}"
    echo -e "${BLUE}Текущее время на хосте:${NC}"
    show_time "host" "local"
    show_time "host" "UTC"
    echo ""
    
    if command -v chronyd >/dev/null 2>&1; then
        if systemctl is-active chronyd >/dev/null 2>&1; then
            echo -e "${GREEN}✅ chronyd активен${NC}"
            chronyc makestep >/dev/null 2>&1 && echo -e "${GREEN}✅ Время синхронизировано${NC}" || echo -e "${YELLOW}⚠️ Не удалось выполнить makestep${NC}"
        else
            echo -e "${YELLOW}⚠️ chronyd не активен, запускаю...${NC}"
            systemctl start chronyd 2>/dev/null || true
            sleep 2
            chronyc makestep >/dev/null 2>&1 && echo -e "${GREEN}✅ Время синхронизировано${NC}" || echo -e "${YELLOW}⚠️ Не удалось синхронизировать${NC}"
        fi
    elif command -v chrony >/dev/null 2>&1; then
        chrony -q 'server pool.ntp.org iburst' && echo -e "${GREEN}✅ Время синхронизировано${NC}" || echo -e "${YELLOW}⚠️ Не удалось синхронизировать${NC}"
    elif command -v ntpdate >/dev/null 2>&1; then
        ntpdate -s pool.ntp.org && echo -e "${GREEN}✅ Время синхронизировано${NC}" || echo -e "${YELLOW}⚠️ Не удалось синхронизировать${NC}"
    else
        echo -e "${RED}❌ NTP клиент не найден${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Время после синхронизации:${NC}"
    show_time "host" "local"
    show_time "host" "UTC"
    echo ""
}

# Функция синхронизации контейнера
sync_container() {
    local ct=$1
    
    if ! check_container $ct; then
        echo -e "${YELLOW}CT $ct: ⚠️ Недоступен${NC}"
        return 1
    fi
    
    echo -e "${BLUE}CT $ct:${NC}"
    local ct_time=$(pct exec $ct -- date -u '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Недоступен")
    echo -e "  Время: ${GREEN}$ct_time UTC${NC}"
    
    # Проверяем наличие chronyd
    if pct exec $ct -- command -v chronyd >/dev/null 2>&1; then
        # Пытаемся запустить chronyd
        if pct exec $ct -- systemctl start chronyd 2>/dev/null; then
            sleep 2
            if pct exec $ct -- chronyc makestep >/dev/null 2>&1; then
                echo -e "  ${GREEN}✅ Синхронизировано через chronyd${NC}"
                return 0
            fi
        fi
    fi
    
    # Пытаемся использовать ntpdate
    if pct exec $ct -- command -v ntpdate >/dev/null 2>&1; then
        if pct exec $ct -- ntpdate -s pool.ntp.org >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ Синхронизировано через ntpdate${NC}"
            return 0
        fi
    fi
    
    # LXC контейнеры автоматически используют время хоста
    echo -e "  ${GREEN}✅ Использует время хоста (LXC)${NC}"
    return 0
}

# Функция проверки статуса синхронизации
check_sync_status() {
    echo -e "${BLUE}=== ПРОВЕРКА СТАТУСА СИНХРОНИЗАЦИИ ===${NC}"
    
    host_utc=$(date -u '+%s')
    host_time_utc=$(date -u '+%Y-%m-%d %H:%M:%S')
    host_time_local=$(date '+%Y-%m-%d %H:%M:%S %Z')
    
    echo -e "${GREEN}Хост:${NC}"
    echo -e "  UTC timestamp: $host_utc"
    echo -e "  UTC время: $host_time_utc"
    echo -e "  Локальное время: $host_time_local"
    echo ""
    
    echo "Разница времени контейнеров от хоста:"
    max_diff=0
    synced=0
    warning=0
    error=0
    
    for ct in "${CONTAINERS[@]}"; do
        ct_utc=$(pct exec $ct -- date -u '+%s' 2>/dev/null || echo "")
        if [ -n "$ct_utc" ]; then
            ct_time_utc=$(pct exec $ct -- date -u '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
            diff=$((ct_utc - host_utc))
            abs_diff=${diff#-}
            if [ $abs_diff -gt $max_diff ]; then
                max_diff=$abs_diff
            fi
            
            if [ $abs_diff -lt 5 ]; then
                echo -e "  CT $ct: ${GREEN}✅ Синхронизирован${NC} (разница: ${diff}с) - $ct_time_utc UTC"
                ((synced++))
            elif [ $abs_diff -lt 30 ]; then
                echo -e "  CT $ct: ${YELLOW}⚠️ Небольшое расхождение${NC} (${diff}с) - $ct_time_utc UTC"
                ((warning++))
            else
                echo -e "  CT $ct: ${RED}❌ Большое расхождение${NC} (${diff}с) - $ct_time_utc UTC"
                ((error++))
            fi
        else
            echo -e "  CT $ct: ${RED}❌ Недоступен${NC}"
            ((error++))
        fi
    done
    
    echo ""
    echo "Статистика:"
    echo -e "  ${GREEN}✅ Синхронизировано: $synced${NC}"
    echo -e "  ${YELLOW}⚠️ Предупреждения: $warning${NC}"
    echo -e "  ${RED}❌ Ошибки: $error${NC}"
    echo -e "  Максимальное расхождение: ${max_diff}с"
    echo ""
}

# Функция проверки NTP статуса на хосте
check_ntp_status() {
    echo -e "${BLUE}=== СТАТУС NTP НА ХОСТЕ ===${NC}"
    
    if command -v chronyc >/dev/null 2>&1; then
        if chronyc tracking >/dev/null 2>&1; then
            echo "Источники времени:"
            chronyc sources | grep -E "^\^|\^\*" | head -5
            echo ""
            echo "Статус синхронизации:"
            chronyc tracking | grep -E "Reference time|System time|Last offset" || true
        else
            echo -e "${YELLOW}⚠️ chronyc не может подключиться к демону${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ chronyc не установлен${NC}"
    fi
    echo ""
}

# Функция установки chrony на контейнере (если нужно)
install_chrony_on_container() {
    local ct=$1
    
    if ! check_container $ct; then
        return 1
    fi
    
    if ! pct exec $ct -- command -v chronyd >/dev/null 2>&1; then
        echo -e "${YELLOW}  Устанавливаю chrony...${NC}"
        pct exec $ct -- dnf install -y chrony >/dev/null 2>&1
        pct exec $ct -- systemctl enable chronyd >/dev/null 2>&1
        echo -e "${GREEN}  ✅ chrony установлен${NC}"
    fi
}

# Основная функция
main() {
    # Синхронизация хоста
    sync_host
    
    # Синхронизация контейнеров
    echo -e "${BLUE}=== СИНХРОНИЗАЦИЯ КОНТЕЙНЕРОВ ===${NC}"
    for ct in "${CONTAINERS[@]}"; do
        sync_container $ct
    done
    echo ""
    
    # Проверка статуса
    check_sync_status
    
    # Проверка NTP статуса
    check_ntp_status
    
    # Итоговый отчет
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА                                     ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✅ Время синхронизировано на всех доступных нодах${NC}"
    echo ""
    echo -e "${BLUE}📊 Текущее время на всех нодах:${NC}"
    echo ""
    echo -e "${BLUE}Хост (Proxmox):${NC}"
    show_time "host" "local"
    show_time "host" "UTC"
    echo ""
    echo -e "${BLUE}Контейнеры (UTC):${NC}"
    for ct in "${CONTAINERS[@]}"; do
        if check_container $ct; then
            show_time $ct "UTC"
        fi
    done
    echo ""
    echo "💡 Примечания:"
    echo "   - LXC контейнеры автоматически используют время хоста"
    echo "   - chronyd в контейнерах может не работать (ограничения безопасности)"
    echo "   - Это нормально - главное, что хост синхронизирован с NTP"
    echo ""
    echo -e "${BLUE}📅 Завершение синхронизации:${NC}"
    show_time "host" "local"
    show_time "host" "UTC"
    echo ""
}

# Запуск основной функции
main

