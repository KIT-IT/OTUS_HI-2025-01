# Consul Cluster для Service Discovery и DNS

Этот проект реализует Consul кластер для управления DNS-записями веб-портала с отказоустойчивой балансировкой нагрузки через DNS.

## Архитектура

- **3 сервера Consul** - образуют кластер для управления сервисами
- **1 клиент Consul** - используется для доступа к DNS
- **3 веб-сервера nginx** - простые HTTP серверы на порту 80
- **1 OpenSearch node** - сбор и анализ логов
- **Fluentd** - агент сбора логов на веб-серверах

## Что реализовано

1. Consul cluster с 3 серверами и 1 клиентом
2. Регистрация веб-сервисов (nginx) в Consul
3. DNS через Consul для разрешения имен сервисов
4. Плавающий IP отключен - используется Consul DNS для балансировки
5. Автоматическое удаление IP неработающих сервисов из DNS
6. Health check скрипт для проверки работоспособности
7. OpenSearch + Dashboard для централизованного логирования
8. Fluentd собирает логи nginx и отправляет в OpenSearch

## Быстрый старт

```bash
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_14
./start.sh
```

Один скрипт развернет всю инфраструктуру и настроит сервисы автоматически!

## Структура проекта

```
lesson_14/
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # Основная конфигурация Terraform
│   ├── variables.tf       # Переменные
│   ├── outputs.tf         # Выходные значения
│   ├── provider.tf        # Провайдер Yandex Cloud
│   └── terraform.tfvars   # Значения переменных (не в git)
├── ansible/               # Автоматизация конфигурации
│   ├── inventory.yml      # Инвентарь Ansible
│   ├── playbook-consul.yml           # Установка Consul кластера
│   ├── playbook-web.yml              # Установка nginx на веб-серверах
│   ├── playbook-register-services.yml  # Регистрация сервисов
│   ├── playbook-dns-config.yml        # Настройка DNS
│   ├── playbook-opensearch.yml        # Установка OpenSearch + Dashboard
│   ├── playbook-fluentd.yml            # Установка Fluentd для сбора логов
│   ├── update-inventory.sh # Автоматическое обновление inventory
│   ├── healthcheck.sh     # Скрипт проверки здоровья
│   └── templates/         # Jinja2 шаблоны
│       ├── consul-*.json.j2          # Конфигурация Consul
│       ├── docker-compose-opensearch.yml.j2  # Docker Compose для OpenSearch
│       ├── fluentd.conf.j2           # Конфигурация Fluentd
│       ├── nginx-template.json.j2   # Index template для OpenSearch
│       └── fluentd.service.j2       # Systemd unit для Fluentd
└── README.md             # Этот файл
```

## Предварительные требования

1. Terraform >= 1.6.0
2. Ansible >= 2.9
3. Yandex Cloud аккаунт и API ключ
4. SSH ключ для доступа к виртуальным машинам
5. `dig` (dnsutils) для проверки DNS

## Установка

### 1. Настройка Terraform

Скопируйте `terraform.tfvars.example` в `terraform.tfvars` и заполните необходимые параметры:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Отредактируйте terraform.tfvars
```

Минимальные параметры:
- `yc_token` - токен доступа к Yandex Cloud
- `yc_cloud_id` - ID облака
- `yc_folder_id` - ID каталога
- `ssh_public_key` - публичный SSH ключ

### 2. Создание инфраструктуры

```bash
cd terraform

# Инициализация Terraform
terraform init

# Планирование изменений
terraform plan

# Применение изменений
terraform apply
```

После выполнения команды будут созданы:
- Consul servers (3 инстанса)
- Consul client (1 инстанс)
- Web servers (3 nginx сервера)
- OpenSearch node (1 инстанс с Docker)
- Networking и security groups

### 3. Получение IP-адресов

После успешного развертывания получите IP-адреса:

```bash
terraform output
```

Сохраните следующие значения:
- `consul_servers_ips` - публичные IP Consul серверов
- `consul_servers_private_ips` - приватные IP Consul серверов
- `consul_client_ip` - публичный IP Consul клиента
- `web_public_ip` - публичный IP Saleor
- `web_public_ip` - публичный IP nginx

### 4. Настройка Ansible

Обновите файл `ansible/inventory.yml` с реальными IP-адресами:

```yaml
consul_servers:
  hosts:
    consul-server-1:
      ansible_host: <CONSUL_SERVER_1_PUBLIC_IP>
    consul-server-2:
      ansible_host: <CONSUL_SERVER_2_PUBLIC_IP>
    consul-server-3:
      ansible_host: <CONSUL_SERVER_3_PUBLIC_IP>

consul_clients:
  hosts:
    consul-client-1:
      ansible_host: <CONSUL_CLIENT_PUBLIC_IP>

web_servers:
  hosts:
    web:
      ansible_host: <SALEOR_PUBLIC_IP>
      ansible_host_private: <SALEOR_PRIVATE_IP>
    web:
      ansible_host: <STOREFRONT_PUBLIC_IP>
      ansible_host_private: <STOREFRONT_PRIVATE_IP>
```

### 5. Развертывание Consul и веб-серверов

```bash
cd ansible

# Развертывание Consul кластера
ansible-playbook -i inventory.yml playbook-consul.yml

# Установка nginx на веб-серверах
ansible-playbook -i inventory.yml playbook-web.yml

# Регистрация веб-сервисов в Consul
ansible-playbook -i inventory.yml playbook-register-services.yml

# Настройка DNS
ansible-playbook -i inventory.yml playbook-dns-config.yml
```

### 6. Проверка работы

Используйте скрипт healthcheck:

```bash
./healthcheck.sh <CONSUL_SERVER_PUBLIC_IP> web
```

Или вручную:

```bash
# Проверка кластера Consul
ssh ubuntu@<CONSUL_SERVER_IP> "/opt/consul/bin/consul members"

# Проверка DNS через Consul
dig @<CONSUL_SERVER_IP> -p 8600 web.service.consul

# Проверка веб-сервисов
curl http://<SALEOR_IP>:8000/graphql/
curl http://<STOREFRONT_IP>:3000/
```

## Тестирование отказоустойчивости

### Тест 1: Проверка DNS round-robin

```bash
# Запрос DNS несколько раз подряд
for i in {1..5}; do
  dig @<CONSUL_SERVER_IP> -p 8600 web.service.consul +short
done
```

Должны получить разные IP-адреса при наличии нескольких инстансов.

### Тест 2: Отказ сервиса

1. Остановите один из веб-серверов:
   ```bash
   ssh ubuntu@<SALEOR_IP> "sudo systemctl stop <service>"
   ```

2. Подождите 30 секунд (время deregister_critical_service_after)

3. Проверьте DNS:
   ```bash
   dig @<CONSUL_SERVER_IP> -p 8600 web.service.consul +short
   ```

   IP остановленного сервиса должен исчезнуть из DNS-ответа.

### Тест 3: Восстановление сервиса

```bash
# Запустите сервис обратно
ssh ubuntu@<SALEOR_IP> "sudo systemctl start <service>"
```

Через 10-30 секунд IP должен снова появиться в DNS-ответе.

## Consul UI

Для визуального мониторинга кластера:

1. Откройте браузер
2. Перейдите на `http://<CONSUL_SERVER_IP>:8500`
3. Посмотрите:
   - Nodes - список узлов кластера
   - Services - зарегистрированные сервисы
   - Services > web/web - детали сервисов и health checks

## Как это работает

1. **Service Registration**: Веб-сервисы (Saleor, nginx) регистрируют себя в Consul при старте
2. **Health Checks**: Consul периодически проверяет здоровье сервисов (HTTP запросы каждые 10 секунд)
3. **DNS**: Consul предоставляет DNS-сервер на порту 8600, который отвечает IP-адресами только здоровых сервисов
4. **Automatic Deregistration**: При падении сервиса его health check начинает fail, и через 30 секунд IP удаляется из DNS
5. **Round-robin**: При наличии нескольких инстансов одного сервиса, DNS возвращает разные IP при каждом запросе

## Troubleshooting

### Consul сервисы не запускаются

Проверьте логи:
```bash
ssh ubuntu@<CONSUL_IP> "sudo journalctl -u consul -n 100"
```

### DNS не работает

1. Проверьте, что Consul DNS слушает на порту 8600:
   ```bash
   ssh ubuntu@<CONSUL_IP> "netstat -tlnp | grep 8600"
   ```

2. Проверьте firewall и security groups

### Сервисы не регистрируются

1. Проверьте, что web-серверы могут подключиться к Consul:
   ```bash
   ssh ubuntu@<WEB_IP> "curl http://<CONSUL_PRIVATE_IP>:8500/v1/status/leader"
   ```

2. Проверьте логи Consul на web-серверах:
   ```bash
   ssh ubuntu@<WEB_IP> "sudo journalctl -u consul -n 100"
   ```

## Очистка

Для удаления всех ресурсов:

```bash
cd terraform
terraform destroy
```

## OpenSearch и Централизованное Логирование

### Что реализовано

- **OpenSearch** (в Docker) - поисковый движок для хранения и анализа логов
- **OpenSearch Dashboard** - веб-интерфейс для визуализации логов
- **Fluentd** - агент на каждом веб-сервере для сбора логов nginx
- Автоматическая индексация логов с полем `@timestamp` типа `date`

### Работа с логами

#### Доступ к OpenSearch
- API: `http://<OPENSEARCH_IP>:9200`
- Dashboard: `http://<OPENSEARCH_IP>:5601`

#### Проверка логов через API

```bash
# Подсчет логов
curl "http://<OPENSEARCH_IP>:9200/nginx-*/_count"

# Поиск последних логов
curl "http://<OPENSEARCH_IP>:9200/nginx-*/_search?size=10&sort=@timestamp:desc"

# Проверка индексов
curl "http://<OPENSEARCH_IP>:9200/_cat/indices/nginx*?v"
```

#### Настройка Dashboard для просмотра логов

1. Откройте OpenSearch Dashboard: http://<OPENSEARCH_IP>:5601
2. Перейдите в: **Management** → **Stack Management** → **Index Patterns**
3. Нажмите **Create index pattern**
4. Введите: `nginx-*`
5. Выберите **@timestamp** в качестве time field
6. Нажмите **Create index pattern**
7. Откройте **Analytics** → **Discover** для просмотра логов

### Генерация тестового трафика

Для создания логов:

```bash
# Генерация запросов к веб-серверам
for i in {1..10}; do 
  curl http://<WEB_SERVER_IP_1>
  curl http://<WEB_SERVER_IP_2>
  curl http://<WEB_SERVER_IP_3>
  sleep 1
done
```

Логи автоматически отправляются в OpenSearch через Fluentd.

### Структура данных в логах

```json
{
  "@timestamp": "2025-10-28T22:37:00.000000000+00:00",
  "hostname": "web-server-1",
  "log_type": "nginx_access",
  "method": "GET",
  "path": "/",
  "code": "200",
  "remote": "10.20.0.x",
  "agent": "curl/7.68.0"
}
```

## Дополнительные возможности

- **ACL** (Access Control Lists) - для безопасности Consul
- **Connect** - для автоматического шифрования соединений между сервисами
- **External DNS** - интеграция с реальным DNS провайдером
- **Multi-datacenter** - кластер в нескольких дата-центрах
- **Custom dashboards** - создание собственных визуализаций в OpenSearch Dashboard
- **Alerting** - настройка уведомлений о проблемах
- **Колонки в логах** - добавление дополнительных меток для фильтрации

