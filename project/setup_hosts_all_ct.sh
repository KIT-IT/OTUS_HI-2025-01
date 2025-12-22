#!/bin/bash

# Скрипт для настройки /etc/hosts во всех контейнерах
# Добавляет записи для всех контейнеров для разрешения имен

echo "=== Настройка /etc/hosts во всех контейнерах ==="
echo ""

# Получаем информацию о всех контейнерах
declare -A CT_HOSTS
CT_HOSTS[100]="ct-haproxy-1.nix.netlab.local:192.168.50.11"
CT_HOSTS[101]="ct-haproxy-2.nix.netlab.local:192.168.50.12"
CT_HOSTS[102]="ct-pg-1.nix.netlab.local:192.168.50.21"
CT_HOSTS[103]="ct-pg-2.nix.netlab.local:192.168.50.22"
CT_HOSTS[104]="ct-pg-3.nix.netlab.local:192.168.50.23"
CT_HOSTS[105]="ct-docker-mgr-1.nix.netlab.local:192.168.50.31"
CT_HOSTS[106]="ct-docker-mgr-2.nix.netlab.local:192.168.50.32"
CT_HOSTS[107]="ct-docker-wkr-1.nix.netlab.local:192.168.50.41"
CT_HOSTS[108]="ct-docker-wkr-2.nix.netlab.local:192.168.50.42"

# Создаем временный файл с записями для всех хостов
TMP_HOSTS=$(mktemp)
echo "# Hosts entries for all containers" > "$TMP_HOSTS"
for ct in "${!CT_HOSTS[@]}"; do
    IFS=':' read -r hostname ip <<< "${CT_HOSTS[$ct]}"
    echo "$ip $hostname $(echo $hostname | cut -d'.' -f1)" >> "$TMP_HOSTS"
done

echo "Содержимое /etc/hosts для добавления:"
cat "$TMP_HOSTS"
echo ""

# Применяем к каждому контейнеру
for ct in "${!CT_HOSTS[@]}"; do
    echo "[$(date +%H:%M:%S)] Обработка CT $ct..."
    
    CONFIG_FILE="/etc/pve/lxc/${ct}.conf"
    
    # Проверяем, существует ли контейнер
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "  CT $ct: ✗ Конфигурационный файл не найден, пропускаем"
        echo ""
        continue
    fi
    
    # Копируем временный файл в контейнер
    pct push $ct "$TMP_HOSTS" /tmp/hosts_entries.txt >/dev/null 2>&1
    
    # Добавляем записи в /etc/hosts, избегая дубликатов
    pct exec $ct -- bash -c "
        # Удаляем старые записи для наших хостов
        sed -i '/ct-.*nix.netlab.local/d' /etc/hosts 2>/dev/null || true
        
        # Добавляем новые записи
        cat /tmp/hosts_entries.txt >> /etc/hosts
        
        # Удаляем временный файл
        rm -f /tmp/hosts_entries.txt
        
        echo '  CT $ct: ✓ /etc/hosts обновлен'
    " 2>&1 | grep -v "^$" || echo "  CT $ct: ✗ Ошибка обновления /etc/hosts"
    
    echo ""
done

# Удаляем временный файл
rm -f "$TMP_HOSTS"

echo "=== Готово ==="
echo ""
echo "Теперь можно использовать имена хостов для ping и других команд."


