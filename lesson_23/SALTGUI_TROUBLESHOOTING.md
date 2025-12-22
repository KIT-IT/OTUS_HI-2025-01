# Решение проблем с подключением SaltGUI

## Текущая конфигурация

✅ **REST API работает:** http://130.193.51.250:8000  
✅ **Аутентификация отключена** (для тестирования)  
✅ **SaltGUI Frontend:** http://130.193.51.250:8001

## Настройка подключения в SaltGUI

### Вариант 1: Без аутентификации (рекомендуется для тестирования)

1. Откройте http://130.193.51.250:8001
2. Найдите настройки подключения (иконка ⚙️ или "Settings")
3. Введите:
   - **URL:** `http://130.193.51.250:8000`
   - **Username:** (оставьте пустым)
   - **Password:** (оставьте пустым)
   - **Auth method:** `none` или `auto` (или оставьте пустым)

### Вариант 2: С PAM аутентификацией

- **URL:** `http://130.193.51.250:8000`
- **Username:** `ubuntu`
- **Password:** `ubuntu123`
- **Auth method:** `pam`

## Диагностика проблем

### Шаг 1: Проверка консоли браузера

1. Откройте http://130.193.51.250:8001
2. Нажмите **F12** (откроется Developer Tools)
3. Перейдите на вкладку **Console**
4. Попробуйте подключиться к REST API
5. Посмотрите, какие ошибки появляются

### Шаг 2: Проверка Network запросов

1. В Developer Tools перейдите на вкладку **Network**
2. Попробуйте подключиться
3. Найдите запросы к `8000` порту
4. Посмотрите статус ответов (200, 401, 400, etc.)

### Шаг 3: Проверка REST API напрямую

Откройте в браузере или через curl:
```bash
curl http://130.193.51.250:8000/
```

Должен вернуться:
```json
{"return": "Welcome", "clients": [...]}
```

## Возможные проблемы и решения

### Проблема: "Connection refused" или таймаут

**Решение:**
```bash
ssh ubuntu@130.193.51.250
sudo systemctl status salt-api
sudo systemctl restart salt-api
```

### Проблема: "401 Unauthorized"

**Решение:** Убедитесь, что в конфигурации `/etc/salt/master` есть:
```yaml
rest_cherrypy:
  disable_authentication: true
```

И перезапустите:
```bash
sudo systemctl restart salt-master salt-api
```

### Проблема: "CORS error" в консоли браузера

**Решение:** Это нормально для SaltGUI, если REST API работает. Попробуйте другой браузер или проверьте настройки безопасности браузера.

### Проблема: SaltGUI не находит настройки подключения

**Решение:** 
- Попробуйте обновить страницу (Ctrl+F5)
- Очистите кеш браузера
- Попробуйте другой браузер

## Альтернативный способ: Использование REST API напрямую

Если SaltGUI не работает, можно использовать REST API напрямую:

### Проверка minion серверов:
```bash
curl -X POST http://130.193.51.250:8000/run \
  -H "Content-Type: application/json" \
  -d '{
    "client": "local",
    "tgt": "*",
    "fun": "test.ping"
  }'
```

### Выполнение команды:
```bash
curl -X POST http://130.193.51.250:8000/run \
  -H "Content-Type: application/json" \
  -d '{
    "client": "local",
    "tgt": "*",
    "fun": "cmd.run",
    "arg": "uptime"
  }'
```

## Проверка статуса сервисов

```bash
ssh ubuntu@130.193.51.250
sudo systemctl status salt-api salt-master saltgui
```

Все сервисы должны быть `active (running)`.

## Логи для диагностики

```bash
# Логи Salt API
sudo journalctl -u salt-api -n 50

# Логи Salt Master
sudo journalctl -u salt-master -n 50

# Логи SaltGUI
sudo journalctl -u saltgui -n 50
```

## Контакты для помощи

Если проблема не решена, предоставьте:
1. Скриншот ошибки из консоли браузера (F12 → Console)
2. Скриншот запросов из Network (F12 → Network)
3. Результат `curl http://130.193.51.250:8000/`

