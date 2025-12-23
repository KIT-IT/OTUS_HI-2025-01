# Инструкция по развертыванию Ceph кластера

## Предпосылки

- Yandex Cloud CLI настроен (переменные окружения: `YC_TOKEN`, `YC_CLOUD_ID`, `YC_FOLDER_ID`)
- Terraform установлен (версия >= 1.6.0)
- Ansible установлен (версия >= 2.9)
- SSH ключ доступен (`~/.ssh/id_ed25519.pub`)

## Шаги развертывания

### 1. Создание инфраструктуры (Terraform)

```bash
cd lesson_36/terraform

# Инициализация Terraform
terraform init

# Планирование изменений
terraform plan

# Применение конфигурации
terraform apply

# Сохранение outputs
terraform output -json > ../terraform-outputs.json
```

**Результат:**
- Созданы VM: 3 монитора, 3 OSD узла, 1 MDS узел, 2 клиентские машины
- Настроены Security Groups для Ceph
- Сгенерирован Ansible inventory файл

### 2. Подготовка ceph-ansible

```bash
cd lesson_36

# Клонирование ceph-ansible (если еще не клонирован)
if [ ! -d "ceph-ansible" ]; then
  git clone https://github.com/ceph/ceph-ansible.git
  cd ceph-ansible
  git checkout stable-6.0  # Или другая стабильная версия
  cd ..
fi

# Копирование конфигурации
cp ansible/group_vars/all/main.yml ceph-ansible/group_vars/all.yml
cp terraform/inventory.ini ceph-ansible/inventory.ini
```

### 3. Развертывание Ceph кластера

```bash
cd lesson_36/ceph-ansible

# Проверка доступности хостов
ansible all -i inventory.ini -m ping

# Развертывание мониторов
ansible-playbook -i inventory.ini site.yml --limit mons

# Развертывание OSD
ansible-playbook -i inventory.ini site.yml --limit osds

# Развертывание MDS
ansible-playbook -i inventory.ini site.yml --limit mdss

# Или развертывание всего кластера сразу
ansible-playbook -i inventory.ini site.yml
```

### 4. Проверка состояния кластера

```bash
# Подключение к одному из мониторов
ssh ubuntu@<mon-ip>

# Проверка статуса кластера
sudo ceph -s

# Проверка OSD
sudo ceph osd tree

# Проверка пулов
sudo ceph df
```

### 5. Создание пулов

```bash
# Создание RBD пула
sudo ceph osd pool create rbd 64 64

# Создание CephFS пулов
sudo ceph osd pool create cephfs_data 32 32
sudo ceph osd pool create cephfs_metadata 4 4

# Создание файловой системы
sudo ceph fs new cephfs cephfs_metadata cephfs_data

# Проверка пулов
sudo ceph df detail
```

### 6. Настройка клиентских машин

```bash
# Установка клиентских пакетов на клиентских машинах
ansible-playbook -i inventory.ini ansible/playbooks/setup-clients.yml

# Или вручную на каждой клиентской машине:
ssh ubuntu@<client-ip>

# Установка пакетов
sudo apt-get update
sudo apt-get install -y ceph-common ceph-fuse

# Копирование ключей и конфигурации с монитора
# (нужно скопировать /etc/ceph/ceph.conf и ключи)
```

### 7. Настройка RBD томов

```bash
# На клиентской машине
# Создание RBD образа
sudo rbd create --size 1024 rbd/volume1
sudo rbd create --size 2048 rbd/volume2
sudo rbd create --size 512 rbd/volume3

# Маппинг томов
sudo rbd map rbd/volume1
sudo rbd map rbd/volume2
sudo rbd map rbd/volume3

# Форматирование и монтирование
sudo mkfs.ext4 /dev/rbd0
sudo mkfs.ext4 /dev/rbd1
sudo mkfs.ext4 /dev/rbd2

sudo mkdir -p /mnt/rbd1 /mnt/rbd2 /mnt/rbd3
sudo mount /dev/rbd0 /mnt/rbd1
sudo mount /dev/rbd1 /mnt/rbd2
sudo mount /dev/rbd2 /mnt/rbd3
```

### 8. Настройка CephFS

```bash
# На клиентской машине
# Получение ключа администратора
sudo ceph auth get-key client.admin

# Монтирование CephFS
sudo mkdir -p /mnt/cephfs
sudo mount -t ceph <mon-ip>:6789:/ /mnt/cephfs -o name=admin,secret=<key>

# Или через fstab для постоянного монтирования
echo "<mon-ip>:6789:/ /mnt/cephfs ceph name=admin,secret=<key>,noatime,_netdev 0 2" | sudo tee -a /etc/fstab
```

## Аварийные сценарии

### 3.1. Split-brain

```bash
# Генерация split-brain (симуляция)
# Остановка одного OSD во время записи
sudo systemctl stop ceph-osd@<osd-id>

# Проверка состояния
sudo ceph health detail

# Разрешение конфликта
sudo ceph pg repair <pg-id>
```

### 3.2. Сбой OSD узла

```bash
# Остановка OSD
sudo systemctl stop ceph-osd@<osd-id>

# Вывод из кластера
sudo ceph osd out <osd-id>
sudo ceph osd crush remove osd.<osd-id>
sudo ceph auth del osd.<osd-id>
sudo ceph osd rm <osd-id>

# Добавление нового OSD
# (после добавления нового диска на новом узле)
sudo ceph-volume lvm create --data /dev/sdb
```

### 3.3. Сбой серверной/дата-центра

```bash
# Симуляция отказа зоны (остановка всех узлов в одной зоне)
# Проверка работоспособности
sudo ceph -s
sudo ceph osd tree

# Восстановление после возврата узлов
sudo ceph osd reweight-all
```

### 3.4. Расширение кластера

```bash
# Добавление новых OSD узлов через Terraform
# (увеличить osd_count в variables.tf)

# После добавления узлов
sudo ceph osd tree

# Перерасчет PG
sudo ceph osd pool set rbd pg_num <new_pg_num>
sudo ceph osd pool set rbd pgp_num <new_pg_num>

# Логика: при добавлении OSD нужно увеличить PG для равномерного распределения
# Формула: Total PG = (Total OSDs × 100) / Replication Factor
```

### 3.5. Уменьшение кластера

```bash
# Вывод OSD из кластера
sudo ceph osd out <osd-id>
sudo ceph osd crush remove osd.<osd-id>

# Перерасчет PG
sudo ceph osd pool set rbd pg_num <new_pg_num>
sudo ceph osd pool set rbd pgp_num <new_pg_num>

# Логика: при уменьшении OSD можно уменьшить PG, но обычно оставляют прежнее количество
# для будущего расширения
```

## Очистка ресурсов

```bash
cd lesson_36/terraform

# Удаление всех ресурсов
terraform destroy

# Подтвердить удаление: yes
```

## Проверка состояния кластера

### Использование скрипта проверки

```bash
# Запуск скрипта проверки состояния (на любом узле кластера)
cd lesson_36
./scripts/check-ceph-status.sh

# Или с полным путем
bash lesson_36/scripts/check-ceph-status.sh
```

Скрипт автоматически проверяет:
- Подключение к кластеру
- Общий статус и здоровье кластера
- Статус мониторов (MON)
- Статус OSD узлов и их использование
- Статус пулов (Pools) и распределение данных
- Статус Placement Groups (PG)
- Статус CephFS (если настроен)

### Ручная проверка

```bash
# Статус кластера
sudo ceph -s
sudo ceph health

# Статус OSD
sudo ceph osd tree
sudo ceph osd df

# Статус пулов
sudo ceph df
sudo ceph df detail

# Статус CephFS
sudo ceph fs status
sudo ceph fs ls

# Информация о RBD образах
sudo rbd list
sudo rbd info rbd/volume1

# Логи
sudo journalctl -u ceph-mon@<mon-id> -f
sudo journalctl -u ceph-osd@<osd-id> -f
```

## Использование Ceph

Подробное руководство по использованию Ceph доступно в файле **[USAGE.md](USAGE.md)**.

Основные операции:
- Создание и использование RBD томов
- Работа с CephFS
- Управление пулами и PG
- Мониторинг и диагностика
- Примеры типичных операций

