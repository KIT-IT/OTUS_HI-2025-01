# Быстрый старт с Ceph

## Проверка состояния кластера

После развертывания Ceph кластера используйте скрипт для проверки состояния:

```bash
# На любом узле кластера (mon, osd, mds или client)
cd lesson_36
./scripts/check-ceph-status.sh
```

Скрипт покажет:
-  Статус подключения к кластеру
-  Общее состояние кластера (HEALTH_OK или проблемы)
-  Статус всех мониторов
-  Статус всех OSD узлов
-  Использование пулов
-  Статус Placement Groups
-  Статус CephFS (если настроен)

## Быстрые команды

### Проверка здоровья кластера

```bash
# Краткий статус
sudo ceph -s

# Детальная информация о проблемах
sudo ceph health detail
```

### Работа с RBD

```bash
# Создать том 1 GB
sudo rbd create --size 1024 rbd/volume1

# Посмотреть список томов
sudo rbd list rbd

# Маппинг тома
sudo rbd map rbd/volume1

# Форматирование и монтирование
sudo mkfs.ext4 /dev/rbd0
sudo mkdir -p /mnt/rbd1
sudo mount /dev/rbd0 /mnt/rbd1
```

### Работа с CephFS

```bash
# Получить ключ администратора
ADMIN_KEY=$(sudo ceph auth get-key client.admin)

# Монтирование CephFS
sudo mkdir -p /mnt/cephfs
sudo mount -t ceph mon1:6789,mon2:6789,mon3:6789:/ /mnt/cephfs \
  -o name=admin,secret=$ADMIN_KEY

# Проверка
df -h /mnt/cephfs
```

## Дополнительная документация

- **[USAGE.md](USAGE.md)** - Подробное руководство по использованию Ceph
- **[APPLY.md](APPLY.md)** - Инструкции по развертыванию
- **[README.md](README.md)** - Архитектура и расчеты

