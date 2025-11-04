# Руководство по проверке топиков Kafka

Это руководство описывает различные способы проверки того, что данные успешно записываются в топики Kafka и могут быть прочитаны.

## Содержание

1. [Проверка количества сообщений (offsets)](#1-проверка-количества-сообщений-offsets)
2. [Чтение сообщений из топиков](#2-чтение-сообщений-из-топиков)
3. [Детальная информация о топиках](#3-детальная-информация-о-топиках)
4. [Генерация тестовых логов](#4-генерация-тестовых-логов)
5. [Мониторинг в реальном времени](#5-мониторинг-в-реальном-времени)
6. [Проверка работы Fluent Bit](#6-проверка-работы-fluent-bit)

## Предварительные требования

- Доступ к Kafka узлу по SSH
- IP-адрес Kafka узла (можно получить командой `terraform output -raw kafka_external_ip`)

## 1. Проверка количества сообщений (offsets)

Самый простой способ проверить, что данные пишутся в топики — это проверить смещения (offsets) в топиках. Смещение — это позиция последнего сообщения в топике.

### Подключение к Kafka узлу

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@<KAFKA_IP>
```

Замените `<KAFKA_IP>` на IP-адрес вашего Kafka узла.

### Проверка смещений в топике nginx

```bash
sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
  kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092,localhost:9093 \
  --topic nginx --time -1
```

**Ожидаемый вывод:**
```
nginx:0:37
nginx:1:59
```

Это означает, что:
- В партиции 0 топика `nginx` находится 37 сообщений
- В партиции 1 топика `nginx` находится 59 сообщений
- Всего: 96 сообщений в топике `nginx`

### Проверка смещений в топике wordpress

```bash
sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
  kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092,localhost:9093 \
  --topic wordpress --time -1
```

**Ожидаемый вывод:**
```
wordpress:0:0
wordpress:1:4
```

Это означает, что:
- В партиции 0 топика `wordpress` находится 0 сообщений
- В партиции 1 топика `wordpress` находится 4 сообщения
- Всего: 4 сообщения в топике `wordpress`

### Проверка динамики записи

Чтобы проверить, что данные действительно пишутся в реальном времени:

1. Зафиксируйте текущие смещения:
   ```bash
   sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
     kafka-run-class kafka.tools.GetOffsetShell \
     --broker-list localhost:9092,localhost:9093 \
     --topic nginx --time -1
   ```

2. Сгенерируйте новые логи (на APP узле):
   ```bash
   ssh -i ~/.ssh/id_ed25519 ubuntu@<APP_IP>
   for i in {1..5}; do curl -s http://localhost > /dev/null; sleep 1; done
   ```

3. Снова проверьте смещения — они должны увеличиться:
   ```bash
   sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
     kafka-run-class kafka.tools.GetOffsetShell \
     --broker-list localhost:9092,localhost:9093 \
     --topic nginx --time -1
   ```

## 2. Чтение сообщений из топиков

### Чтение последних N сообщений из топика

Чтобы прочитать последние 5 сообщений из топика `nginx`:

```bash
sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
  kafka-console-consumer \
  --bootstrap-server localhost:9092,localhost:9093 \
  --topic nginx --from-beginning --max-messages 5
```

**Ожидаемый вывод:**
```json
{"@timestamp":1762279757.4214,"log":"204.76.203.211 - - [04/Nov/2025:18:09:17 +0000] \"GET / HTTP/1.1\" 200 166 \"-\" \"Hello World\"","source_type":"nginx"}
{"@timestamp":1762279774.744989,"log":"83.219.234.85 - - [04/Nov/2025:18:09:34 +0000] \"GET / HTTP/1.1\" 304 0 \"-\" \"Mozilla/5.0...\"","source_type":"nginx"}
...
```

### Чтение всех сообщений с начала

Чтобы прочитать все сообщения с начала топика:

```bash
sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
  kafka-console-consumer \
  --bootstrap-server localhost:9092,localhost:9093 \
  --topic nginx --from-beginning
```

**Внимание:** Эта команда будет читать все сообщения до тех пор, пока вы не остановите её (Ctrl+C).

### Чтение только новых сообщений

Чтобы читать только новые сообщения (те, которые приходят после запуска команды):

```bash
sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
  kafka-console-consumer \
  --bootstrap-server localhost:9092,localhost:9093 \
  --topic nginx
```

### Чтение сообщений из топика wordpress

```bash
sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
  kafka-console-consumer \
  --bootstrap-server localhost:9092,localhost:9093 \
  --topic wordpress --from-beginning --max-messages 5
```

**Ожидаемый вывод:**
```json
{"@timestamp":1762291346.782393,"log":"New log entry Tue 04 Nov 2025 09:22:26 PM UTC","source_type":"wordpress"}
{"@timestamp":1762279971.351882,"log":"Test log entry Tue 04 Nov 2025 06:12:51 PM UTC","source_type":"wordpress"}
...
```

## 3. Детальная информация о топиках

### Описание топика nginx

```bash
sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
  kafka-topics --bootstrap-server localhost:9092,localhost:9093 \
  --describe --topic nginx
```

**Ожидаемый вывод:**
```
Topic: nginx	TopicId: Xl4YTsFpTRimmM9Mxcnz7A	PartitionCount: 2	ReplicationFactor: 2	Configs: 
	Topic: nginx	Partition: 0	Leader: 1	Replicas: 1,2	Isr: 1,2
	Topic: nginx	Partition: 1	Leader: 2	Replicas: 2,1	Isr: 2,1
```

Это показывает:
- **PartitionCount: 2** — топик имеет 2 партиции
- **ReplicationFactor: 2** — каждая партиция имеет 2 реплики
- **Leader** — лидер каждой партиции
- **Replicas** — список реплик
- **Isr** — In-Sync Replicas (синхронизированные реплики)

### Описание топика wordpress

```bash
sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
  kafka-topics --bootstrap-server localhost:9092,localhost:9093 \
  --describe --topic wordpress
```

### Список всех топиков

```bash
sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
  kafka-topics --bootstrap-server localhost:9092,localhost:9093 --list
```

**Ожидаемый вывод:**
```
__consumer_offsets
nginx
wordpress
```

## 4. Генерация тестовых логов

Для проверки работы системы можно генерировать тестовые логи.

### Подключение к APP узлу

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@<APP_IP>
```

Замените `<APP_IP>` на IP-адрес вашего APP узла (можно получить командой `terraform output -raw app_external_ip`).

### Генерация nginx логов

Сделайте несколько HTTP-запросов к nginx:

```bash
# Генерация 5 запросов
for i in {1..5}; do curl -s http://localhost > /dev/null; sleep 1; done

# Или более интенсивная генерация
for i in {1..10}; do curl -s http://localhost > /dev/null; sleep 0.5; done
```

Каждый запрос создаст запись в `/var/log/nginx/access.log`, которую Fluent Bit отправит в топик `nginx` в Kafka.

### Генерация wordpress логов

Добавьте запись в файл лога WordPress:

```bash
echo "Test log entry $(date)" | sudo tee -a /var/log/wordpress/app.log
```

Или добавьте несколько записей:

```bash
for i in {1..3}; do 
  echo "Test log entry $i at $(date)" | sudo tee -a /var/log/wordpress/app.log
  sleep 1
done
```

### Комбинированная генерация

```bash
# Генерировать nginx и wordpress логи одновременно
for i in {1..5}; do 
  curl -s http://localhost > /dev/null
  echo "WordPress log entry $i at $(date)" | sudo tee -a /var/log/wordpress/app.log
  sleep 1
done
```

## 5. Мониторинг в реальном времени

Для мониторинга в реальном времени вам понадобятся два терминала.

### Терминал 1: Чтение из Kafka

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@<KAFKA_IP>

# Читать новые сообщения из топика nginx
sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
  kafka-console-consumer \
  --bootstrap-server localhost:9092,localhost:9093 \
  --topic nginx
```

Эта команда будет выводить все новые сообщения по мере их поступления в топик.

### Терминал 2: Генерация логов

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@<APP_IP>

# Генерировать логи каждые 2 секунды
while true; do 
  curl -s http://localhost > /dev/null
  sleep 2
done
```

В первом терминале вы должны увидеть новые сообщения, появляющиеся каждые 2 секунды.

### Мониторинг нескольких топиков

Для мониторинга обоих топиков одновременно используйте несколько терминалов или запустите команды в фоне:

```bash
# В фоне читать из nginx
sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
  kafka-console-consumer \
  --bootstrap-server localhost:9092,localhost:9093 \
  --topic nginx > /tmp/nginx.log 2>&1 &

# В фоне читать из wordpress
sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
  kafka-console-consumer \
  --bootstrap-server localhost:9092,localhost:9093 \
  --topic wordpress > /tmp/wordpress.log 2>&1 &

# Просмотр логов
tail -f /tmp/nginx.log
# или
tail -f /tmp/wordpress.log
```

## 6. Проверка работы Fluent Bit

Fluent Bit — это агент, который собирает логи и отправляет их в Kafka. Проверить его работу можно несколькими способами.

### Проверка статуса службы Fluent Bit

```bash
ssh -i ~/.ssh/id_ed25519 ubuntu@<APP_IP>
sudo systemctl status fluent-bit
```

**Ожидаемый вывод:**
```
● fluent-bit.service - Fluent Bit
     Loaded: loaded (/lib/systemd/system/fluent-bit.service; enabled; vendor preset: enabled)
     Active: active (running) since ...
```

### Просмотр логов Fluent Bit

```bash
# Последние 20 строк логов
sudo journalctl -u fluent-bit -n 20

# Логи в реальном времени
sudo journalctl -u fluent-bit -f

# Логи с фильтрацией по ошибкам
sudo journalctl -u fluent-bit | grep -i error
```

### Проверка конфигурации Fluent Bit

```bash
sudo cat /etc/fluent-bit/fluent-bit.conf
```

Убедитесь, что в конфигурации указаны правильные:
- Пути к лог-файлам (INPUT)
- Адреса брокеров Kafka (OUTPUT)
- Названия топиков (OUTPUT)

### Проверка подключения к Kafka

Fluent Bit должен подключаться к Kafka. Если есть проблемы, проверьте логи:

```bash
sudo journalctl -u fluent-bit | grep -i kafka
```

Ожидаемые сообщения:
```
[ info] [output:kafka:kafka.0] brokers='158.160.40.230:9092,158.160.40.230:9093' topics='nginx'
[ info] [output:kafka:kafka.1] brokers='158.160.40.230:9092,158.160.40.230:9093' topics='wordpress'
```

## Типичные проблемы и решения

### Проблема: Смещения не увеличиваются

**Возможные причины:**
1. Fluent Bit не работает
2. Fluent Bit не может подключиться к Kafka
3. Логи не генерируются

**Решение:**
1. Проверьте статус Fluent Bit: `sudo systemctl status fluent-bit`
2. Проверьте логи Fluent Bit: `sudo journalctl -u fluent-bit -n 50`
3. Проверьте доступность Kafka: `telnet <KAFKA_IP> 9092`
4. Проверьте, что логи генерируются: `tail -f /var/log/nginx/access.log`

### Проблема: Не удается прочитать сообщения из топика

**Возможные причины:**
1. Топик пуст
2. Неправильное имя топика
3. Проблемы с подключением к Kafka

**Решение:**
1. Проверьте список топиков: `kafka-topics --list`
2. Проверьте смещения: `GetOffsetShell --topic <topic_name>`
3. Убедитесь, что брокеры Kafka работают: `docker ps | grep kafka`

### Проблема: Сообщения не в формате JSON

**Возможные причины:**
1. Неправильная конфигурация Fluent Bit
2. Проблемы с парсингом логов

**Решение:**
1. Проверьте конфигурацию Fluent Bit: `sudo cat /etc/fluent-bit/fluent-bit.conf`
2. Убедитесь, что в OUTPUT используется `Format json`
3. Проверьте логи Fluent Bit на наличие ошибок парсинга

## Быстрые команды для проверки

### Одной командой с локального компьютера

```bash
# Получить IP-адреса
KAFKA_IP=$(cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_16/terraform && terraform output -raw kafka_external_ip)
APP_IP=$(cd /home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_16/terraform && terraform output -raw app_external_ip)

# Проверить смещения в nginx
ssh -i ~/.ssh/id_ed25519 ubuntu@$KAFKA_IP \
  'sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
   kafka-run-class kafka.tools.GetOffsetShell \
   --broker-list localhost:9092,localhost:9093 --topic nginx --time -1'

# Прочитать последние 3 сообщения
ssh -i ~/.ssh/id_ed25519 ubuntu@$KAFKA_IP \
  'sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 \
   kafka-console-consumer --bootstrap-server localhost:9092,localhost:9093 \
   --topic nginx --from-beginning --max-messages 3'

# Генерировать тестовые логи
ssh -i ~/.ssh/id_ed25519 ubuntu@$APP_IP \
  'for i in {1..5}; do curl -s http://localhost > /dev/null; sleep 1; done && \
   echo "Test log $(date)" | sudo tee -a /var/log/wordpress/app.log'
```

## Дополнительные ресурсы

- [Документация Kafka Console Consumer](https://kafka.apache.org/documentation/#basic_ops_consumer)
- [Документация Kafka Tools](https://kafka.apache.org/documentation/#tools)
- [Документация Fluent Bit](https://docs.fluentbit.io/)

