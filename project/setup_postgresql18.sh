#!/bin/bash
# Скрипт для установки и настройки PostgreSQL 18 на CT

# Укажите номер CT для PostgreSQL
CT_ID=${1:-102}  # По умолчанию CT 102, можно указать как аргумент: ./setup_postgresql18.sh 102

echo "=== Установка PostgreSQL 18 на CT $CT_ID ==="
echo ""

# Проверка существования CT
if ! pct status $CT_ID >/dev/null 2>&1; then
    echo "Ошибка: CT $CT_ID не найден"
    exit 1
fi

echo "[$(date +%H:%M:%S)] Начинаю установку PostgreSQL 18 в CT $CT_ID..."

# Установка PostgreSQL 18 через официальный репозиторий
pct exec $CT_ID << 'EOF'
# Обновление системы
dnf update -y

# Установка необходимых пакетов
dnf install -y wget curl

# Добавление официального репозитория PostgreSQL 18
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Установка PostgreSQL 18 сервера и клиента
dnf install -y postgresql18-server postgresql18

# Инициализация базы данных
/usr/pgsql-18/bin/postgresql-18-setup initdb

# Включение и запуск PostgreSQL
systemctl enable postgresql-18
systemctl start postgresql-18

# Ожидание запуска PostgreSQL
sleep 3

# Проверка статуса
systemctl status postgresql-18 --no-pager -l

# Проверка версии
/usr/pgsql-18/bin/psql --version

echo ""
echo "PostgreSQL 18 установлен и запущен"
EOF

# Получение IP адреса CT
CT_IP=$(grep "net0.*ip=" /etc/pve/lxc/$CT_ID.conf 2>/dev/null | sed 's/.*ip=\([^,]*\).*/\1/' | cut -d/ -f1)

echo ""
echo "=== Настройка PostgreSQL ==="
echo ""

# Настройка PostgreSQL для удаленного доступа
pct exec $CT_ID << 'EOF'
# Создание резервной копии конфигурации
cp /var/lib/pgsql/18/data/postgresql.conf /var/lib/pgsql/18/data/postgresql.conf.backup
cp /var/lib/pgsql/18/data/pg_hba.conf /var/lib/pgsql/18/data/pg_hba.conf.backup

# Настройка postgresql.conf для прослушивания всех интерфейсов
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/18/data/postgresql.conf

# Настройка pg_hba.conf для разрешения подключений из сети
echo "" >> /var/lib/pgsql/18/data/pg_hba.conf
echo "# Разрешить подключения из локальной сети" >> /var/lib/pgsql/18/data/pg_hba.conf
echo "host    all             all             192.168.50.0/24         md5" >> /var/lib/pgsql/18/data/pg_hba.conf

# Перезапуск PostgreSQL для применения изменений
systemctl restart postgresql-18

# Ожидание перезапуска
sleep 3

echo "PostgreSQL настроен для удаленного доступа"
EOF

# Настройка пользователей и паролей
echo ""
echo "=== Настройка пользователей PostgreSQL ==="
echo ""

# Установка пароля для postgres и создание пользователя sqlUser
pct exec $CT_ID << 'EOF'
# Установка пароля для пользователя postgres
sudo -u postgres psql << SQL
-- Установка пароля для postgres (можно изменить позже)
ALTER USER postgres WITH PASSWORD 'Qwe1234!';

-- Создание пользователя sqlUser
CREATE USER sqlUser WITH PASSWORD 'Qwe1234!';

-- Предоставление прав на создание баз данных
ALTER USER sqlUser CREATEDB;

-- Создание базы данных для sqlUser
CREATE DATABASE sqluser_db OWNER sqlUser;

-- Предоставление всех привилегий на базу данных
GRANT ALL PRIVILEGES ON DATABASE sqluser_db TO sqlUser;

\q
SQL

echo "Пользователь sqlUser создан с паролем Qwe1234!"
echo "База данных sqluser_db создана и назначена пользователю sqlUser"
EOF

# Проверка подключения
echo ""
echo "=== Проверка установки ==="
pct exec $CT_ID -- systemctl is-active postgresql-18 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ PostgreSQL 18 запущен"
else
    echo "✗ Ошибка: PostgreSQL 18 не запущен"
fi

# Проверка порта
if [ -n "$CT_IP" ]; then
    echo -n "Проверка порта 5432 на $CT_IP: "
    timeout 2 nc -zv $CT_IP 5432 >/dev/null 2>&1 && echo "✓ Порт открыт" || echo "✗ Порт закрыт (возможно, требуется настройка firewall)"
fi

# Тест подключения с новым пользователем
echo ""
echo "=== Тест подключения ==="
pct exec $CT_ID -- sudo -u postgres psql -U sqlUser -d sqluser_db -c "SELECT version();" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Подключение пользователя sqlUser работает"
else
    echo "⚠ Проверьте подключение вручную"
fi

echo ""
echo "=== Информация о подключении ==="
echo "CT ID: $CT_ID"
if [ -n "$CT_IP" ]; then
    echo "IP адрес: $CT_IP"
fi
echo "Порт: 5432"
echo ""
echo "Пользователи:"
echo "  - postgres (пароль: Qwe1234!)"
echo "  - sqlUser (пароль: Qwe1234!)"
echo ""
echo "База данных: sqluser_db (владелец: sqlUser)"
echo ""
echo "Подключение с пользователем sqlUser:"
echo "  psql -h $CT_IP -U sqlUser -d sqluser_db"
echo ""
echo "Подключение с пользователем postgres:"
echo "  psql -h $CT_IP -U postgres -d postgres"
echo ""
echo "Подключение из контейнера:"
echo "  pct exec $CT_ID -- sudo -u postgres psql -U sqlUser -d sqluser_db"
echo ""
echo "=== Готово ==="


