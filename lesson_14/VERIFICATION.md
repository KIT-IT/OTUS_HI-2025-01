# Инструкция по проверке Consul кластера и Service Discovery

## Структура окружения

### Consul серверы:
- `consul-server-1`: 51.250.1.88 (внутр. 10.20.0.12)
- `consul-server-2`: 51.250.95.217 (внутр. 10.20.0.25)  
- `consul-server-3`: 46.21.246.91 (внутр. 10.20.0.23)

### Consul клиент:
- `consul-client-1`: 62.84.114.1 (внутр. 10.20.0.14)

### Web серверы:
- `web-1`: 51.250.7.12 (внутр. 10.20.0.3)
- `web-2`: 84.201.129.218 (внутр. 10.20.0.38)
- `web-3`: 89.169.129.29 (внутр. 10.20.0.29)

---

## Проверка 1: Доступность Consul UI

```bash
# Откройте в браузере
http://51.250.1.88:8500/ui/
```

В интерфейсе вы должны увидеть:
- Все 3 consul-server ноды
- 1 consul-client ноду
- Зарегистрированный сервис `web` с 3 экземплярами

---

## Проверка 2: DNS резолвинг через Consul (Round-Robin)

Подключитесь к одному из consul-server и проверьте DNS:

```bash
# SSH на consul-server
ssh ubuntu@51.250.1.88

# Проверка DNS через Consul (должен вернуть разные IP в каждый запрос)
dig @127.0.0.1 -p 8600 web.service.consul +short

# Повторите несколько раз
for i in {1..6}; do 
  echo "Запрос $i:"
  dig @127.0.0.1 -p 8600 web.service.consul +short
  echo ""
done
```

Результат: Должны получать разные IP адреса в round-robin порядке

---

## Проверка 3: Проверка здоровья сервисов

```bash
# Проверка health checks через API
curl http://51.250.1.88:8500/v1/health/service/web?passing

# Вывод всех IP адресов web сервисов
curl http://51.250.1.88:8500/v1/health/service/web | jq -r '.[].Service.Address'
```

Ожидаемый результат:
```
10.20.0.3
10.20.0.38
10.20.0.29
```

---

## Проверка 4: Проверка доступности web серверов

```bash
# Проверка каждого web сервера напрямую
curl http://51.250.7.12
curl http://84.201.129.218
curl http://89.169.129.29
```

Все должны возвращать HTML страницу с информацией о сервере.

---

## Проверка 5: Автоматическое удаление из DNS при падении сервера

### Шаг 1: Проверьте текущие сервисы
```bash
ssh ubuntu@51.250.1.88
dig @127.0.0.1 -p 8600 web.service.consul +short
```

Должны получить 3 IP адреса: `10.20.0.3`, `10.20.0.38`, `10.20.0.29`

### Шаг 2: Остановите nginx на одном из серверов
```bash
# Остановим nginx на web-1
ssh ubuntu@51.250.7.12 "sudo systemctl stop nginx"
```

### Шаг 3: Подождите 10-30 секунд для обновления health check
```bash
sleep 30
```

### Шаг 4: Проверьте DNS снова
```bash
# На consul-server
ssh ubuntu@51.250.1.88
dig @127.0.0.1 -p 8600 web.service.consul +short
```

**Ожидаемый результат**: Теперь должны получить только 2 IP адреса (без IP web-1)

### Шаг 5: Проверьте через Consul API
```bash
curl http://localhost:8500/v1/health/service/web?passing | jq '.[].Service.Address'
```

Должны увидеть только IP работающих серверов.

### Шаг 6: Восстановите сервер
```bash
ssh ubuntu@51.250.7.12 "sudo systemctl start nginx"
```

### Шаг 7: Снова проверьте DNS
```bash
# Подождите 10 секунд
sleep 10

# Снова проверьте
dig @127.0.0.1 -p 8600 web.service.consul +short
```

**Ожидаемый результат**: Все 3 IP адреса снова в DNS

---

## Проверка 6: Проверка членов кластера Consul

```bash
# Проверка через Docker на consul-server
ssh ubuntu@51.250.1.88
docker exec consul curl -s http://localhost:8500/v1/status/leader
docker exec consul curl -s http://localhost:8500/v1/status/peers
```

Должны увидеть:
- Leader: IP одного из consul-server
- Peers: список из 3 IP адресов серверов

---

## Проверка 7: Использование DNS через client

```bash
# На consul-client
ssh ubuntu@62.84.114.1
dig @127.0.0.1 -p 8600 web.service.consul +short
```

Должен получить IP адреса web серверов.

---

## Быстрая проверка всех компонентов

```bash
# Выполните на локальной машине
cat << 'EOF'
=== Быстрая проверка всех компонентов ===
EOF

echo "1. Consul UI доступность:"
curl -I http://51.250.1.88:8500/ui/ | grep "HTTP"

echo ""
echo "2. Web серверы доступны:"
for ip in 51.250.7.12 84.201.129.218 89.169.129.29; do
  echo -n "$ip: "
  curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 http://$ip
done

echo ""
echo "3. DNS резолвинг через Consul:"
ssh ubuntu@51.250.1.88 "dig @127.0.0.1 -p 8600 web.service.consul +short" 2>&1 | cat

echo ""
echo "4. Health checks:"
ssh ubuntu@51.250.1.88 "curl -s http://localhost:8500/v1/health/service/web | jq -r '.[] | .Service.Address + \": \" + .Checks[0].Status'" 2>&1 | cat

cat << 'EOF'

=== Проверка завершена ===
EOF
```

---

## Проверка балансировки нагрузки

### Через браузер
1. Откройте любую страницу через прямую ссылку
2. Обновите страницу несколько раз
3. В случае балансировки через proxy вы должны получать ответы от разных серверов

### Через curl (имитация round-robin)
```bash
# Запустите несколько запросов через DNS Consul
ssh ubuntu@51.250.1.88
for i in {1..10}; do
  IP=$(dig @127.0.0.1 -p 8600 web.service.consul +short | head -1)
  curl -s "http://$IP" | grep -o "<title>.*</title>"
  sleep 1
done
```

Вы должны получить HTML от разных серверов по round-robin.

---

## Troubleshooting

### Consul UI не открывается
```bash
# Проверьте порт 8500
ssh ubuntu@51.250.1.88 "sudo ss -tlnp | grep 8500"

# Проверьте firewall
ssh ubuntu@51.250.1.88 "sudo iptables -L -n | grep 8500"

# Проверьте security group в Terraform
cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_14/terraform
terraform show | grep -A 5 "port.*8500"
```

### DNS не возвращает IP адреса
```bash
# Проверьте зарегистрированные сервисы
ssh ubuntu@51.250.1.88 "curl -s http://localhost:8500/v1/catalog/services"

# Проверьте health checks
ssh ubuntu@51.250.1.88 "curl -s http://localhost:8500/v1/health/service/web"
```

### Web сервер не отвечает
```bash
# SSH на проблемный сервер
ssh ubuntu@IP_СЕРВЕРА

# Проверьте nginx
sudo systemctl status nginx
sudo systemctl status consul

# Проверьте логи
sudo journalctl -u nginx -n 50
sudo journalctl -u consul -n 50
```

---