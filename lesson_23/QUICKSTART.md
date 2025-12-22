# Быстрый старт

## Что было создано

✅ Terraform конфигурация для развертывания инфраструктуры на Яндекс.Облаке
✅ Ansible роли для установки Salt Master и Minion
✅ Salt States для управления Nginx
✅ Salt States для управления iptables
✅ Автоматическое развертывание через Ansible
✅ Подробная документация

## Структура проекта

```
lesson_23/
├── terraform/          # Terraform конфигурация
├── ansible/           # Ansible роли и playbooks
│   ├── roles/
│   │   ├── salt-master/
│   │   └── salt-minion/
│   └── playbooks/
├── salt/              # Salt States
├── pillar/            # Pillar данные
├── scripts/           # Скрипты развертывания
├── README.md          # Основная документация
├── APPLY.md           # Инструкция по применению
└── start.sh           # Скрипт запуска
```

## Быстрый запуск (3 команды)

```bash
# 1. Экспорт переменных Яндекс.Облака
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)

# 2. Развертывание инфраструктуры
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_23
./start.sh

# 3. Применить Salt States (автоматически или вручную)
cd ansible && ansible-playbook playbooks/apply-salt-states.yml
```

## Что будет создано

- **1 Salt Master** - управляющий сервер
- **2 Nginx сервера** - веб-серверы с балансировкой
- **2 Backend сервера** - серверы приложений

## Что происходит при запуске

Скрипт `./start.sh` автоматически:
1. ✅ Развертывает инфраструктуру через Terraform
2. ✅ Устанавливает Salt Master через Ansible
3. ✅ Устанавливает Salt Minion на всех серверах через Ansible
4. ✅ Копирует Salt States и Pillar на Salt Master
5. ✅ Принимает ключи Minion

## Следующие шаги

После автоматического развертывания:

1. Применить Salt States: `cd ansible && ansible-playbook playbooks/apply-salt-states.yml`
2. Или вручную на Salt Master: `sudo salt '*' state.apply`

## Полезные команды

```bash
# Получить IP Salt Master
cd terraform && terraform output salt_master_external_ip

# Подключиться к Salt Master
ssh ubuntu@$(cd terraform && terraform output -raw salt_master_external_ip)

# Удалить всю инфраструктуру
cd terraform && terraform destroy
```

## Документация

- **README.md** - полное описание проекта
- **APPLY.md** - подробная инструкция по применению Salt States

