#!/bin/bash

set -euo pipefail

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()    { echo -e "${RED}[ERR ]${NC} $*"; }
step()   { echo -e "${BLUE}[STEP]${NC} $*"; }

# Получаем IP-адреса из Terraform outputs
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$PROJECT_DIR/terraform"

# Проверка наличия Terraform
if [ ! -d "$TF_DIR" ]; then
  err "Каталог Terraform не найден: $TF_DIR"
  exit 1
fi

cd "$TF_DIR"

# Получаем IP-адреса Docker контейнеров через terraform output
step "Получение IP-адресов Docker контейнеров из Terraform..."

DOCKER_MANAGER_IPS=()
DOCKER_WORKER_IPS=()

# Используем terraform output -json для получения IP
if command -v python3 &> /dev/null; then
  JSON_OUTPUT=$(terraform output -json 2>/dev/null)
  
  if [ -n "$JSON_OUTPUT" ]; then
    DOCKER_MANAGER_IPS=($(echo "$JSON_OUTPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for ip in data.get('docker_manager_ips', {}).get('value', []):
        print(ip.split('/')[0])
except Exception as e:
    pass
" 2>/dev/null))
    
    DOCKER_WORKER_IPS=($(echo "$JSON_OUTPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for ip in data.get('docker_worker_ips', {}).get('value', []):
        print(ip.split('/')[0])
except Exception as e:
    pass
" 2>/dev/null))
  fi
fi

# Если не удалось получить IP, используем значения по умолчанию
if [ ${#DOCKER_MANAGER_IPS[@]} -eq 0 ]; then
  warn "Не удалось получить IP из Terraform, используем значения по умолчанию"
  DOCKER_MANAGER_IPS=("192.168.50.31" "192.168.50.32")
fi

if [ ${#DOCKER_WORKER_IPS[@]} -eq 0 ]; then
  warn "Не удалось получить IP из Terraform, используем значения по умолчанию"
  DOCKER_WORKER_IPS=("192.168.50.41" "192.168.50.42")
fi

log "Docker Manager IPs: ${DOCKER_MANAGER_IPS[*]}"
log "Docker Worker IPs: ${DOCKER_WORKER_IPS[*]}"

# Параметры подключения
SSH_USER="${SSH_USER:-root}"
SSH_PASSWORD="${SSH_PASSWORD:-sedunovsv}"
TARGET_DIR="${TARGET_DIR:-/opt}"

# Файлы для копирования (все .sh и .yml файлы из каталога scripts, кроме самого copy_to_docker.sh)
SOURCE_DIR="$SCRIPT_DIR"
FILES_TO_COPY=()

for file in "$SOURCE_DIR"/*.sh "$SOURCE_DIR"/*.yml; do
  if [ -f "$file" ] && [ "$(basename "$file")" != "copy_to_docker.sh" ]; then
    FILES_TO_COPY+=("$(basename "$file")")
  fi
done

if [ ${#FILES_TO_COPY[@]} -eq 0 ]; then
  err "Не найдено файлов для копирования в $SOURCE_DIR"
  exit 1
fi

step "Файлы для копирования:"
for file in "${FILES_TO_COPY[@]}"; do
  log "  ✓ $file"
done

# Функция для копирования файлов в контейнер
copy_to_container() {
  local ip=$1
  local role=$2
  
  step "Копирование файлов в $role контейнер ($ip)..."
  
  # Проверка доступности контейнера (опционально, пропускаем если ping не работает)
  # if ! ping -c 1 -W 2 "$ip" &> /dev/null; then
  #   warn "Контейнер $ip не отвечает на ping, но продолжаем попытку подключения..."
  # fi
  
  # Создание целевой директории
  log "Создание директории $TARGET_DIR на $ip..."
  
  # Используем sshpass если доступен, иначе обычный ssh
  SSH_CMD="ssh"
  SCP_CMD="scp"
  SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  
  if command -v sshpass &> /dev/null; then
    SSH_CMD="sshpass -p '$SSH_PASSWORD' ssh"
    SCP_CMD="sshpass -p '$SSH_PASSWORD' scp"
  fi
  
  # Создание директории
  eval "$SSH_CMD $SSH_OPTS $SSH_USER@$ip 'mkdir -p $TARGET_DIR'" 2>/dev/null || {
    warn "Не удалось подключиться к $ip. Проверьте доступность и учетные данные."
    return 1
  }
  
  # Копирование файлов
  for file in "${FILES_TO_COPY[@]}"; do
    if [ -f "$SOURCE_DIR/$file" ]; then
      log "  Копирование $file..."
      if eval "$SCP_CMD $SSH_OPTS '$SOURCE_DIR/$file' $SSH_USER@$ip:$TARGET_DIR/" 2>/dev/null; then
        log "    ✓ $file скопирован"
      else
        err "    ✗ Ошибка копирования $file"
      fi
    fi
  done
  
  # Установка прав на выполнение для скриптов
  log "Установка прав на выполнение для скриптов..."
  eval "$SSH_CMD $SSH_OPTS $SSH_USER@$ip 'chmod +x $TARGET_DIR/*.sh 2>/dev/null || true'" 2>/dev/null || true
  
  log "✓ Файлы скопированы в $role контейнер ($ip)"
}

# Копирование в Docker Manager контейнеры
for ip in "${DOCKER_MANAGER_IPS[@]}"; do
  copy_to_container "$ip" "Docker Manager"
done

# Копирование в Docker Worker контейнеры
for ip in "${DOCKER_WORKER_IPS[@]}"; do
  copy_to_container "$ip" "Docker Worker"
done

step "Копирование завершено!"
log "Файлы скопированы во все Docker контейнеры в директорию $TARGET_DIR"
log ""
log "Для проверки можно подключиться к контейнеру:"
log "  ssh $SSH_USER@${DOCKER_MANAGER_IPS[0]}"
log "  ls -la $TARGET_DIR"
log ""
log "Примечание: Скрипты копируются в каталог /opt на каждом Docker контейнере"
