#!/bin/bash
#######################################################################
# ВЕРСИЯ: 1.0.1. Дата 15.12.2025 18:00
# Скрипт развертывания ATM Terminal
# Запуск Portainer и развертывание документации
#
# История версий:
# - 1.0.1 (15.12.2025): перенос каталога Deploy и временных путей с /tmp на /opt, добавлен вывод версии (-V|--version)
# - 1.0.0: начальная версия скрипта развертывания
#
# Требования: 
# - Docker должен быть установлен и настроен
# - Пользователь должен быть в группе docker
# - Файл DOCKER_REGISTRY.crt должен быть в директории скрипта
# - Файл images.yml должен быть в директории скрипта
#
# Переменные окружения:
# - DOCKER_REGISTRY - адрес Docker реестра (по умолчанию: nexus.netlab.local)
#   Пример: DOCKER_REGISTRY=my-registry.local ./deploy.sh
#   Показать версию: ./deploy.sh -V|--version

# Примеры использования:
#   ./deploy.sh
#       - стандартный запуск, используется DOCKER_REGISTRY по умолчанию
#   DOCKER_REGISTRY=repo.example.com ./deploy.sh
#       - развертывание с альтернативным Docker-реестром
#   ./deploy.sh -V
#       - вывод версии скрипта и даты сборки
#
# Основные этапы:
# 1. Проверка наличия необходимых файлов
# 2. Запуск Portainer в docker
# 3. Загрузка docker образа с Ansible файлами и документацией.
# 4. Копирование файлов Ansible файлов в каталог /opt/Deploy на локальную машину
# 5. Запуск сайта с документацией через ansoble playbook

set -euo pipefail

SCRIPT_VERSION="1.0.1"
SCRIPT_VERSION_DATE="15.12.2025 18:00"

if [[ "${1:-}" == "-V" || "${1:-}" == "--version" ]]; then
    echo "deploy.sh версия ${SCRIPT_VERSION} от ${SCRIPT_VERSION_DATE}"
    exit 0
fi

# Определяем путь к директории скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Настройки Docker реестра
DOCKER_REGISTRY="${DOCKER_REGISTRY:-nexus.netlab.local}"

# Функция для вывода сообщения об ошибке и выхода
function error_exit {
    echo "ERROR: $1"
    exit 1
}

# Обеспечиваем, что /usr/local/bin в PATH для всех пользователей
export PATH="$PATH:/usr/local/bin"

# Для root также обновляем PATH
if [ "$EUID" -eq 0 ]; then
    export PATH="$PATH:/usr/local/bin"
    echo "PATH обновлен для root: $PATH"
fi

echo "=== Проверка готовности к развертыванию ==="
echo "Используемый Docker реестр: $DOCKER_REGISTRY"

# Проверяем, что Docker установлен и запущен
if ! command -v docker &>/dev/null; then
    error_exit "Docker не установлен. Сначала запустите lab_environment_setup.sh"
fi

# Проверяем, что Docker запущен
if ! docker info &>/dev/null; then
    error_exit "Docker не запущен. Запустите: sudo systemctl start docker"
fi

# Проверяем, что пользователь в группе docker
if ! groups | grep -q docker; then
    error_exit "Пользователь не в группе docker. Завершите сессию и откройте новую, затем запустите этот скрипт снова"
fi

# Проверяем доступность ansible-playbook
if ! command -v ansible-playbook &>/dev/null; then
    echo "ansible-playbook не найден в PATH, проверяем /usr/local/bin..."
    if [ -f "/usr/local/bin/ansible-playbook" ]; then
        echo "ansible-playbook найден в /usr/local/bin, добавляем в PATH"
        export PATH="/usr/local/bin:$PATH"
    else
        error_exit "ansible-playbook не найден. Убедитесь, что Ansible установлен правильно"
    fi
fi

# Проверяем наличие необходимых файлов
if [ ! -f "$SCRIPT_DIR/nexus.netlab.local.crt" ]; then
    error_exit "Файл сертификата $SCRIPT_DIR/nexus.netlab.local.crt не найден"
fi

if [ ! -f "$SCRIPT_DIR/images.yml" ]; then
    error_exit "Файл $SCRIPT_DIR/images.yml не найден"
fi

echo "✓ Все проверки пройдены успешно"

echo ""
echo "===  Вход в приватный реестр $DOCKER_REGISTRY ==="
# Проверяем, залогинены ли мы уже в реестр

if docker info 2>/dev/null | grep -q "$DOCKER_REGISTRY" || docker system info 2>/dev/null | grep -q "$DOCKER_REGISTRY"; then
    echo "✓ Уже залогинены в реестр $DOCKER_REGISTRY"
else
    echo "Выполняем вход в реестр..."
    docker login "$DOCKER_REGISTRY" || {
        echo "ERROR: Ошибка входа в Docker реестр $DOCKER_REGISTRY"
        exit 1
    }
fi
echo "===  Вход выполнен успешно ==="

echo ""
echo "=== Запуск Portainer ==="

docker volume create portainer_data || error_exit "Не удалось создать docker volume portainer_data"

if  docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
    echo "Контейнер Portainer уже существует, перезапускаем..."
    docker rm -f portainer || error_exit "Не удалось удалить старый контейнер Portainer"
fi

docker run -d \
  -p 8000:8000 -p 9000:9000 -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest || error_exit "Не удалось запустить контейнер Portainer"

echo "✓ Portainer запущен успешно"

echo ""
echo "=== Загрузка образа с документацией и копирование файлов Ansible ==="
# Загружаем образ с документацией и копируем файлы Ansible (полное обновление каталога Deploy)
echo "Загружаем образ с документацией и копируем файлы Ansible..."
DOCS_IMAGE_VERSION=$(grep "docs_image:" "$SCRIPT_DIR/images.yml" | cut -d'"' -f2)
echo "Версия образа документации: $DOCS_IMAGE_VERSION"

if [ -d "$SCRIPT_DIR/Deploy" ]; then
    echo "Найден существующий каталог $SCRIPT_DIR/Deploy — удаляем перед копированием..."
    if rm -rf "$SCRIPT_DIR/Deploy" 2>/dev/null; then
        echo "✓ Старый каталог Deploy удален"
    else
        echo "Требуются повышенные привилегии для удаления старого каталога Deploy, пробуем через sudo..."
        if sudo rm -rf "$SCRIPT_DIR/Deploy"; then
            echo "✓ Старый каталог Deploy удален (через sudo)"
        else
            error_exit "Не удалось удалить существующий каталог Deploy"
        fi
    fi
fi

if ! docker run --rm -v "$SCRIPT_DIR":/opt "$DOCKER_REGISTRY/$DOCS_IMAGE_VERSION" sh -c 'mkdir -p /opt/Deploy && cp -r /DevOps/ansible/. /opt/Deploy/'; then
    echo "ERROR: Не удалось загрузить образ с документацией и скопировать файлы Ansible"
    exit 1
fi

echo "✓ Образ с документацией загружен и файлы Ansible скопированы"

# Смена владельца каталога Deploy на пользователя, запустившего скрипт
if [ -d "$SCRIPT_DIR/Deploy" ]; then
    OWNER_USER="${SUDO_USER:-$USER}"
    OWNER_GROUP="$(id -gn "$OWNER_USER")"
    if chown -R "$OWNER_USER":"$OWNER_GROUP" "$SCRIPT_DIR/Deploy" 2>/dev/null; then
        echo "✓ Владелец каталога Deploy изменен на $OWNER_USER:$OWNER_GROUP"
    else
        echo "Требуются повышенные привилегии для смены владельца каталога Deploy, пробуем через sudo..."
        if sudo chown -R "$OWNER_USER":"$OWNER_GROUP" "$SCRIPT_DIR/Deploy"; then
            echo "✓ Владелец каталога Deploy изменен на $OWNER_USER:$OWNER_GROUP (через sudo)"
        else
            echo "Предупреждение: не удалось изменить владельца каталога Deploy. Продолжаем с текущими правами."
        fi
    fi
fi
echo ""
echo "Развертывание сайта с документацией..."
# Запуск плейбука с документацией
if [ -f "$SCRIPT_DIR/Deploy/docs.yml" ] && [ -f "$SCRIPT_DIR/Deploy/inventories/ATM_demo/hosts.ini" ] && [ -f "$SCRIPT_DIR/images.yml" ]; then
    echo "✓ Найдены необходимые файлы для развертывания документации"
    echo ""
    echo "Переходим в директорию /opt для запуска Ansible..."
    echo ""
    cd /opt
    echo "Запуск: ansible-playbook -i $SCRIPT_DIR/Deploy/inventories/ATM_demo/hosts.ini $SCRIPT_DIR/Deploy/docs.yml -e @$SCRIPT_DIR/images.yml"
    
    if ansible-playbook -i "$SCRIPT_DIR/Deploy/inventories/ATM_demo/hosts.ini" "$SCRIPT_DIR/Deploy/docs.yml" --extra-vars 'docker_image_registry=$DOCKER_REGISTRY' -e "@$SCRIPT_DIR/images.yml"; then
        echo "✓ Документация успешно развернута"
    else
        error_exit "Ошибка при развертывании документации. Проверьте логи и конфигурацию Ansible"
    fi
else
    echo "✗ Не найдены необходимые файлы для развертывания документации:"
    [ ! -f "$SCRIPT_DIR/Deploy/docs.yml" ] && echo "  - $SCRIPT_DIR/Deploy/docs.yml"
        [ ! -f "$SCRIPT_DIR/Deploy/inventories/ATM_demo/hosts.ini" ] && echo "  - $SCRIPT_DIR/Deploy/inventories/ATM_demo/hosts.ini"
    [ ! -f "$SCRIPT_DIR/images.yml" ] && echo "  - $SCRIPT_DIR/images.yml"
    error_exit "Не найдены необходимые файлы для развертывания документации. Убедитесь, что образ с деплоем был правильно скопирован"
fi

echo ""
echo "=== Развертывание завершено успешно! ==="
echo ""
echo "Доступные сервисы:"
echo ""
echo "📚 Документация:"
echo "   http://$(hostname -I | awk '{print $1}'):37527/docs/"
echo "   - Полная документация по ATM Terminal"
echo "   - Руководства по установке и настройке"
echo "   - API документация"
echo ""
echo "🐳 Portainer (Управление Docker):"
echo "   http://$(hostname -I | awk '{print $1}'):9000"
echo "   - Веб-интерфейс для управления Docker контейнерами"
echo "   - Управление Docker Swarm"
echo "   - Мониторинг ресурсов"
echo ""
echo "🔐 Первый запуск Portainer:"
echo "   1. Откройте ссылку Portainer в браузере"
echo "   2. Создайте учетную запись администратора"
echo "   3. Выберите 'Local' для подключения к локальному Docker"
echo "   4. Начните управление контейнерами через веб-интерфейс"
echo ""
echo "📋 Следующие шаги:"
echo "   1. Изучите документацию по адресу http://$(hostname -I | awk '{print $1}'):37527/docs/. Вкладка 'Развертывание на стенде'"
echo "   2. Настройте Portainer для управления Docker"
echo "   3. Следуйте инструкциям в документации для дальнейшего развертывания"
echo ""
