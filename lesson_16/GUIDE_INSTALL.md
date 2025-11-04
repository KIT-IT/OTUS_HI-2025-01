# Гайд по установке зависимостей

Этот гайд описывает установку всех необходимых инструментов для работы с проектом.

## Требования

- Операционная система: Ubuntu 20.04+ / Debian 11+ / аналогичная Linux система
- Права sudo для установки пакетов
- Доступ в интернет
- Аккаунт в Yandex Cloud

## Установка инструментов

### 1. Yandex Cloud CLI (yc)

#### Способ 1: Через официальный репозиторий (рекомендуется)

```bash
# Установка
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash

# Перезагрузка PATH
exec -l $SHELL

# Проверка
yc version
```

#### Способ 2: Через snap

```bash
sudo snap install yandex-cloud-cli --classic
yc version
```

#### Инициализация

```bash
yc init
```

Следуйте инструкциям:
- Выберите облако
- Выберите каталог
- Выберите зону по умолчанию

### 2. Terraform

#### Способ 1: Через официальный репозиторий HashiCorp

```bash
# Установка зависимостей
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

# Добавление GPG ключа
wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Добавление репозитория
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list

# Установка
sudo apt update
sudo apt-get install terraform

# Проверка
terraform version
```

#### Способ 2: Через бинарный файл

```bash
# Скачать последнюю версию с https://www.terraform.io/downloads
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version
```

### 3. Ansible

```bash
# Обновление списка пакетов
sudo apt-get update

# Установка
sudo apt-get install -y ansible

# Проверка
ansible --version
```

**Минимальная версия:** 2.9+

### 4. SSH ключи

#### Проверка наличия ключей

```bash
ls -la ~/.ssh/id_ed25519*
```

Если ключей нет, создайте их:

```bash
# Генерация SSH ключа
ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/id_ed25519

# При запросе passphrase можно оставить пустым для автоматизации
# Или задать пароль для безопасности
```

#### Настройка прав доступа

```bash
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

#### Добавление ключа в ssh-agent (опционально)

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### 5. Дополнительные инструменты (опционально)

#### jq (для работы с JSON)

```bash
sudo apt-get install -y jq
```

#### curl и wget

```bash
sudo apt-get install -y curl wget
```

#### Docker (для локального тестирования)

```bash
# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER

# Перелогин для применения изменений
newgrp docker

# Проверка
docker version
```

## Настройка Yandex Cloud

### 1. Создание сервисного аккаунта

```bash
# Создание аккаунта
yc iam service-account create --name terraform-sa

# Сохранение ID аккаунта
SA_ID=$(yc iam service-account get terraform-sa --format json | jq -r '.id')
echo "Service Account ID: $SA_ID"
```

### 2. Назначение ролей

```bash
# Роль editor на каталог
yc resource-manager folder add-access-binding <FOLDER_ID> \
    --role editor \
    --subject serviceAccount:$SA_ID

# Роль admin на облако (для создания сетей)
yc resource-manager cloud add-access-binding <CLOUD_ID> \
    --role admin \
    --subject serviceAccount:$SA_ID
```

### 3. Создание ключа для сервисного аккаунта

```bash
# Создание ключа
yc iam key create --service-account-id $SA_ID \
    --output ~/.yc/terraform-sa-key.json

# Настройка профиля
yc config profile create terraform
yc config set service-account-key ~/.yc/terraform-sa-key.json
yc config set cloud-id <CLOUD_ID>
yc config set folder-id <FOLDER_ID>
```

### 4. Настройка переменных окружения

Создайте файл `~/.yc_env`:

```bash
cat > ~/.yc_env << EOF
export YC_TOKEN=\$(yc iam create-token)
export YC_CLOUD_ID=\$(yc config get cloud-id)
export YC_FOLDER_ID=\$(yc config get folder-id)
EOF

# Добавьте в .bashrc или .zshrc
echo "source ~/.yc_env" >> ~/.bashrc
source ~/.bashrc
```

## Проверка установки

Создайте тестовый скрипт:

```bash
cat > ~/test_install.sh << 'EOF'
#!/bin/bash

echo "Checking installations..."

# Check yc
if command -v yc &> /dev/null; then
    echo "✓ yc installed: $(yc version)"
else
    echo "✗ yc not found"
fi

# Check terraform
if command -v terraform &> /dev/null; then
    echo "✓ terraform installed: $(terraform version | head -1)"
else
    echo "✗ terraform not found"
fi

# Check ansible
if command -v ansible &> /dev/null; then
    echo "✓ ansible installed: $(ansible --version | head -1)"
else
    echo "✗ ansible not found"
fi

# Check SSH keys
if [ -f ~/.ssh/id_ed25519 ]; then
    echo "✓ SSH key found: ~/.ssh/id_ed25519"
else
    echo "✗ SSH key not found"
fi

# Check YC config
if yc config list &> /dev/null; then
    echo "✓ YC config configured"
    echo "  Cloud ID: $(yc config get cloud-id)"
    echo "  Folder ID: $(yc config get folder-id)"
else
    echo "✗ YC config not configured"
fi

# Check YC token
if [ -n "${YC_TOKEN:-}" ]; then
    echo "✓ YC_TOKEN exported"
else
    echo "✗ YC_TOKEN not exported"
fi
EOF

chmod +x ~/test_install.sh
~/test_install.sh
```

## Устранение проблем

### Проблема: yc command not found

**Решение:**
```bash
# Проверьте установку
which yc

# Если не установлен, переустановите
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
exec -l $SHELL
```

### Проблема: terraform permission denied

**Решение:**
```bash
# Проверьте права
ls -la $(which terraform)

# Если нужно, установите права
sudo chmod +x $(which terraform)
```

### Проблема: ansible слишком старая версия

**Решение:**
```bash
# Удалите старую версию
sudo apt-get remove ansible

# Установите через pip (более новая версия)
sudo apt-get install -y python3-pip
pip3 install ansible

# Или используйте PPA
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install ansible
```

### Проблема: SSH ключ не работает

**Решение:**
```bash
# Проверьте права
ls -la ~/.ssh/id_ed25519
# Должно быть: -rw------- (600)

# Исправьте права
chmod 600 ~/.ssh/id_ed25519

# Проверьте содержимое публичного ключа
cat ~/.ssh/id_ed25519.pub
```

### Проблема: YC authentication failed

**Решение:**
```bash
# Проверьте токен
yc iam create-token

# Если ошибка, переавторизуйтесь
yc init

# Проверьте конфигурацию
yc config list
```

## Следующие шаги

После успешной установки всех зависимостей:
1. Прочитайте [GUIDE_RUN.md](GUIDE_RUN.md) для запуска системы
2. Настройте Yandex Cloud (если еще не настроен)
3. Проверьте все инструменты командой `~/test_install.sh`

