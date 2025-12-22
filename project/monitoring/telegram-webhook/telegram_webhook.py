#!/usr/bin/env python3
"""
Telegram webhook для Alertmanager
"""
import os
import json
import requests
from flask import Flask, request, jsonify

app = Flask(__name__)

# Конфигурация из переменных окружения
TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN', 'YOUR_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID', 'YOUR_CHAT_ID')
TELEGRAM_API_URL = f'https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}'

def format_alert(alert):
    """Форматирование алерта для Telegram"""
    status_emoji = "🚨" if alert.get('status') == 'firing' else "✅"
    status_text = "ALERT FIRING" if alert.get('status') == 'firing' else "ALERT RESOLVED"
    
    labels = alert.get('labels', {})
    annotations = alert.get('annotations', {})
    
    message = f"{status_emoji} <b>{status_text}</b>\n\n"
    message += f"<b>Alert:</b> {labels.get('alertname', 'N/A')}\n"
    message += f"<b>Severity:</b> {labels.get('severity', 'N/A')}\n"
    
    if 'instance' in labels:
        message += f"<b>Instance:</b> {labels['instance']}\n"
    if 'node' in labels:
        message += f"<b>Node:</b> {labels['node']}\n"
    if 'job' in labels:
        message += f"<b>Job:</b> {labels['job']}\n"
    
    if 'summary' in annotations:
        message += f"\n<b>Summary:</b> {annotations['summary']}\n"
    if 'description' in annotations:
        message += f"<b>Description:</b> {annotations['description']}\n"
    
    if 'startsAt' in alert:
        message += f"\n<b>Started:</b> {alert['startsAt']}\n"
    if 'endsAt' in alert:
        message += f"<b>Ended:</b> {alert['endsAt']}\n"
    
    message += "\n─────────────────────"
    return message

def send_telegram_message(text):
    """Отправка сообщения в Telegram"""
    url = f'{TELEGRAM_API_URL}/sendMessage'
    data = {
        'chat_id': TELEGRAM_CHAT_ID,
        'text': text,
        'parse_mode': 'HTML',
        'disable_notification': False
    }
    
    try:
        response = requests.post(url, json=data, timeout=10)
        response.raise_for_status()
        return True
    except Exception as e:
        print(f"Error sending message: {e}")
        return False

@app.route('/telegram', methods=['POST'])
def telegram_webhook():
    """Webhook endpoint для Alertmanager"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'error': 'No data received'}), 400
        
        # Обрабатываем алерты
        alerts = data.get('alerts', [])
        if not alerts:
            return jsonify({'error': 'No alerts in data'}), 400
        
        # Форматируем и отправляем каждый алерт
        for alert in alerts:
            message = format_alert(alert)
            send_telegram_message(message)
        
        return jsonify({'status': 'ok'}), 200
        
    except Exception as e:
        print(f"Error processing webhook: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok'}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
