FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir flask requests

COPY telegram_webhook.py .

EXPOSE 8080

CMD ["python", "telegram_webhook.py"]
