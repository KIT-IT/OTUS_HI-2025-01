# Ansible Configuration

## Структура

```
ansible/
├── ansible.cfg          # Конфигурация Ansible
├── inventory.ini        # Автоматически генерируется Terraform
├── playbooks/
│   └── site.yml        # Главный playbook
├── group_vars/
│   └── all.yml         # Общие переменные (Kafka, ELK версии)
└── roles/
    ├── kafka/          # Установка Kafka (2 брокера)
    ├── app/            # Установка nginx и WordPress
    ├── log-agent/      # Установка Fluent Bit
    └── elk/            # Установка ELK стека
```

## Использование

После развертывания Terraform, inventory.ini автоматически создается.

Запуск playbook:
```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_16/ansible
ansible-playbook -i inventory.ini playbooks/site.yml
```

Или для отдельных компонентов:
```bash
# Только Kafka
ansible-playbook -i inventory.ini playbooks/site.yml --limit kafka

# Только APP
ansible-playbook -i inventory.ini playbooks/site.yml --limit app

# Только ELK
ansible-playbook -i inventory.ini playbooks/site.yml --limit elk
```

## Роли

- **kafka** - Устанавливает Docker, разворачивает 2 брокера Kafka в KRaft режиме, создает топики
- **app** - Устанавливает nginx, создает директории для логов WordPress
- **log-agent** - Устанавливает Fluent Bit, настраивает сбор логов nginx и wordpress, отправку в Kafka
- **elk** - Устанавливает Docker, разворачивает OpenSearch, Logstash, Dashboards, создает index patterns

