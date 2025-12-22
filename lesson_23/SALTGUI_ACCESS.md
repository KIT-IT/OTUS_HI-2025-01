# Как зайти в SaltGUI

## Шаг 1: Откройте интерфейс в браузере

Откройте в любом браузере:
```
http://130.193.51.250:8001
```

Вы увидите интерфейс SaltGUI с заголовком "Manual Run".

## Шаг 2: Настройте подключение к Salt REST API

SaltGUI - это фронтенд, который работает с Salt REST API. Нужно указать URL REST API:

1. **Найдите кнопку настроек** (обычно это иконка ⚙️ или "Settings" в правом верхнем углу)
2. **Введите URL Salt REST API:**
   ```
   http://130.193.51.250:8000
   ```
3. **Сохраните настройки**

## Шаг 3: Использование SaltGUI

После настройки подключения вы сможете:

### Просмотр Minion серверов
- Перейдите в раздел **"Minions"** или **"Keys"**
- Увидите список всех подключенных серверов (salt-master, nginx-1, nginx-2, backend-1, backend-2)

### Выполнение команд
1. Перейдите в раздел **"Run"** или **"Manual Run"**
2. Выберите minion (или используйте `*` для всех)
3. Введите команду, например:
   - `test.ping` - проверить доступность
   - `cmd.run 'uptime'` - выполнить команду
   - `state.apply` - применить Salt States
4. Нажмите **"Run"**

### Применение Salt States
1. Перейдите в раздел **"States"**
2. Выберите minion
3. Выберите state для применения (например, `nginx`, `iptables`)
4. Нажмите **"Apply"**

### Управление ключами
- Перейдите в раздел **"Keys"**
- Увидите список всех minion ключей
- Можете принять/отклонить ключи

## Альтернативный способ: через REST API напрямую

Если интерфейс не работает, можно использовать REST API напрямую:

### Проверка доступности minion
```bash
curl -X POST http://130.193.51.250:8000/run \
  -H "Content-Type: application/json" \
  -d '{
    "client": "local",
    "tgt": "*",
    "fun": "test.ping"
  }'
```

### Выполнение команды
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

## Troubleshooting

### SaltGUI не подключается к REST API

1. **Проверьте, что REST API работает:**
   ```bash
   curl http://130.193.51.250:8000/
   ```
   Должен вернуть информацию о Salt API

2. **Проверьте статус сервисов:**
   ```bash
   ssh ubuntu@130.193.51.250
   sudo systemctl status salt-api salt-master
   ```

3. **Проверьте логи:**
   ```bash
   sudo journalctl -u salt-api -n 50
   ```

### Интерфейс не загружается

1. **Проверьте, что сервис saltgui запущен:**
   ```bash
   ssh ubuntu@130.193.51.250
   sudo systemctl status saltgui
   ```

2. **Проверьте порт:**
   ```bash
   sudo ss -tlnp | grep 8001
   ```

3. **Перезапустите сервис:**
   ```bash
   sudo systemctl restart saltgui
   ```

## Дополнительная информация

- **SaltGUI Frontend:** http://130.193.51.250:8001
- **Salt REST API:** http://130.193.51.250:8000
- **Документация SaltGUI:** https://github.com/erwindon/SaltGUI

