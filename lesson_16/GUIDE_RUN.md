# Гайд по запуску системы Kafka + ELK

Этот гайд описывает быстрый способ запуска всей инфраструктуры с помощью готовых скриптов.

## Быстрый старт

### Вариант 1: Автоматический запуск (рекомендуется)

```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_16
./start.sh
```

Скрипт автоматически:
1. Экспортирует переменные Yandex Cloud
2. Запустит `deploy-cluster.sh`
3. Развернет всю инфраструктуру

### Вариант 2: Пошаговый запуск

#### Шаг 1: Экспорт переменных Yandex Cloud

```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_16
source ../lesson_3/start.sh
```

Или вручную:
```bash
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
```

#### Шаг 2: Запуск развертывания

```bash
./deploy-cluster.sh
```

## Что происходит при запуске

1. **Проверка зависимостей** - проверяются наличие `terraform`, `ansible`, `yc`
2. **Terraform init** - инициализация провайдеров
3. **Terraform apply** - создание 3 ВМ:
   - Kafka node
   - ELK node  
   - APP node
4. **Ожидание готовности** - 60 секунд для завершения cloud-init
5. **Ansible deploy** - установка и настройка компонентов:
   - Kafka (2 брокера)
   - APP (nginx + Fluent Bit)
   - ELK (OpenSearch + Logstash + Dashboards)

## Время выполнения

- Terraform: ~2-3 минуты
- Ansible: ~5-10 минут (зависит от скорости скачивания Docker образов)
- **Итого: ~7-13 минут**

## После запуска

После успешного завершения вы увидите:
- IP адреса всех нод
- Команды для проверки
- Ссылки на веб-интерфейсы

## Остановка системы

Для полного удаления инфраструктуры:

```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_16
./cleanup.sh
```

**Внимание:** Все данные будут удалены!

## Устранение проблем при запуске

### Ошибка: "YC_TOKEN is not set"

**Решение:**
```bash
source ../lesson_3/start.sh
# или
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
```

### Ошибка: "terraform not found"

**Решение:**
```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install terraform

# Или через официальный репозиторий HashiCorp
```

### Ошибка: "ansible not found"

**Решение:**
```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install ansible
```

### Ошибка при terraform apply

**Возможные причины:**
- Недостаточно квот в Yandex Cloud
- Неправильные credentials
- Проблемы с сетью

**Решение:**
```bash
# Проверьте квоты
yc compute instance list

# Проверьте credentials
yc config list

# Проверьте логи
terraform apply -auto-approve 2>&1 | tee terraform.log
```

### Ошибка при Ansible deploy

**Возможные причины:**
- SSH ключи не настроены
- ВМ еще не готовы
- Проблемы с доступом к репозиториям

**Решение:**
```bash
# Увеличьте время ожидания в deploy-cluster.sh (строка 47)
sleep 120  # вместо 60

# Проверьте SSH доступ вручную
ssh -i ~/.ssh/id_ed25519 ubuntu@<IP>
```

## Полезные команды

### Проверка статуса Terraform

```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_3
terraform show
terraform output
```

### Просмотр логов Ansible

```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_3/ansible
ansible-playbook -i inventory.ini playbooks/site.yml -v  # verbose
ansible-playbook -i inventory.ini playbooks/site.yml -vv  # более подробно
```

### Перезапуск только одного компонента

```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_3/ansible

# Только Kafka
ansible-playbook -i inventory.ini playbooks/site.yml --limit kafka

# Только APP
ansible-playbook -i inventory.ini playbooks/site.yml --limit app

# Только ELK
ansible-playbook -i inventory.ini playbooks/site.yml --limit elk
```

## Следующие шаги

После успешного запуска:
1. Прочитайте [GUIDE_KAFKA_CHECK.md](GUIDE_KAFKA_CHECK.md) для проверки записи данных в топики Kafka
2. Изучите [GUIDE_SYSTEM.md](GUIDE_SYSTEM.md) для понимания архитектуры
3. Настройте мониторинг и алерты (опционально)

## Дополнительные руководства

- [GUIDE_INSTALL.md](GUIDE_INSTALL.md) - установка необходимых инструментов
- [GUIDE_SYSTEM.md](GUIDE_SYSTEM.md) - описание архитектуры системы
- [GUIDE_KAFKA_CHECK.md](GUIDE_KAFKA_CHECK.md) - проверка работы топиков Kafka

