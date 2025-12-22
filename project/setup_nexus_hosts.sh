#!/bin/bash
#######################################################################
# Скрипт для настройки /etc/hosts для nexus.netlab.local на всех Docker нодах
#
# Использование:
#   ./setup_nexus_hosts.sh [NEXUS_IP]
#
# Примеры:
#   ./setup_nexus_hosts.sh 192.168.50.1
#   ./setup_nexus_hosts.sh 10.0.0.100
#
# Если IP не указан, используется 192.168.50.1 (шлюз по умолчанию)

set -e

# IP адрес Nexus (по умолчанию - шлюз)
NEXUS_IP="${1:-192.168.50.1}"
NEXUS_HOST="nexus.netlab.local"

# Docker ноды
DOCKER_NODES=(105 106 107 108)

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Настройка /etc/hosts для nexus.netlab.local                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "IP адрес Nexus: $NEXUS_IP"
echo ""

for ct in "${DOCKER_NODES[@]}"; do
    echo "=== CT $ct ==="
    
    # Проверяем, существует ли уже запись
    if pct exec $ct -- grep -q "$NEXUS_HOST" /etc/hosts 2>/dev/null; then
        echo "  Запись уже существует, обновляю..."
        # Удаляем старую запись
        pct exec $ct -- sed -i "/$NEXUS_HOST/d" /etc/hosts
    fi
    
    # Добавляем новую запись
    pct exec $ct -- bash -c "echo '$NEXUS_IP $NEXUS_HOST' >> /etc/hosts" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Запись добавлена: $NEXUS_IP $NEXUS_HOST"
        
        # Проверяем разрешение имени
        if pct exec $ct -- ping -c 1 -W 1 $NEXUS_HOST >/dev/null 2>&1; then
            echo "  ✓ Имя успешно разрешается"
        else
            echo "  ⚠ Имя добавлено, но ping не проходит (возможно, неправильный IP)"
        fi
    else
        echo "  ✗ Ошибка добавления записи"
    fi
    echo ""
done

echo "✅ Настройка завершена"
echo ""
echo "Проверка на CT 106:"
pct exec 106 -- grep "$NEXUS_HOST" /etc/hosts
echo ""
echo "Тест подключения:"
pct exec 106 -- curl -k -s -I https://$NEXUS_HOST/v2/ 2>&1 | head -3 || echo "  (Проверьте доступность Nexus на $NEXUS_IP)"


