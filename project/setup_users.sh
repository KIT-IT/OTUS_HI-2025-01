#!/bin/bash
# Скрипт для настройки пользователей PostgreSQL (выполняется внутри CT)

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


