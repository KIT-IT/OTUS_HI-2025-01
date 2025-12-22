# Telegram Webhook API

## Endpoint

**POST** `http://telegram-webhook:8080/telegram`

## Описание

Webhook endpoint для получения алертов от Alertmanager и отправки их в Telegram.

## Формат запроса

### Headers
```
Content-Type: application/json
```

### Body (Alertmanager format)

```json
{
  "alerts": [
    {
      "status": "firing",           // или "resolved"
      "labels": {
        "alertname": "HAProxyNoMaster",
        "severity": "critical",     // или "warning"
        "instance": "192.168.50.11:9100",
        "node": "ct-haproxy-1",
        "job": "node-haproxy",
        "cluster": "postgresql-ha-cluster"
      },
      "annotations": {
        "summary": "No HAProxy master available",
        "description": "No HAProxy node has the VIP. All nodes are in backup state."
      },
      "startsAt": "2025-12-19T00:00:00Z",    // ISO8601 timestamp
      "endsAt": "2025-12-19T00:05:00Z"        // только для resolved
    }
  ]
}
```

## Формат ответа

### Успешный ответ
```json
{
  "status": "ok"
}
```
HTTP Status: `200 OK`

### Ошибки
```json
{
  "error": "No data received"
}
```
HTTP Status: `400 Bad Request`

```json
{
  "error": "No alerts in data"
}
```
HTTP Status: `400 Bad Request`

```json
{
  "error": "Error message"
}
```
HTTP Status: `500 Internal Server Error`

## Примеры использования

### Пример 1: Критический алерт
```bash
curl -X POST http://telegram-webhook:8080/telegram \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [
      {
        "status": "firing",
        "labels": {
          "alertname": "HAProxyNoMaster",
          "severity": "critical",
          "instance": "192.168.50.11:9100"
        },
        "annotations": {
          "summary": "No HAProxy master available",
          "description": "No HAProxy node has the VIP"
        },
        "startsAt": "2025-12-19T00:00:00Z"
      }
    ]
  }'
```

### Пример 2: Предупреждение
```bash
curl -X POST http://telegram-webhook:8080/telegram \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [
      {
        "status": "firing",
        "labels": {
          "alertname": "HighCPUUsage",
          "severity": "warning",
          "instance": "192.168.50.21:9100"
        },
        "annotations": {
          "summary": "High CPU usage on 192.168.50.21:9100",
          "description": "CPU usage is above 80% for more than 5 minutes"
        },
        "startsAt": "2025-12-19T00:00:00Z"
      }
    ]
  }'
```

### Пример 3: Разрешенный алерт
```bash
curl -X POST http://telegram-webhook:8080/telegram \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [
      {
        "status": "resolved",
        "labels": {
          "alertname": "HAProxyNoMaster",
          "severity": "critical"
        },
        "annotations": {
          "summary": "HAProxy master restored",
          "description": "HAProxy master node is now available"
        },
        "startsAt": "2025-12-19T00:00:00Z",
        "endsAt": "2025-12-19T00:05:00Z"
      }
    ]
  }'
```

## Формат сообщения в Telegram

Сообщение форматируется в HTML и содержит:

- **Эмодзи статуса**: 🚨 для `firing`, ✅ для `resolved`
- **Название алерта** (из `labels.alertname`)
- **Severity** (из `labels.severity`)
- **Instance** (если есть в `labels.instance`)
- **Node** (если есть в `labels.node`)
- **Job** (если есть в `labels.job`)
- **Summary** (из `annotations.summary`)
- **Description** (из `annotations.description`)
- **Время начала** (из `startsAt`)
- **Время окончания** (из `endsAt`, только для resolved)

### Пример сообщения в Telegram:

```
🚨 ALERT FIRING

Alert: HAProxyNoMaster
Severity: critical
Instance: 192.168.50.11:9100
Node: ct-haproxy-1
Job: node-haproxy

Summary: No HAProxy master available
Description: No HAProxy node has the VIP. All nodes are in backup state.

Started: 2025-12-19T00:00:00Z
─────────────────────
```

## Health Check

**GET** `http://telegram-webhook:8080/health`

### Ответ
```json
{
  "status": "ok"
}
```

## Конфигурация

Переменные окружения:
- `TELEGRAM_BOT_TOKEN` - токен Telegram бота
- `TELEGRAM_CHAT_ID` - Chat ID для отправки сообщений



