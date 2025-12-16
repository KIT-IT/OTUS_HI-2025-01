# Установка Proxmox VE

## Варианты установки

### Вариант 1: Установка на отдельный сервер (рекомендуется)

1. **Скачайте ISO образ Proxmox VE**
   - Перейдите на https://www.proxmox.com/en/downloads
   - Скачайте последнюю версию Proxmox VE ISO

2. **Создайте загрузочную флешку или используйте ISO в виртуальной машине**
   ```bash
   # Пример для записи на флешку (замените /dev/sdX на ваше устройство)
   sudo dd if=proxmox-ve_*.iso of=/dev/sdX bs=4M status=progress
   ```

3. **Установите Proxmox VE**
   - Загрузитесь с ISO
   - Следуйте инструкциям установщика
   - Укажите пароль для root и настройте сеть

4. **Доступ к веб-интерфейсу**
   - После установки откройте браузер: `https://IP_СЕРВЕРА:8006`
   - Войдите с учётными данными root

## Загрузка ISO образов в Proxmox

После установки Proxmox и входа в веб-интерфейс необходимо загрузить ISO образы операционных систем для создания виртуальных машин.

### Способ 1: Загрузка через веб-интерфейс (рекомендуется)

1. **Откройте хранилище `local`**
   - В левой панели найдите узел (например, `pve`)
   - Раскройте узел и найдите **`local`** (или другое хранилище)
   - Кликните на **`local`** → перейдите на вкладку **`ISO Images`**

2. **Загрузите ISO образ**
   - Нажмите кнопку **`Upload`** в верхней панели
   - В открывшемся окне:
     - Нажмите **`Select File`** или перетащите файл ISO
     - Выберите ISO файл (например, `ubuntu-22.04.5-live-server-amd64.iso`)
     - Нажмите **`Upload`**
   - Дождитесь завершения загрузки (прогресс будет виден в интерфейсе)

3. **Проверьте загруженный образ**
   - После загрузки ISO должен появиться в списке на вкладке **`ISO Images`**
   - Запомните имя файла - оно понадобится при создании ВМ

### Способ 2: Загрузка через командную строку (SSH)

Если у вас есть доступ по SSH к Proxmox серверу:

```bash
# Подключитесь к Proxmox серверу
ssh root@IP_СЕРВЕРА

# Перейдите в директорию хранилища ISO
cd /var/lib/vz/template/iso

# Загрузите ISO (например, через wget)
# Ubuntu 22.04.5 LTS (актуальная версия):
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso

# Или скопируйте через scp с вашего компьютера
# scp ubuntu-22.04.5-live-server-amd64.iso root@IP_СЕРВЕРА:/var/lib/vz/template/iso/
```

После загрузки через SSH образ появится в веб-интерфейсе на вкладке **`ISO Images`**.

### Способ 3: Использование GitLab для хранения ISO образов

Если вы хотите использовать GitLab для хранения и управления ISO образами:

1. **Загрузите ISO в GitLab**
   - Создайте проект в GitLab (или используйте существующий)
   - Загрузите ISO файл в репозиторий (через веб-интерфейс или Git LFS для больших файлов)

2. **Скачайте ISO из GitLab в Proxmox**
   
   **Вариант A: Через веб-интерфейс Proxmox**
   - В Proxmox: **`local`** → **`ISO Images`** → **`Upload`**
   - Сначала скачайте ISO из GitLab на ваш компьютер, затем загрузите в Proxmox

   **Вариант B: Через SSH (прямая загрузка)**
   ```bash
   # Подключитесь к Proxmox по SSH
   ssh root@IP_СЕРВЕРА
   
   # Перейдите в директорию ISO
   cd /var/lib/vz/template/iso
   
   # Скачайте ISO из GitLab (используйте прямую ссылку на файл)
   # Для публичных репозиториев:
   wget https://gitlab.com/username/project/-/raw/main/ubuntu-22.04.5-live-server-amd64.iso
   
   # Для приватных репозиториев (нужен токен):
   wget --header="PRIVATE-TOKEN: YOUR_GITLAB_TOKEN" \
     https://gitlab.com/api/v4/projects/PROJECT_ID/repository/files/path%2Fto%2Ffile.iso/raw
   ```

3. **Автоматизация через CI/CD (опционально)**
   - Можно настроить GitLab CI/CD для автоматической загрузки ISO в Proxmox
   - Используйте Proxmox API или SSH для автоматизации

### Рекомендуемые ISO образы для начала работы

- **Ubuntu Server 22.04.5 LTS** (прямая ссылка):
  - https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso
  - Или выберите версию на: https://ubuntu.com/download/server
- **Debian**: https://www.debian.org/CD/http-ftp/
- **CentOS/Rocky Linux**: https://rockylinux.org/download
- **Alpine Linux**: https://alpinelinux.org/downloads/ (для легковесных ВМ)

> **Примечание**: Ссылки на конкретные версии ISO могут изменяться. Если прямая ссылка не работает, используйте официальные страницы загрузки для получения актуальных ссылок.

### Следующий шаг: Создание виртуальной машины

После загрузки ISO образа:
1. В веб-интерфейсе Proxmox нажмите **`Create VM`** (кнопка в правом верхнем углу)
2. В мастере создания ВМ на шаге **`OS`** выберите загруженный ISO образ
3. Продолжите настройку ВМ (CPU, RAM, диск, сеть)

### Вариант 2: Установка в виртуальной машине (для тестирования)

Если вы хотите протестировать Proxmox в виртуальной машине:

#### Использование VirtualBox

1. **Создайте новую виртуальную машину**
   - Тип: Linux, Версия: Debian (64-bit)
   - RAM: минимум 4GB (рекомендуется 8GB)
   - Жёсткий диск: минимум 32GB
   - **Важно**: Включите виртуализацию (VT-x/AMD-V) в настройках VM

2. **Настройте сеть**
   - Тип адаптера: Bridged Adapter или NAT
   - Для доступа извне используйте Bridged Adapter

3. **Установите Proxmox**
   - Подключите ISO образ
   - Загрузите VM и установите Proxmox

#### Использование VMware

1. **Создайте новую виртуальную машину**
   - Guest OS: Linux, Debian 11.x 64-bit
   - RAM: минимум 4GB
   - Диск: минимум 32GB
   - **Включите виртуализацию**: Settings → Processors → Virtualize Intel VT-x/EPT

2. **Установите Proxmox**

### Вариант 3: Использование существующего Proxmox сервера

Если у вас уже есть доступ к Proxmox серверу, используйте его.

## Настройка API токена в Proxmox

После установки Proxmox необходимо создать API токен для Terraform:

1. **Войдите в веб-интерфейс Proxmox**
   - URL: `https://IP_СЕРВЕРА:8006`
   - Логин: `root` (или другой пользователь)
   - Пароль: ваш пароль

2. **Создайте пользователя для API (опционально, но рекомендуется)**
   - Перейдите в **Datacenter** → **Permissions** → **Users**
   - Нажмите **Add** → **User**
   - Username: `terraform`
   - Password: создайте надёжный пароль
   - Groups: можно добавить в группу или оставить пустым

3. **Создайте API токен**
   - Перейдите в **Datacenter** → **Permissions** → **API Tokens**
   - Нажмите **Add** → **API Token**
   - Заполните:
     - **Token ID**: `terraform@pve!terraform-token` (формат: `user@realm!token-name`)
     - **User**: выберите пользователя (например, `terraform@pve` или `root@pam`)
     - **Realm**: обычно `pve` или `pam`
     - **Privilege Separation**: включите для безопасности
   - Нажмите **Generate**
   - **ВАЖНО**: Сохраните **Token Secret** - он показывается только один раз!

4. **Настройте права доступа**
   - Перейдите в **Datacenter** → **Permissions**
   - Создайте роль или используйте существующую
   - Минимальные права для создания ВМ:
     - `Datastore.Audit`
     - `Datastore.AllocateSpace`
     - `Pool.Allocate`
     - `SDN.Use`
     - `Sys.Audit`
     - `Sys.Modify`
     - `VM.Allocate`
     - `VM.Audit`
     - `VM.Clone`
     - `VM.Config.CDROM`
     - `VM.Config.CPU`
     - `VM.Config.CloudInit`
     - `VM.Config.Disk`
     - `VM.Config.HWType`
     - `VM.Config.Memory`
     - `VM.Config.Network`
     - `VM.Config.Options`
     - `VM.Monitor`
     - `VM.PowerMgmt`

## Проверка подключения

После настройки API токена можно проверить подключение:

```bash
# Установите curl, если его нет
sudo apt-get update && sudo apt-get install -y curl

# Проверьте подключение (замените на ваши данные)
curl -k -H "Authorization: PVEAPIToken=terraform@pve!terraform-token=YOUR_TOKEN_SECRET" \
  https://YOUR_PROXMOX_IP:8006/api2/json/version
```

Если всё настроено правильно, вы получите JSON ответ с версией Proxmox.

## Следующие шаги

После установки и настройки Proxmox:

1. Скопируйте `terraform.tfvars.example` в `terraform.tfvars`
2. Заполните параметры подключения
3. Запустите `terraform init`
4. Запустите `terraform plan` для проверки
5. Запустите `terraform apply` для создания ВМ

