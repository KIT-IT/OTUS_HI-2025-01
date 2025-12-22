# Настройка Telegram алертинга

## Шаг 1: Создание Telegram бота

1. Откройте Telegram и найдите @BotFather
2. Отправьте команду `/newbot`
3. Следуйте инструкциям и получите токен бота (например: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)
4. Сохраните токен бота

## Шаг 2: Получение Chat ID

1. Найдите вашего бота в Telegram (по имени, которое вы указали)
2. Отправьте боту любое сообщение (например: `/start`)
3. Откройте в браузере: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
4. Найдите `"chat":{"id":123456789}` - это ваш Chat ID

## Шаг 3: Настройка Alertmanager

Токен и Chat ID будут добавлены в конфигурацию Alertmanager.
