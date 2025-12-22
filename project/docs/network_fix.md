# Исправление сетевой конфигурации Proxmox контейнеров

## Проблема
Контейнеры (CT) в Proxmox не пинговались. Контейнеры находились в сети `192.168.50.0/24` с шлюзом `192.168.50.1`, который не существовал. Proxmox хост находился в сети `192.168.44.0/24`.

## Решение

### 1. Увеличение диска
- Расширен раздел `/dev/sda3` с 19.5G до 99.5G (диск увеличен до 100G в VMware)
- Расширен LVM physical volume: `pvresize /dev/sda3`
- Расширен logical volume `pve-root` до 88G с автоматическим расширением ext4 файловой системы

### 2. Настройка сети для контейнеров

#### Шаг 1: Диагностика текущего состояния
```bash
# Проверка статуса контейнеров
pct list

# Проверка сетевых интерфейсов хоста
ip addr show

# Проверка маршрутов
ip route show

# Проверка конфигурации контейнера
cat /etc/pve/lxc/100.conf | grep net0

# Проверка сети внутри контейнера
pct enter 100
ip addr show
ip route show
exit
```

#### Шаг 2: Добавление маршрута к сети контейнеров
```bash
# Добавление маршрута к сети 192.168.50.0/24 через vmbr0
ip route add 192.168.50.0/24 dev vmbr0

# Проверка добавленного маршрута
ip route show | grep 192.168.50
```

#### Шаг 3: Добавление IP 192.168.50.1 на vmbr0 (шлюз для контейнеров)
```bash
# Добавление IP адреса на интерфейс vmbr0
ip addr add 192.168.50.1/24 dev vmbr0

# Проверка добавленного IP
ip addr show vmbr0 | grep 192.168.50
```

#### Шаг 4: Настройка NAT masquerading для выхода в интернет
```bash
# Проверка включен ли IP forwarding
sysctl net.ipv4.ip_forward

# Добавление правила NAT masquerading для сети контейнеров
iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o vmbr0 -j MASQUERADE

# Проверка добавленного правила
iptables -t nat -L POSTROUTING -n | grep 192.168.50
```

#### Шаг 5: Обновление конфигурации сети для сохранения после перезагрузки
```bash
# Создание резервной копии конфигурации
cp /etc/network/interfaces /etc/network/interfaces.backup.$(date +%Y%m%d_%H%M%S)

# Редактирование /etc/network/interfaces
# Добавлена строка в секцию vmbr0:
#   up ip addr add 192.168.50.1/24 dev vmbr0
```

Содержимое `/etc/network/interfaces`:
```
auto vmbr0
iface vmbr0 inet static
        address 192.168.44.128/24
        gateway 192.168.44.2
        bridge-ports nic0
        bridge-stp off
        bridge-fd 0
        up ip addr add 192.168.50.1/24 dev vmbr0
```

#### Шаг 6: Обновление шлюза в конфигурации контейнеров
```bash
# Проверка текущего шлюза в конфигурациях
grep "gw=" /etc/pve/lxc/*.conf

# Обновление шлюза на 192.168.50.1 во всех контейнерах
for file in /etc/pve/lxc/*.conf; do
    sed -i 's/gw=192.168.50.1/gw=192.168.50.1/g' "$file"
done

# Проверка обновленной конфигурации
cat /etc/pve/lxc/100.conf | grep net0
```

#### Шаг 7: Перезапуск контейнеров для применения настроек
```bash
# Перезапуск всех контейнеров
for ct in 100 101 102 103 104 105 106 107; do
    pct restart $ct
done

# Ожидание запуска контейнеров
sleep 10

# Проверка статуса
pct list
```

#### Шаг 8: Проверка работоспособности
```bash
# Проверка пинга контейнеров с хоста
ping -c 2 192.168.50.31

# Проверка доступа контейнеров к шлюзу
pct exec 100 -- ping -c 2 192.168.50.1

# Проверка доступа контейнеров в интернет
pct exec 100 -- ping -c 2 8.8.8.8

# Проверка всех контейнеров
for ct in 100 101 102 103 104 105 106 107; do
    ip=$(grep "net0.*ip=" /etc/pve/lxc/$ct.conf | sed 's/.*ip=\([^,]*\).*/\1/' | cut -d/ -f1)
    echo -n "CT $ct ($ip): "
    ping -c 1 -W 1 $ip >/dev/null 2>&1 && echo "✓ OK" || echo "✗ FAILED"
done
```

### 3. Результат
Все 8 контейнеров теперь пингуются и имеют доступ в интернет:
- CT 100: 192.168.50.31
- CT 101: 192.168.50.41
- CT 102: 192.168.50.11
- CT 103: 192.168.50.32
- CT 104: 192.168.50.21
- CT 105: 192.168.50.22
- CT 106: 192.168.50.42
- CT 107: 192.168.50.12

## Измененные файлы
- `/etc/network/interfaces` - добавлен IP 192.168.50.1/24 на vmbr0
- `/etc/pve/lxc/*.conf` - все контейнеры используют шлюз 192.168.50.1

## Подключение по SSH к контейнерам

### Установка SSH сервера в контейнере (если не установлен)

#### Для AlmaLinux/RHEL/CentOS контейнеров:
```bash
# Войти в контейнер
pct enter 100

# Установить SSH сервер
dnf install -y openssh-server openssh-clients

# Включить и запустить SSH сервис
systemctl enable sshd
systemctl start sshd

# Проверить статус
systemctl status sshd

# Выйти из контейнера
exit
```

#### Для Debian/Ubuntu контейнеров:
```bash
# Войти в контейнер
pct enter 100

# Установить SSH сервер
apt-get update
apt-get install -y openssh-server

# Включить и запустить SSH сервис
systemctl enable ssh
systemctl start ssh

# Проверить статус
systemctl status ssh

# Выйти из контейнера
exit
```

### Подключение по SSH

#### С хоста Proxmox:
```bash
# Подключение к контейнеру по IP
ssh root@192.168.50.31

# Или с указанием пользователя
ssh username@192.168.50.31
```

#### С другого компьютера в сети:
```bash
# Если компьютер в той же сети 192.168.44.0/24 или 192.168.50.0/24
ssh root@192.168.50.31

# Если компьютер в другой сети, через Proxmox хост (192.168.44.128)
# Сначала подключиться к Proxmox хосту, затем к контейнеру
ssh root@192.168.44.128
ssh root@192.168.50.31
```

### Настройка SSH ключей (рекомендуется)

#### Генерация SSH ключа на клиенте:
```bash
# Создать SSH ключ (если еще нет)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Скопировать публичный ключ в контейнер
ssh-copy-id root@192.168.50.31
```

#### Ручная настройка ключей:
```bash
# На клиенте: скопировать публичный ключ
cat ~/.ssh/id_rsa.pub

# В контейнере: добавить ключ в authorized_keys
pct enter 100
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ваш_публичный_ключ" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
exit
```

### Проверка подключения

```bash
# Проверка доступности порта SSH
nc -zv 192.168.50.31 22

# Или с помощью telnet
telnet 192.168.50.31 22

# Проверка SSH подключения
ssh -v root@192.168.50.31

# Тест подключения с выполнением команды
ssh root@192.168.50.31 "hostname && whoami"
```

### Настройка SSH для всех контейнеров

```bash
# Установка SSH во всех контейнерах (пример для AlmaLinux)
for ct in 100 101 102 103 104 105 106 107; do
    echo "Setting up SSH in CT $ct..."
    pct exec $ct -- dnf install -y openssh-server openssh-clients
    pct exec $ct -- systemctl enable sshd
    pct exec $ct -- systemctl start sshd
done
```

### Включение входа root по SSH

По умолчанию в некоторых конфигурациях SSH вход под root может быть запрещен. Для включения:

#### В одном контейнере:
```bash
# Войти в контейнер
pct enter 100

# Отредактировать конфигурацию SSH
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Перезапустить SSH
systemctl restart sshd

# Проверить настройки
grep -E "^PermitRootLogin|^PasswordAuthentication" /etc/ssh/sshd_config

exit
```

#### Во всех контейнерах:
```bash
# Настроить SSH для всех контейнеров
for ct in 100 101 102 103 104 105 106 107; do
    echo "Настройка CT $ct..."
    pct exec $ct -- sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/; s/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    pct exec $ct -- systemctl restart sshd
done
```

**Важно:** После включения входа root необходимо установить пароль:
```bash
# Установить пароль для root в контейнере
pct enter 100
passwd root
exit
```

### Безопасность SSH

#### Отключение входа под root (рекомендуется):
```bash
# В контейнере отредактировать /etc/ssh/sshd_config
pct enter 100
vi /etc/ssh/sshd_config

# Изменить строку:
# PermitRootLogin no

# Создать пользователя с sudo правами
useradd -m -s /bin/bash username
passwd username
usermod -aG wheel username

# Перезапустить SSH
systemctl restart sshd
exit
```

#### Изменение порта SSH (опционально):
```bash
# В контейнере отредактировать /etc/ssh/sshd_config
pct enter 100
vi /etc/ssh/sshd_config

# Изменить строку:
# Port 2222

# Перезапустить SSH
systemctl restart sshd
exit

# Подключение с указанием порта
ssh -p 2222 root@192.168.50.31
```

## Команды для проверки
```bash
# Проверка пинга контейнеров
ping -c 2 192.168.50.31

# Проверка IP на vmbr0
ip addr show vmbr0

# Проверка маршрутов
ip route show | grep 192.168.50

# Проверка NAT
iptables -t nat -L POSTROUTING -n | grep 192.168.50

# Проверка SSH подключения
ssh root@192.168.50.31 "hostname"
```

