#!/bin/bash

# Проверка пользователя - для sedunovsv не используем sudo
# Если мы уже root, sudo не нужен
if [ "$USER" = "sedunovsv" ] || [ "$EUID" -eq 0 ]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi
# Скрипт для создания пользователя sedunovsv на всех контейнерах

USER_NAME="sedunovsv"
USER_PASSWORD="sedunovsv"

echo "=== Создание пользователя $USER_NAME на всех контейнерах ==="
echo ""

# Список VMID всех контейнеров
CT_IDS=(100 101 102 103 104 105 106 107 108 109 110 111)

for ct in "${CT_IDS[@]}"; do
    echo "[$(date +%H:%M:%S)] Обработка CT $ct..."
    
    # Проверяем, существует ли контейнер
    # Используем pct config для проверки - это более надежный способ
    if ! $SUDO_CMD pct config $ct >/dev/null 2>&1; then
        echo "  CT $ct: ✗ Контейнер не существует, пропускаем"
        echo ""
        continue
    fi
    
    # Проверяем, запущен ли контейнер
    if [ "$($SUDO_CMD pct status $ct | awk '{print $2}')" != "running" ]; then
        echo "  CT $ct: Запускаю контейнер..."
        $SUDO_CMD pct start $ct >/dev/null 2>&1
        sleep 2
    fi
    
    # Создаем пользователя и настраиваем sudo без пароля
    $SUDO_CMD pct exec $ct -- bash -c "
        if ! id -u $USER_NAME >/dev/null 2>&1; then
            useradd -m -s /bin/bash $USER_NAME
            echo '$USER_NAME:$USER_PASSWORD' | chpasswd
            usermod -aG wheel $USER_NAME
            echo '  CT $ct: ✓ Пользователь $USER_NAME создан'
        else
            echo '$USER_NAME:$USER_PASSWORD' | chpasswd
            usermod -aG wheel $USER_NAME 2>/dev/null || true
            echo '  CT $ct: ✓ Пользователь $USER_NAME уже существует, пароль обновлен'
        fi
        
        # Настраиваем sudo без пароля для sedunovsv
        if [ -d /etc/sudoers.d ]; then
            echo '$USER_NAME ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/$USER_NAME
            chmod 440 /etc/sudoers.d/$USER_NAME
            echo '  CT $ct: ✓ Sudo без пароля настроен для $USER_NAME'
        else
            # Если директории нет, добавляем в основной sudoers
            if ! grep -q \"^$USER_NAME.*NOPASSWD\" /etc/sudoers 2>/dev/null; then
                echo '$USER_NAME ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
                echo '  CT $ct: ✓ Sudo без пароля настроен для $USER_NAME (в /etc/sudoers)'
            fi
        fi
    " 2>&1 | grep -v "^$" || echo "  CT $ct: ✗ Ошибка создания пользователя"
    
    echo ""
done

echo "=== Готово ==="

