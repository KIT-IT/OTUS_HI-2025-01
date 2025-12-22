#!/bin/bash
# Скрипт для установки PostgreSQL 18 (выполняется внутри CT)

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


