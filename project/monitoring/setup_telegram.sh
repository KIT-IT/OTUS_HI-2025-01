#!/bin/bash

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     НАСТРОЙКА TELEGRAM АЛЕРТИНГА                               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

read -p "Введите токен Telegram бота: " BOT_TOKEN
read -p "Введите Chat ID: " CHAT_ID

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "Ошибка: Токен и Chat ID обязательны!"
    exit 1
fi

# Создаем .env файл для docker-compose
cat > /root/monitoring/.env << ENVEOF
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
TELEGRAM_CHAT_ID=$CHAT_ID
ENVEOF

echo "✅ Конфигурация обновлена!"
echo ""
echo "📋 Следующие шаги:"
echo "   1. Скопируйте файлы на CT 107:"
echo "      pct push 107 /root/monitoring /opt/monitoring"
echo ""
echo "   2. На CT 107 создайте .env файл:"
echo "      pct exec 107 -- bash -c 'cat > /opt/monitoring/.env << \"ENVEOF\""
echo "      TELEGRAM_BOT_TOKEN=$BOT_TOKEN"
echo "      TELEGRAM_CHAT_ID=$CHAT_ID"
echo "      ENVEOF'"
echo ""
echo "   3. Перезапустите сервисы на CT 107:"
echo "      pct exec 107 -- cd /opt/monitoring && docker-compose -f docker-compose.ct107.yml down"
echo "      pct exec 107 -- cd /opt/monitoring && docker-compose -f docker-compose.ct107.yml up -d"
echo ""
echo "   4. Проверьте статус:"
echo "      http://192.168.50.41:9093 (Alertmanager)"
echo "      http://192.168.50.41:9090/alerts (Prometheus Alerts)"
echo "      http://192.168.50.41:8080/health (Telegram Webhook)"
