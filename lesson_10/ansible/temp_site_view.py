@api_view(['GET'])
def site_view(request):
    """Simple website view."""
    current_time = timezone.now().strftime('%d.%m.%Y %H:%M:%S')
    html_content = '''<!DOCTYPE html>
<html>
<head>
    <title>Django Site</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; }
        .status { background: #28a745; color: white; padding: 10px; text-align: center; border-radius: 5px; margin: 20px 0; }
        .info { background: #f8f9fa; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .info-item { margin: 10px 0; }
        .label { font-weight: bold; color: #555; }
        .value { color: #007bff; }
        .links { text-align: center; margin: 30px 0; }
        .links a { display: inline-block; margin: 10px; padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; }
        .links a:hover { background: #0056b3; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Django Site</h1>
        <div class="status">✅ Online</div>
        
        <div class="info">
            <div class="info-item">
                <span class="label">Сервер:</span>
                <span class="value">''' + os.uname().nodename + '''</span>
            </div>
            <div class="info-item">
                <span class="label">База данных:</span>
                <span class="value">PostgreSQL</span>
            </div>
            <div class="info-item">
                <span class="label">WSGI сервер:</span>
                <span class="value">UWSGI</span>
            </div>
            <div class="info-item">
                <span class="label">Время:</span>
                <span class="value">''' + current_time + '''</span>
            </div>
        </div>
        
        <div class="links">
            <a href="/api/">API</a>
            <a href="/api/health/">Health Check</a>
            <a href="/api/items/">Items</a>
            <a href="/admin/">Admin</a>
        </div>
        
        <p style="text-align: center; color: #666; margin-top: 30px;">
            Django REST API v1.0.0 | Powered by UWSGI + PostgreSQL
        </p>
    </div>
</body>
</html>'''
    return HttpResponse(html_content)
