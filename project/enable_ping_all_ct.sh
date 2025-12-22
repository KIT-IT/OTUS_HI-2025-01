#!/bin/bash

# Скрипт для проверки и очистки настроек ping во всех контейнерах
# В Proxmox 9.1 ping работает по умолчанию для unprivileged контейнеров
# Неправильные настройки features или lxc.cap.keep могут мешать запуску

echo "=== Проверка настроек ping во всех контейнерах ==="
echo ""

# Список VMID всех контейнеров
CT_IDS=(100 101 102 103 104 105 106 107 108 109 110 111)

for ct in "${CT_IDS[@]}"; do
    echo "[$(date +%H:%M:%S)] Обработка CT $ct..."
    
    CONFIG_FILE="/etc/pve/lxc/${ct}.conf"
    
    # Проверяем, существует ли контейнер
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "  CT $ct: ✗ Конфигурационный файл не найден, пропускаем"
        echo ""
        continue
    fi
    
    # Удаляем неправильные настройки, которые могут мешать запуску
    REMOVED=0
    if grep -q "^features:" "$CONFIG_FILE"; then
        sed -i '/^features:/d' "$CONFIG_FILE"
        REMOVED=1
    fi
    if grep -q "^lxc.cap" "$CONFIG_FILE"; then
        sed -i '/^lxc.cap/d' "$CONFIG_FILE"
        REMOVED=1
    fi
    
    if [ $REMOVED -eq 1 ]; then
        echo "  CT $ct: ✓ Удалены проблемные настройки (ping работает по умолчанию)"
    else
        echo "  CT $ct: ✓ Настройки в порядке"
    fi
    
    echo ""
done

echo "=== Готово ==="
echo ""
echo "Примечание: В Proxmox 9.1 ping работает по умолчанию для unprivileged контейнеров."
echo "Если ping не работает, проверьте права пользователя внутри контейнера."

