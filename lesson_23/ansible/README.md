# Ansible Configuration для Salt

## Структура

```
ansible/
├── ansible.cfg          # Конфигурация Ansible
├── inventory.ini        # Автоматически генерируется Terraform
├── playbooks/
│   ├── site.yml        # Главный playbook (установка Salt)
│   └── apply-salt-states.yml  # Применение Salt States
├── group_vars/
│   └── all.yml         # Общие переменные
└── roles/
    ├── salt-master/    # Установка Salt Master
    └── salt-minion/    # Установка Salt Minion
```

## Использование

### Автоматическое развертывание

После развертывания Terraform, inventory.ini автоматически создается.

Запуск полного развертывания:

```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_23
./start.sh
```

Этот скрипт:
1. Развернет инфраструктуру через Terraform
2. Автоматически запустит Ansible playbook для установки Salt

### Ручной запуск Ansible

```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_23/ansible

# Проверка подключения
ansible all -m ping

# Установка Salt Master и Minion
ansible-playbook playbooks/site.yml

# Применение Salt States
ansible-playbook playbooks/apply-salt-states.yml
```

### Установка отдельных компонентов

```bash
# Только Salt Master
ansible-playbook playbooks/site.yml --limit salt_master

# Только Nginx серверы
ansible-playbook playbooks/site.yml --limit nginx

# Только Backend серверы
ansible-playbook playbooks/site.yml --limit backend
```

## Роли

### salt-master
- Устанавливает Salt Master через bootstrap скрипт
- Настраивает конфигурацию `/etc/salt/master`
- Создает директории `/srv/salt` и `/srv/pillar`
- Запускает и включает сервис salt-master

### salt-minion
- Устанавливает Salt Minion через bootstrap скрипт
- Настраивает подключение к Salt Master
- Настраивает конфигурацию `/etc/salt/minion`
- Запускает и включает сервис salt-minion

## Переменные

Все переменные определены в `group_vars/all.yml`:

- `salt_master_interface` - интерфейс для Salt Master (по умолчанию 0.0.0.0)
- `salt_master_publish_port` - порт для публикации (4505)
- `salt_master_ret_port` - порт для возврата (4506)
- `salt_master_auto_accept` - автоматическое принятие ключей (true для тестирования)
- `salt_minion_master_port` - порт Master для Minion (4506)

## Inventory

Inventory автоматически генерируется Terraform и содержит:

- `[salt_master]` - Salt Master сервер
- `[nginx]` - Nginx серверы (2 сервера)
- `[backend]` - Backend серверы (2 сервера, доступ через SSH jump host)

Backend серверы доступны через SSH jump host (Salt Master), так как у них нет публичного IP.

## Troubleshooting

### Проблемы с подключением к Backend серверам

Backend серверы доступны только через Salt Master. Убедитесь, что:
1. Salt Master имеет публичный IP
2. SSH ключ настроен правильно
3. ProxyCommand настроен в inventory

### Проблемы с установкой Salt

Если установка не удалась:
1. Проверьте логи: `ansible-playbook playbooks/site.yml -vvv`
2. Проверьте подключение: `ansible all -m ping`
3. Проверьте доступность bootstrap скрипта: `curl -L https://bootstrap.saltproject.io`

### Проблемы с принятием ключей

Если ключи не принимаются:
1. Проверьте, что `auto_accept: true` в конфигурации Master
2. Или примите ключи вручную на Salt Master: `salt-key -A`

