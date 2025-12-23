# Руководство по использованию Ceph

## Содержание

1. [Основные концепции](#основные-концепции)
2. [Работа с RBD (RADOS Block Device)](#работа-с-rbd)
3. [Работа с CephFS](#работа-с-cephfs)
4. [Управление пулами](#управление-пулами)
5. [Мониторинг и диагностика](#мониторинг-и-диагностика)
6. [Типичные операции](#типичные-операции)

## Основные концепции

### Что такое Ceph?

Ceph — это распределенная система хранения данных с открытым исходным кодом, которая обеспечивает:
- **RADOS Block Device (RBD)** — блочные устройства для виртуальных машин
- **CephFS** — распределенная файловая система
- **RADOS Gateway (RGW)** — объектное хранилище (S3/Swift совместимое)

### Ключевые компоненты

- **MON (Monitor)** — управляют состоянием кластера и хранят карту кластера
- **OSD (Object Storage Daemon)** — хранят данные объектов
- **MDS (Metadata Server)** — управляют метаданными для CephFS
- **PG (Placement Group)** — логические группы объектов для распределения данных

### Основные понятия

- **Pool (Пул)** — логическое разделение хранилища (аналог namespace)
- **PG (Placement Group)** — группа объектов, распределяемых по OSD
- **Replication Factor** — фактор репликации (количество копий данных)
- **CRUSH** — алгоритм распределения данных по OSD

## Работа с RBD

### Создание RBD образа

```bash
# Создать образ размером 10 GB в пуле rbd
rbd create --size 10240 rbd/myimage

# Создать образ с указанием формата (1 или 2)
rbd create --size 10240 --image-format 2 rbd/myimage

# Создать образ с тонким провизионированием
rbd create --size 10240 --thick-provision rbd/myimage
```

### Просмотр информации об образах

```bash
# Список всех образов в пуле
rbd list rbd

# Детальная информация об образе
rbd info rbd/myimage

# Статус образа
rbd status rbd/myimage
```

### Маппинг RBD образа

```bash
# Маппинг образа в блочное устройство
sudo rbd map rbd/myimage

# Проверка маппинга
rbd showmapped

# Результат будет примерно таким:
# id pool image   snap device
# 0  rbd  myimage -    /dev/rbd0
```

### Форматирование и монтирование

```bash
# Форматирование в ext4
sudo mkfs.ext4 /dev/rbd0

# Создание точки монтирования
sudo mkdir -p /mnt/rbd-myimage

# Монтирование
sudo mount /dev/rbd0 /mnt/rbd-myimage

# Автоматическое монтирование при загрузке (добавить в /etc/fstab)
echo "/dev/rbd0 /mnt/rbd-myimage ext4 defaults,noatime,_netdev 0 2" | sudo tee -a /etc/fstab
```

### Размонтирование и отключение

```bash
# Размонтирование
sudo umount /mnt/rbd-myimage

# Отключение RBD образа
sudo rbd unmap /dev/rbd0
# или
sudo rbd unmap rbd/myimage
```

### Изменение размера образа

```bash
# Увеличение размера до 20 GB
rbd resize --size 20480 rbd/myimage

# После увеличения размера нужно расширить файловую систему
sudo resize2fs /dev/rbd0
```

### Создание снимков (snapshots)

```bash
# Создание снимка
rbd snap create rbd/myimage@snapshot1

# Список снимков
rbd snap list rbd/myimage

# Восстановление из снимка
rbd snap rollback rbd/myimage@snapshot1

# Клонирование из снимка
rbd clone rbd/myimage@snapshot1 rbd/myimage-clone

# Удаление снимка
rbd snap rm rbd/myimage@snapshot1
```

### Удаление образа

```bash
# Удаление образа (сначала нужно отключить)
sudo rbd unmap rbd/myimage
rbd rm rbd/myimage
```

## Работа с CephFS

### Проверка статуса CephFS

```bash
# Статус файловой системы
ceph fs status

# Список файловых систем
ceph fs ls

# Информация о метаданных
ceph mds stat
```

### Монтирование CephFS

#### Способ 1: Через mount (kernel client)

```bash
# Получение ключа администратора
ADMIN_KEY=$(sudo ceph auth get-key client.admin)

# Монтирование
sudo mkdir -p /mnt/cephfs
sudo mount -t ceph mon1:6789,mon2:6789,mon3:6789:/ /mnt/cephfs \
  -o name=admin,secret=$ADMIN_KEY

# Или через файл с ключом
echo $ADMIN_KEY | sudo tee /etc/ceph/admin.secret
sudo mount -t ceph mon1:6789,mon2:6789,mon3:6789:/ /mnt/cephfs \
  -o name=admin,secretfile=/etc/ceph/admin.secret
```

#### Способ 2: Через ceph-fuse (FUSE client)

```bash
# Установка ceph-fuse
sudo apt-get install -y ceph-fuse

# Монтирование
sudo mkdir -p /mnt/cephfs
sudo ceph-fuse -m mon1:6789,mon2:6789,mon3:6789 /mnt/cephfs

# Или с указанием пользователя
sudo ceph-fuse -n client.admin /mnt/cephfs
```

### Автоматическое монтирование CephFS

Добавить в `/etc/fstab`:

```bash
# Для kernel client
mon1:6789,mon2:6789,mon3:6789:/ /mnt/cephfs ceph name=admin,secretfile=/etc/ceph/admin.secret,noatime,_netdev 0 2

# Для FUSE client
id=admin /mnt/cephfs fuse.ceph defaults,_netdev 0 0
```

### Работа с данными в CephFS

```bash
# Создание директорий
sudo mkdir -p /mnt/cephfs/data
sudo mkdir -p /mnt/cephfs/shared

# Установка прав доступа
sudo chown -R user:group /mnt/cephfs/data
sudo chmod 755 /mnt/cephfs/data

# Копирование данных
sudo cp -r /local/data/* /mnt/cephfs/data/

# Проверка использования пространства
df -h /mnt/cephfs
```

### Размонтирование CephFS

```bash
# Для kernel client
sudo umount /mnt/cephfs

# Для FUSE client
sudo fusermount -u /mnt/cephfs
```

## Управление пулами

### Просмотр информации о пулах

```bash
# Список всех пулов
ceph osd pool ls

# Детальная информация о пуле
ceph osd pool get rbd all

# Использование пространства пулами
ceph df detail
```

### Создание пула

```bash
# Создание пула с указанием PG
ceph osd pool create mypool 64 64

# Создание пула с репликацией 3
ceph osd pool create mypool 64 64
ceph osd pool set mypool size 3
ceph osd pool set mypool min_size 2
```

### Изменение параметров пула

```bash
# Изменение количества реплик
ceph osd pool set rbd size 3
ceph osd pool set rbd min_size 2

# Изменение количества PG (осторожно!)
ceph osd pool set rbd pg_num 128
ceph osd pool set rbd pgp_num 128

# Включение/выключение сжатия
ceph osd pool set rbd compression_algorithm snappy
ceph osd pool set rbd compression_mode aggressive
```

### Удаление пула

```bash
# ВНИМАНИЕ: Это удалит все данные в пуле!

# Сначала нужно разрешить удаление пулов
ceph config set mon mon_allow_pool_delete true

# Удаление пула
ceph osd pool delete mypool mypool --yes-i-really-really-mean-it
```

## Мониторинг и диагностика

### Основные команды мониторинга

```bash
# Общий статус кластера
ceph -s

# Статус здоровья
ceph health
ceph health detail

# Использование пространства
ceph df
ceph df detail

# Статус OSD
ceph osd tree
ceph osd df
ceph osd stat

# Статус мониторов
ceph mon stat
ceph mon dump

# Статус PG
ceph pg stat
ceph pg dump
```

### Использование скрипта проверки

```bash
# Запуск скрипта проверки состояния
./scripts/check-ceph-status.sh

# Или с полным путем
bash lesson_36/scripts/check-ceph-status.sh
```

### Просмотр логов

```bash
# Логи монитора
sudo journalctl -u ceph-mon@mon1 -f

# Логи OSD
sudo journalctl -u ceph-osd@0 -f

# Логи MDS
sudo journalctl -u ceph-mds@mds1 -f

# Все логи Ceph
sudo journalctl -u ceph* -f
```

## Типичные операции

### Создание и использование RBD томов на клиентских машинах

```bash
# 1. Установка клиентских пакетов
sudo apt-get update
sudo apt-get install -y ceph-common

# 2. Копирование конфигурации с монитора
scp ubuntu@mon1:/etc/ceph/ceph.conf /etc/ceph/
scp ubuntu@mon1:/etc/ceph/ceph.client.admin.keyring /etc/ceph/

# 3. Создание RBD образа
rbd create --size 1024 rbd/volume1
rbd create --size 2048 rbd/volume2
rbd create --size 512 rbd/volume3

# 4. Маппинг томов
sudo rbd map rbd/volume1
sudo rbd map rbd/volume2
sudo rbd map rbd/volume3

# 5. Форматирование
sudo mkfs.ext4 /dev/rbd0
sudo mkfs.ext4 /dev/rbd1
sudo mkfs.ext4 /dev/rbd2

# 6. Монтирование
sudo mkdir -p /mnt/rbd1 /mnt/rbd2 /mnt/rbd3
sudo mount /dev/rbd0 /mnt/rbd1
sudo mount /dev/rbd1 /mnt/rbd2
sudo mount /dev/rbd2 /mnt/rbd3

# 7. Проверка
df -h | grep rbd
```

### Настройка CephFS на всех клиентах

```bash
# На каждом клиентском узле:

# 1. Установка пакетов
sudo apt-get install -y ceph-fuse

# 2. Копирование конфигурации и ключей
scp ubuntu@mon1:/etc/ceph/ceph.conf /etc/ceph/
scp ubuntu@mon1:/etc/ceph/ceph.client.admin.keyring /etc/ceph/

# 3. Получение ключа администратора
ADMIN_KEY=$(sudo ceph auth get-key client.admin)
echo $ADMIN_KEY | sudo tee /etc/ceph/admin.secret
sudo chmod 600 /etc/ceph/admin.secret

# 4. Монтирование CephFS
sudo mkdir -p /mnt/cephfs
sudo mount -t ceph mon1:6789,mon2:6789,mon3:6789:/ /mnt/cephfs \
  -o name=admin,secretfile=/etc/ceph/admin.secret

# 5. Автоматическое монтирование (добавить в /etc/fstab)
echo "mon1:6789,mon2:6789,mon3:6789:/ /mnt/cephfs ceph name=admin,secretfile=/etc/ceph/admin.secret,noatime,_netdev 0 2" | sudo tee -a /etc/fstab

# 6. Проверка
df -h /mnt/cephfs
```

### Проверка репликации данных

```bash
# Проверка статуса репликации
ceph osd pool get rbd size
ceph osd pool get rbd min_size

# Проверка распределения данных
ceph pg dump | grep -E "^pg_stat|^sum"

# Проверка состояния PG
ceph pg stat
```

### Резервное копирование RBD образа

```bash
# Создание снимка для бэкапа
rbd snap create rbd/myimage@backup-$(date +%Y%m%d)

# Экспорт образа в файл
rbd export rbd/myimage@backup-$(date +%Y%m%d) /backup/myimage-backup.img

# Импорт образа из файла
rbd import /backup/myimage-backup.img rbd/myimage-restored
```

### Оптимизация производительности

```bash
# Настройка количества PG для пула
ceph osd pool set rbd pg_num 128
ceph osd pool set rbd pgp_num 128

# Включение кэширования для RBD
rbd feature enable rbd/myimage exclusive-lock
rbd feature enable rbd/myimage object-map
rbd feature enable rbd/myimage fast-diff
rbd feature enable rbd/myimage deep-flatten

# Настройка сжатия
ceph osd pool set rbd compression_algorithm snappy
ceph osd pool set rbd compression_mode aggressive
```

## Полезные команды

### Быстрая справка

```bash
# Справка по командам
ceph --help
rbd --help

# Справка по конкретной команде
ceph osd --help
rbd create --help
```

### Проверка конфигурации

```bash
# Текущая конфигурация
ceph config dump

# Конфигурация конкретного daemon
ceph config get mon.*
ceph config get osd.*
```

### Управление пользователями и ключами

```bash
# Список пользователей
ceph auth ls

# Создание пользователя для клиента
ceph auth get-or-create client.myuser mon 'allow r' osd 'allow rwx pool=rbd'

# Экспорт ключа пользователя
ceph auth get client.myuser -o /etc/ceph/ceph.client.myuser.keyring

# Удаление пользователя
ceph auth del client.myuser
```

## Примеры использования

### Пример 1: Создание RBD тома для базы данных

```bash
# Создание образа с оптимальными настройками
rbd create --size 20480 --image-format 2 rbd/postgres-data

# Включение функций для производительности
rbd feature enable rbd/postgres-data exclusive-lock
rbd feature enable rbd/postgres-data object-map
rbd feature enable rbd/postgres-data fast-diff

# Маппинг и форматирование
sudo rbd map rbd/postgres-data
sudo mkfs.ext4 /dev/rbd0
sudo mount /dev/rbd0 /var/lib/postgresql/data
```

### Пример 2: Общий доступ к данным через CephFS

```bash
# На сервере 1
echo "Hello from server 1" | sudo tee /mnt/cephfs/shared/file.txt

# На сервере 2 (тот же файл доступен)
cat /mnt/cephfs/shared/file.txt
echo "Hello from server 2" | sudo tee -a /mnt/cephfs/shared/file.txt

# На сервере 1 (изменения видны)
cat /mnt/cephfs/shared/file.txt
```

### Пример 3: Резервное копирование с использованием снимков

```bash
# Создание снимка перед обновлением
rbd snap create rbd/myapp-data@before-update

# Выполнение обновления
# ... операции с данными ...

# Если что-то пошло не так, откат
rbd snap rollback rbd/myapp-data@before-update

# Если все хорошо, удаление снимка
rbd snap rm rbd/myapp-data@before-update
```

## Дополнительные ресурсы

- [Официальная документация Ceph](https://docs.ceph.com/)
- [Ceph Storage Guide](https://docs.ceph.com/en/latest/rados/)
- [RBD Documentation](https://docs.ceph.com/en/latest/rbd/)
- [CephFS Documentation](https://docs.ceph.com/en/latest/cephfs/)

