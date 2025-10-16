# Техническая документация MySQL InnoDB Cluster

## Архитектура кластера

### Обзор системы
MySQL InnoDB Cluster представляет собой высокодоступное решение на основе Group Replication, обеспечивающее автоматическую отказоустойчивость и синхронную репликацию данных между узлами кластера.

### Компоненты кластера

#### 1. Group Replication
- **Назначение**: Основа кластера, обеспечивающая синхронную репликацию
- **Принцип работы**: Каждая транзакция реплицируется на все узлы кластера
- **Консенсус**: Использует алгоритм Paxos для достижения консенсуса между узлами

#### 2. MySQL Router (не используется в данной реализации)
- **Назначение**: Балансировщик нагрузки и точка входа в кластер
- **Статус**: Не развернут, подключение напрямую к узлам

#### 3. MySQL Shell (не используется)
- **Назначение**: Управление кластером через JavaScript/Python API
- **Статус**: Не установлен, управление через стандартные SQL команды

## Конфигурация инфраструктуры

### Terraform конфигурация

#### main.tf
```hcl
provider "yandex" {
  zone      = "ru-central1-a"
  folder_id = "b1gr66gumfmr5ua86ol9"
}
```

**Назначение**: Определяет провайдера Yandex Cloud с указанием зоны и папки проекта.

#### Ресурсы ВМ
```hcl
resource "yandex_compute_instance" "mysql_node_1" {
  name        = "mysql-node-1"
  platform_id = "standard-v2"
  zone        = "ru-central1-a"
  
  resources {
    cores  = 2
    memory = 4
  }
}
```

**Параметры**:
- **Платформа**: standard-v2 (оптимальная для баз данных)
- **CPU**: 2 ядра (достаточно для тестового кластера)
- **RAM**: 4GB (минимум для MySQL InnoDB Cluster)
- **Диск**: 20GB SSD (достаточно для тестовых данных)

#### Сетевая конфигурация
```hcl
resource "yandex_vpc_network" "mysql_network" {
  name = "mysql-cluster-network"
}

resource "yandex_vpc_subnet" "mysql_subnet" {
  name           = "mysql-cluster-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mysql_network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}
```

**Назначение**:
- **Сеть**: Изолированная сеть для кластера
- **Подсеть**: 192.168.10.0/24 (256 IP адресов)
- **NAT**: Внешний доступ для управления

### Cloud-init конфигурация

#### meta_mysql_node.yaml
```yaml
#cloud-config
users:
  - name: ubuntu
    ssh_authorized_keys:
      - ${ssh_public_key}

runcmd:
  - apt-get update
  - apt-get install -y mysql-server
```

**Этапы инициализации**:

1. **Обновление системы**: `apt-get update`
2. **Установка MySQL**: `apt-get install -y mysql-server`
3. **Конфигурация MySQL**: Создание файла конфигурации InnoDB Cluster
4. **Настройка репликации**: Создание пользователя репликации
5. **Запуск сервиса**: `systemctl start mysql`

## Конфигурация MySQL InnoDB Cluster

### Основные параметры Group Replication

#### server_id
```ini
server_id=${node_id}
```
**Назначение**: Уникальный идентификатор сервера в кластере
**Значения**: 1, 2, 3 для каждой ноды соответственно

#### GTID (Global Transaction Identifier)
```ini
gtid_mode=ON
enforce_gtid_consistency=ON
```
**Назначение**: Обеспечивает уникальную идентификацию транзакций
**Преимущества**: Безопасная репликация, простое восстановление

#### Binary Logging
```ini
binlog_checksum=NONE
log_bin=binlog
log_slave_updates=ON
binlog_format=ROW
```
**Назначение**: Логирование изменений для репликации
**Формат ROW**: Более безопасный, реплицирует изменения строк

#### Group Replication настройки
```ini
transaction_write_set_extraction=XXHASH64
loose-group_replication_group_name="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
loose-group_replication_start_on_boot=off
loose-group_replication_local_address="__INTERNAL_IP__:33061"
loose-group_replication_group_seeds="192.168.10.4:33061,192.168.10.18:33061,192.168.10.9:33061"
loose-group_replication_bootstrap_group=off
loose-group_replication_single_primary_mode=on
loose-group_replication_enforce_update_everywhere_checks=off
```

**Параметры**:
- **group_name**: Уникальный идентификатор группы
- **local_address**: IP:порт для Group Replication (33061)
- **group_seeds**: Список всех узлов кластера
- **single_primary_mode**: Только один PRIMARY узел
- **bootstrap_group**: Автоматический запуск кластера

### InnoDB настройки
```ini
innodb_buffer_pool_size=1G
innodb_log_file_size=256M
innodb_log_buffer_size=16M
innodb_flush_log_at_trx_commit=2
innodb_file_per_table=1
```

**Оптимизация**:
- **buffer_pool_size**: 1GB (25% от RAM)
- **log_file_size**: 256MB (оптимально для репликации)
- **flush_log_at_trx_commit=2**: Баланс производительности и надежности

### Сетевая конфигурация
```ini
bind-address=0.0.0.0
```
**Назначение**: MySQL слушает на всех интерфейсах
**Безопасность**: Ограничено внутренней сетью кластера

## Процесс развертывания

### Этап 1: Создание инфраструктуры
```bash
terraform init
terraform plan
terraform apply
```

**Результат**: 3 ВМ с настроенной сетью

### Этап 2: Инициализация MySQL
```bash
# Cloud-init выполняет:
systemctl stop mysql
# Создание конфигурации
systemctl start mysql
```

**Результат**: MySQL установлен и настроен

### Этап 3: Настройка кластера
```bash
# На PRIMARY ноде (mysql-node-1)
mysql -e "SET GLOBAL group_replication_bootstrap_group=ON;"
mysql -e "START GROUP_REPLICATION;"
mysql -e "SET GLOBAL group_replication_bootstrap_group=OFF;"
```

**Результат**: Создан кластер с PRIMARY нодой

### Этап 4: Добавление SECONDARY нод
```bash
# На каждой SECONDARY ноде
mysql -e "START GROUP_REPLICATION;"
```

**Результат**: Полный кластер с репликацией

## Файловая структура на нодах кластера

### Основные директории MySQL
```
/var/lib/mysql/                    # Основная директория данных MySQL
├── mysql/                         # Системные таблицы
├── performance_schema/            # Таблицы мониторинга
├── sys/                          # Системные представления
├── testdb/                       # Тестовая база данных
├── mysql-bin.000001             # Binary log файлы
├── mysql-bin.index              # Индекс binary log файлов
├── ib_logfile0                  # InnoDB log файлы
├── ib_logfile1
├── ibdata1                      # InnoDB системные таблицы
└── auto.cnf                     # Автоматически сгенерированная конфигурация
```

### Конфигурационные файлы
```
/etc/mysql/
├── mysql.conf.d/
│   ├── mysqld.cnf               # Основная конфигурация MySQL
│   └── innodb-cluster.cnf       # Конфигурация InnoDB Cluster
├── debian.cnf                   # Конфигурация для debian-sys-maint
└── debian-start                 # Скрипт запуска для Debian
```

### Логи
```
/var/log/mysql/
├── error.log                    # Основной лог ошибок MySQL
├── mysql-slow.log              # Лог медленных запросов
└── mysql.log                   # Общий лог MySQL
```

### Системные логи
```
/var/log/
├── syslog                       # Системный лог
├── auth.log                    # Лог аутентификации
└── cloud-init-output.log       # Лог cloud-init
```

### Скрипты мониторинга
```
/usr/local/bin/
└── cluster-status.sh           # Скрипт проверки статуса кластера
```

### Временные файлы
```
/tmp/
├── mysql.sock                  # Unix socket для подключений
└── mysql.sock.lock             # Блокировка socket файла
```

### PID файлы
```
/var/run/mysqld/
├── mysqld.pid                  # PID файл процесса MySQL
└── mysqld.sock                 # Socket файл для подключений
```

## Мониторинг и управление

### Проверка статуса кластера
```sql
SELECT * FROM performance_schema.replication_group_members;
```

**Возможные состояния**:
- **ONLINE**: Узел активен и синхронизирован
- **RECOVERING**: Узел восстанавливается
- **OFFLINE**: Узел отключен
- **ERROR**: Ошибка на узле

### Проверка репликации
```sql
SHOW STATUS LIKE 'group_replication%';
```

**Ключевые метрики**:
- **group_replication_primary_member**: ID PRIMARY узла
- **group_replication_member_count**: Количество узлов
- **group_replication_group_name**: Имя группы

### Мониторинг производительности
```sql
SELECT * FROM performance_schema.replication_group_member_stats;
```

## Отказоустойчивость

### Типы отказов

#### 1. Отказ PRIMARY узла
**Поведение**: Остальные узлы остаются в состоянии RECOVERING
**Восстановление**: Требуется ручной перезапуск PRIMARY
**Данные**: Сохраняются на всех узлах

#### 2. Отказ SECONDARY узла
**Поведение**: Кластер продолжает работать
**Восстановление**: Автоматическое при перезапуске
**Данные**: Реплицируются при восстановлении

#### 3. Сетевой разрыв
**Поведение**: Узлы изолируются
**Восстановление**: Автоматическое при восстановлении связи
**Данные**: Синхронизируются при восстановлении

### Стратегии восстановления

#### Автоматическое восстановление
- Перезапуск MySQL сервиса
- Автоматическое подключение к кластеру
- Синхронизация данных

#### Ручное восстановление
- Очистка данных на проблемном узле
- Перезапуск Group Replication
- Проверка статуса кластера

## Безопасность

### Аутентификация
```sql
CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'replpass';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
```

**Пользователь репликации**:
- **Имя**: repl
- **Пароль**: replpass
- **Привилегии**: REPLICATION SLAVE
- **Аутентификация**: mysql_native_password

### Сетевая безопасность
- **Внутренняя сеть**: 192.168.10.0/24
- **NAT**: Внешний доступ только для управления
- **Порты**: 3306 (MySQL), 33061 (Group Replication)

## Производительность

### Оптимизация для кластера
- **InnoDB Buffer Pool**: 1GB (25% от RAM)
- **Binary Log**: ROW формат
- **GTID**: Включен для безопасности
- **Network**: Внутренняя сеть для репликации

### Мониторинг производительности
```sql
-- Статистика репликации
SELECT * FROM performance_schema.replication_group_member_stats;

-- Статистика InnoDB
SHOW ENGINE INNODB STATUS;

-- Статистика соединений
SHOW STATUS LIKE 'Connections';
```

## Резервное копирование

### Стратегия бэкапов
1. **Полный бэкап**: mysqldump всей базы
2. **Инкрементальный**: Binary log файлы
3. **Точка восстановления**: GTID координаты

### Команды бэкапа
```bash
# Полный бэкап
mysqldump --single-transaction --routines --triggers testdb > backup.sql

# Инкрементальный бэкап
mysqlbinlog mysql-bin.000001 > incremental.sql
```

## Масштабирование

### Горизонтальное масштабирование
- Добавление новых узлов в кластер
- Обновление group_seeds конфигурации
- Перезапуск Group Replication

### Вертикальное масштабирование
- Увеличение CPU/RAM на узлах
- Оптимизация InnoDB параметров
- Настройка мониторинга

## Устранение неполадок

### Частые проблемы

#### 1. Ошибка "server is not configured properly"
**Причина**: Конфликт транзакций
**Решение**: Очистка данных и перезапуск

#### 2. Ошибка "Authentication requires secure connection"
**Причина**: Неправильная аутентификация
**Решение**: Использование mysql_native_password

#### 3. Ошибка "Can't connect to MySQL server"
**Причина**: Неправильный bind-address
**Решение**: Установка bind-address=0.0.0.0

### Логи для диагностики
```bash
# Логи MySQL
tail -f /var/log/mysql/error.log

# Логи Group Replication
mysql -e "SHOW STATUS LIKE 'group_replication%';"

# Логи системы
journalctl -u mysql -f

# Логи cloud-init
tail -f /var/log/cloud-init-output.log
```

### Команды для работы с файлами
```bash
# Проверка размера данных MySQL
du -sh /var/lib/mysql/

# Проверка binary log файлов
ls -la /var/lib/mysql/mysql-bin.*

# Проверка конфигурации
cat /etc/mysql/mysql.conf.d/innodb-cluster.cnf

# Проверка PID процесса
cat /var/run/mysqld/mysqld.pid

# Проверка socket файлов
ls -la /var/run/mysqld/

# Проверка прав доступа
ls -la /var/lib/mysql/
```

## Заключение

MySQL InnoDB Cluster обеспечивает:
- **Высокую доступность**: Автоматическое восстановление
- **Консистентность данных**: Синхронная репликация
- **Масштабируемость**: Легкое добавление узлов
- **Мониторинг**: Встроенные инструменты

Кластер готов для использования в продакшене с дополнительной настройкой мониторинга и резервного копирования.
