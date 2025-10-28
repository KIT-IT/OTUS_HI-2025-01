# Использование скриптов автоматизации

## start.sh - Полное развертывание

Главный скрипт для автоматического развертывания всего проекта:

```bash
./start.sh
```

Что делает:
1. Настраивает аутентификацию Yandex Cloud
2. Запускает `deploy-cluster.sh` для полного развертывания

## deploy-cluster.sh - Развертывание кластера

Основной скрипт развертывания:

```bash
./deploy-cluster.sh
```

Этапы:
1. **Terraform init & apply** - развертывание инфраструктуры
2. **Update inventory** - обновление Ansible inventory с IP адресами
3. **Wait for instances** - ожидание готовности виртуальных машин
4. **Ansible playbooks**:
   - `playbook-consul.yml` - установка Consul кластера
   - `playbook-web.yml` - установка nginx на веб-серверах
   - `playbook-register-services.yml` - регистрация сервисов в Consul
   - `playbook-dns-config.yml` - настройка DNS
5. **Show results** - вывод адресов для доступа

## cleanup.sh - Удаление инфраструктуры

Удаление всех ресурсов:

```bash
./cleanup.sh
```

⚠️ Требует подтверждения (введите `yes`)

## Примеры использования

### Полное развертывание с нуля
```bash
./start.sh
```

### Только развертывание кластера (если уже есть YC токены)
```bash
./deploy-cluster.sh
```

### Удаление и пересоздание
```bash
./cleanup.sh
./start.sh
```

### Проверка после развертывания
```bash
cd ansible
./healthcheck.sh <CONSUL_SERVER_IP> web
```
