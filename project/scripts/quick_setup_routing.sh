#!/bin/bash

# Быстрая настройка маршрутизации для доступа к Proxmox CT из WSL
# Выполните этот скрипт с правами sudo

PROXMOX_HOST="192.168.44.128"
PROXMOX_NETWORK="192.168.50.0/24"

echo "=== Настройка маршрутизации для доступа к Proxmox CT ==="
echo ""
echo "Шаг 1: Проверка доступности Proxmox хоста..."
if ping -c 1 -W 2 "$PROXMOX_HOST" &> /dev/null; then
  echo "✓ Proxmox хост доступен"
else
  echo "✗ Proxmox хост недоступен"
  exit 1
fi

echo ""
echo "Шаг 2: Добавление маршрута к сети $PROXMOX_NETWORK..."
if ip route show | grep -q "$PROXMOX_NETWORK"; then
  echo "Маршрут уже существует, удаляем старый..."
  sudo ip route del "$PROXMOX_NETWORK" 2>/dev/null || true
fi

if sudo ip route add "$PROXMOX_NETWORK" via "$PROXMOX_HOST"; then
  echo "✓ Маршрут добавлен"
else
  echo "✗ Ошибка добавления маршрута"
  exit 1
fi

echo ""
echo "Шаг 3: Проверка маршрута..."
ip route show | grep "$PROXMOX_NETWORK"

echo ""
echo "Шаг 4: Тестирование доступности..."
TEST_IPS=("192.168.50.31" "192.168.50.41" "192.168.50.11" "192.168.50.21")
for ip in "${TEST_IPS[@]}"; do
  if ping -c 1 -W 2 "$ip" &> /dev/null; then
    echo "✓ $ip доступен"
  else
    echo "✗ $ip недоступен (возможно, контейнер не запущен или нужна настройка на Proxmox)"
  fi
done

echo ""
echo "=== Настройка завершена ==="
echo ""
echo "ВАЖНО: Маршрут будет действовать только до перезагрузки WSL."
echo "Для постоянного сохранения добавьте в ~/.bashrc:"
echo "  sudo ip route add $PROXMOX_NETWORK via $PROXMOX_HOST 2>/dev/null || true"
echo ""
echo "Также убедитесь, что на Proxmox хосте включена маршрутизация:"
echo "  ssh root@$PROXMOX_HOST 'sysctl -w net.ipv4.ip_forward=1'"

