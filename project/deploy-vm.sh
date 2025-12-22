#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()    { echo -e "${RED}[ERR ]${NC} $*"; }
step()   { echo -e "${BLUE}[STEP]${NC} $*"; }

ROOT_DIR="/home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_19"
TF_DIR="$ROOT_DIR/terraform"

# Проверка предварительных требований
step "Проверка предварительных требований..."
if ! command -v terraform >/dev/null 2>&1; then
  err "Terraform не установлен"
  exit 1
fi

log "Terraform версия: $(terraform version | head -n1)"

# Проверка наличия файла переменных
if [ ! -f "$TF_DIR/terraform.tfvars" ]; then
  warn "Файл terraform.tfvars не найден"
  log "Создайте файл terraform.tfvars на основе terraform.tfvars.example"
  log "Команда: cp $TF_DIR/terraform.tfvars.example $TF_DIR/terraform.tfvars"
  exit 1
fi

# Проверка SSH ключа
if [ -z "${SSH_PUBLIC_KEY:-}" ]; then
  if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    export SSH_PUBLIC_KEY=$(cat "$HOME/.ssh/id_ed25519.pub")
    log "Используется SSH ключ: $HOME/.ssh/id_ed25519.pub"
  elif [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    export SSH_PUBLIC_KEY=$(cat "$HOME/.ssh/id_rsa.pub")
    log "Используется SSH ключ: $HOME/.ssh/id_rsa.pub"
  else
    warn "SSH публичный ключ не найден. Создайте его командой: ssh-keygen -t ed25519"
  fi
fi

# Шаг 1: Инициализация Terraform
step "Шаг 1/3: Инициализация Terraform..."
cd "$TF_DIR"
log "Выполняется: terraform init"
terraform init -input=false

# Шаг 2: Просмотр плана
step "Шаг 2/3: Просмотр плана развёртывания..."
log "Выполняется: terraform plan"
terraform plan -out=tfplan

# Шаг 3: Применение конфигурации
step "Шаг 3/3: Развёртывание LXC контейнера..."
read -p "Применить изменения? (yes/no): " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  log "Выполняется: terraform apply"
  terraform apply -auto-approve tfplan
else
  warn "Отменено пользователем"
  exit 0
fi

# Показываем результаты
step "Развёртывание завершено!"
log "═══════════════════════════════════════════════════════════════"
log "Информация о созданном LXC контейнере:"
log "═══════════════════════════════════════════════════════════════"
echo ""

terraform output

echo ""
log "═══════════════════════════════════════════════════════════════"
log "Проверка контейнера в Proxmox:"
log "1. Войдите в веб-интерфейс Proxmox"
log "2. Перейдите в раздел LXC/CT"
log "3. Найдите контейнер с именем, указанным в terraform.tfvars"
log "═══════════════════════════════════════════════════════════════"

