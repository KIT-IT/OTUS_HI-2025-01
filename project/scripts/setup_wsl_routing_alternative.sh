#!/bin/bash

# Альтернативный способ настройки маршрутизации для WSL
# Использует SSH туннель или проброс портов

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

PROXMOX_HOST="192.168.44.128"
PROXMOX_NETWORK="192.168.50.0/24"
WSL_GATEWAY="172.27.0.1"

step "Альтернативная настройка маршрутизации для WSL"

echo ""
echo "Вариант 1: Настройка маршрутизации через Windows (рекомендуется для WSL2)"
echo "  Выполните в PowerShell от имени администратора:"
echo "    cd $PWD"
echo "    .\setup_wsl_routing_windows.ps1"
echo ""

echo "Вариант 2: Использование SSH туннеля для доступа к конкретным хостам"
echo "  Можно настроить SSH туннель для доступа к контейнерам"
echo ""

echo "Вариант 3: Настройка на Proxmox хосте (если есть доступ)"
echo "  На Proxmox хосте можно настроить NAT или проброс портов"
echo ""

step "Проверка текущей конфигурации..."

# Проверка доступности Proxmox
if ping -c 1 -W 2 "$PROXMOX_HOST" &> /dev/null; then
  log "✓ Proxmox хост доступен: $PROXMOX_HOST"
else
  err "✗ Proxmox хост недоступен: $PROXMOX_HOST"
  exit 1
fi

# Попытка использовать шлюз WSL (может не сработать, если Windows не знает о сети)
log "Попытка добавить маршрут через шлюз WSL..."
if sudo ip route add "$PROXMOX_NETWORK" via "$WSL_GATEWAY" 2>/dev/null; then
  log "✓ Маршрут добавлен через шлюз WSL"
  ip route show | grep "$PROXMOX_NETWORK"
  
  # Тест
  if ping -c 1 -W 2 192.168.50.31 &> /dev/null; then
    log "✓ Доступность контейнеров проверена"
  else
    warn "Маршрут добавлен, но контейнеры недоступны"
    warn "Нужно настроить маршрутизацию на Windows хосте"
  fi
else
  warn "Не удалось добавить маршрут через шлюз WSL"
  echo ""
  echo "РЕШЕНИЕ: Настройте маршрутизацию на Windows хосте"
  echo ""
  echo "В PowerShell от имени администратора выполните:"
  echo ""
  echo "# Найти WSL интерфейс"
  echo "\$wsl = Get-NetAdapter | Where-Object { \$_.InterfaceDescription -like '*WSL*' -or \$_.Name -like '*vEthernet*' }"
  echo ""
  echo "# Добавить маршрут"
  echo "New-NetRoute -DestinationPrefix '$PROXMOX_NETWORK' -InterfaceAlias \$wsl.Name -NextHop '$PROXMOX_HOST'"
  echo ""
fi

