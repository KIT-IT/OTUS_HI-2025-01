#!/bin/bash
# Скрипт для установки SSH на всех контейнерах

echo "=== Установка SSH на всех контейнерах ==="
echo ""

for ct in 100 101 102 103 104 105 106 107 108 109; do
    echo "[$(date +%H:%M:%S)] Обработка CT $ct..."
    
    # Проверка, установлен ли уже SSH
    if pct exec $ct -- command -v sshd >/dev/null 2>&1; then
        echo "  CT $ct: SSH уже установлен, проверяю статус..."
        pct exec $ct -- systemctl is-active sshd >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "  CT $ct: ✓ SSH уже запущен"
        else
            echo "  CT $ct: Запускаю SSH..."
            pct exec $ct -- systemctl start sshd
            pct exec $ct -- systemctl enable sshd
            echo "  CT $ct: ✓ SSH запущен"
        fi
    else
        echo "  CT $ct: Устанавливаю SSH..."
        pct exec $ct -- dnf install -y openssh-server openssh-clients >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            pct exec $ct -- systemctl enable sshd
            pct exec $ct -- systemctl start sshd
            if pct exec $ct -- systemctl is-active sshd >/dev/null 2>&1; then
                echo "  CT $ct: ✓ SSH установлен и запущен"
            else
                echo "  CT $ct: ✗ Ошибка запуска SSH"
            fi
        else
            echo "  CT $ct: ✗ Ошибка установки SSH"
        fi
    fi
    echo ""
done

echo "=== Проверка SSH портов ==="
for ct in 100 101 102 103 104 105 106 107; do
    ip=$(grep "net0.*ip=" /etc/pve/lxc/$ct.conf 2>/dev/null | sed 's/.*ip=\([^,]*\).*/\1/' | cut -d/ -f1)
    if [ -n "$ip" ]; then
        echo -n "  CT $ct ($ip): "
        timeout 2 nc -zv $ip 22 >/dev/null 2>&1 && echo "✓ Порт 22 открыт" || echo "✗ Порт 22 закрыт"
    fi
done

echo ""
echo "=== Готово ==="






