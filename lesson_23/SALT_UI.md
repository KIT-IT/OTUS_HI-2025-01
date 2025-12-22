# Salt Web UI - SaltGUI

## Что такое SaltGUI?

**SaltGUI** - это open-source веб-интерфейс для управления инфраструктурой через SaltStack. Он предоставляет удобный графический интерфейс для:

- Просмотра всех minion серверов
- Выполнения команд на серверах
- Применения Salt States
- Просмотра результатов выполнения команд
- Управления ключами minion
- Мониторинга состояния серверов

## Архитектура

SaltGUI работает через **Salt REST API (CherryPy)**, который встроен в Salt Master:

```
┌─────────────┐
│  SaltGUI    │ (веб-интерфейс, порт 8001)
│  Frontend   │
└──────┬──────┘
       │ HTTP запросы
       ▼
┌─────────────┐
│ Salt REST   │ (REST API, порт 8000)
│ API         │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Salt Master │
└─────────────┘
```

## Установка SaltGUI

SaltGUI устанавливается автоматически через Ansible роль при развертывании Salt Master.

### Автоматическая установка

```bash
cd ansible
ansible-playbook playbooks/site.yml --limit salt_master
```

### Ручная установка

Если нужно установить вручную на Salt Master:

```bash
# Установить зависимости
sudo apt-get install -y git python3-pip python3-dev
sudo pip3 install cherrypy ws4py

# Клонировать SaltGUI
sudo git clone https://github.com/erwindon/SaltGUI.git /opt/saltgui

# Настроить Salt Master для REST API
sudo tee -a /etc/salt/master <<EOF
# REST API для SaltGUI
rest_cherrypy:
  port: 8000
  host: 0.0.0.0
  disable_ssl: true
  webhook_url: /hook
EOF

# Перезапустить Salt Master
sudo systemctl restart salt-master

# Запустить SaltGUI (простой HTTP сервер для фронтенда)
cd /opt/saltgui
sudo python3 -m http.server 8001
```

## Доступ к SaltGUI

После установки:

1. **Salt REST API** доступен на: `http://<salt-master-ip>:8000`
2. **SaltGUI Frontend** доступен на: `http://<salt-master-ip>:8001`

Например:
- REST API: `http://130.193.51.250:8000`
- SaltGUI: `http://130.193.51.250:8001`

## Настройка Security Group

Убедитесь, что порты 8000 и 8001 открыты в Security Group для Salt Master:

```bash
# В Terraform уже настроено для порта 8000
# Для порта 8001 можно добавить вручную или через Terraform
cd terraform
terraform apply
```

## Использование SaltGUI

### Основные функции

1. **Minions** - просмотр всех подключенных minion серверов
2. **Jobs** - просмотр истории выполнения команд и состояний
3. **Keys** - управление ключами minion (принять/отклонить)
4. **Run** - выполнение команд на серверах
5. **States** - применение Salt States

### Примеры использования

#### Просмотр всех minion
В интерфейсе перейдите в раздел "Minions" - увидите список всех подключенных серверов.

#### Выполнение команды
1. Перейдите в "Run"
2. Выберите minion или используйте `*` для всех
3. Введите команду (например, `uptime`)
4. Нажмите "Run"

#### Применение States
1. Перейдите в "States"
2. Выберите minion
3. Выберите state для применения
4. Нажмите "Apply"

## Альтернативные UI для Salt

### 1. SaltGUI (установлен)
- **Тип**: Open-source
- **GitHub**: https://github.com/erwindon/SaltGUI
- **Порты**: 8000 (REST API), 8001 (Frontend)
- **Особенности**: Простой, легковесный, не требует базы данных

### 2. Salt.Box
- **Тип**: Open-source
- **Сайт**: https://saltbox.pro
- **Особенности**: Более продвинутый интерфейс, визуализация состояний

### 3. SaltStack Enterprise (коммерческий)
- **Тип**: Коммерческий
- **Особенности**: Полнофункциональное enterprise-решение с LDAP, RBAC и т.д.

## Troubleshooting

### Salt REST API не отвечает

```bash
# Проверить конфигурацию
sudo salt-api -d

# Проверить логи
sudo tail -f /var/log/salt/api

# Проверить статус
sudo systemctl status salt-master
```

### SaltGUI не загружается

```bash
# Проверить, что HTTP сервер запущен
ps aux | grep "http.server"

# Проверить порт
sudo netstat -tlnp | grep 8001

# Перезапустить
cd /opt/saltgui
sudo python3 -m http.server 8001
```

## Обновление документации

После установки SaltGUI обновите README.md с информацией о веб-интерфейсе.
