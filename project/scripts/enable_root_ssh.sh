#!/bin/bash
# Скрипт для включения входа root по SSH во всех контейнерах

echo "=== Включение SSH входа для root ==="
echo ""

for ct in 100 101 102 103 104 105 106 107 108 109; do
    echo "Обработка CT $ct..."
    
    # Войти в контейнер и настроить SSH
    pct enter $ct << 'EOF'
# Создать резервную копию конфигурации
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Разрешить вход root
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Убедиться, что парольная аутентификация включена
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Если строк нет, добавить их
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# Перезапустить SSH
systemctl restart sshd

# Проверить статус
echo "Проверка настроек:"
grep -E "^PermitRootLogin|^PasswordAuthentication" /etc/ssh/sshd_config | grep -v "^#"
EOF
    
    echo "  CT $ct: ✓ Настроено"
    echo ""
done

echo "=== Готово ==="






