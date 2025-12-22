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

# Параметры сети Proxmox
PROXMOX_HOST="${PROXMOX_HOST:-192.168.44.128}"
PROXMOX_NETWORK="${PROXMOX_NETWORK:-192.168.50.0/24}"

step "Настройка маршрутизации для доступа к Proxmox CT из WSL"

# Проверка доступности Proxmox хоста
log "Проверка доступности Proxmox хоста ($PROXMOX_HOST)..."
if ! ping -c 1 -W 2 "$PROXMOX_HOST" &> /dev/null; then
  err "Proxmox хост $PROXMOX_HOST недоступен"
  exit 1
fi
log "✓ Proxmox хост доступен"

# Проверка текущих маршрутов
log "Текущие маршруты:"
ip route show | grep -E "$PROXMOX_NETWORK|default" || true

# Добавление маршрута
step "Добавление маршрута к сети $PROXMOX_NETWORK через $PROXMOX_HOST..."

# Проверка, существует ли уже маршрут
if ip route show | grep -q "$PROXMOX_NETWORK"; then
  warn "Маршрут к $PROXMOX_NETWORK уже существует"
  log "Удаление существующего маршрута..."
  sudo ip route del "$PROXMOX_NETWORK" 2>/dev/null || true
fi

# Добавление нового маршрута
if sudo ip route add "$PROXMOX_NETWORK" via "$PROXMOX_HOST" 2>/dev/null; then
  log "✓ Маршрут добавлен успешно"
else
  err "Ошибка добавления маршрута. Возможно, нужны права sudo"
  exit 1
fi

# Проверка маршрута
log "Проверка добавленного маршрута:"
ip route show | grep "$PROXMOX_NETWORK" || err "Маршрут не найден"

# Тест доступности сети
step "Тестирование доступности сети $PROXMOX_NETWORK..."

# Получаем IP адреса CT из Terraform
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$PROJECT_DIR/terraform"

if [ -d "$TF_DIR" ] && command -v terraform &> /dev/null; then
  cd "$TF_DIR"
  
  if command -v python3 &> /dev/null; then
    JSON_OUTPUT=$(terraform output -json 2>/dev/null || echo "{}")
    
    # Тестируем доступность Docker контейнеров
    TEST_IPS=()
    for ip in $(echo "$JSON_OUTPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for ip in data.get('docker_manager_ips', {}).get('value', []):
        print(ip.split('/')[0])
    for ip in data.get('docker_worker_ips', {}).get('value', []):
        print(ip.split('/')[0])
except:
    pass
" 2>/dev/null); do
      TEST_IPS+=("$ip")
    done
    
    if [ ${#TEST_IPS[@]} -gt 0 ]; then
      log "Тестирование доступности CT контейнеров..."
      for ip in "${TEST_IPS[@]}"; do
        if ping -c 1 -W 2 "$ip" &> /dev/null; then
          log "  ✓ $ip доступен"
        else
          warn "  ✗ $ip недоступен (возможно, контейнер не запущен или сеть не настроена)"
        fi
      done
    fi
  fi
fi

step "Настройка завершена!"
log ""
log "Маршрут добавлен, но он будет действовать только до перезагрузки WSL."
log "Для постоянного сохранения маршрута добавьте в /etc/network/interfaces или используйте netplan."
log ""
log "Для постоянного сохранения выполните:"
log "  echo '$PROXMOX_NETWORK via $PROXMOX_HOST' | sudo tee -a /etc/network/interfaces.d/proxmox-route"
log ""
log "Или добавьте в ~/.bashrc или ~/.zshrc:"
log "  sudo ip route add $PROXMOX_NETWORK via $PROXMOX_HOST 2>/dev/null || true"

