#!/bin/bash
# Скрипт для настройки PostgreSQL (выполняется внутри CT)

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


