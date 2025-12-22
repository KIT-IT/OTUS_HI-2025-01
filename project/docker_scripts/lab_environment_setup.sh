#!/bin/bash
#######################################################################
# ВЕРСИЯ: 1.0.2. Дата 17.12.2025 19:00 
# Скрипт автоматической настройки окружения для ATM Terminal
# Поддерживает: Astra Linux, Debian, Ubuntu, RHEL, CentOS, Alma Linux, Rocky Linux, RedOS, Fedora
# Менеджеры пакетов: apt (Debian-based), dnf (RHEL 8+), yum (RHEL 7 и старые версии)
#
# История версий:
# - 1.0.2 (17.12.2025): добавлена опциональная настройка TCP доступа к docker.sock через переменную ENABLE_DOCKER_TCP (по умолчанию: false)
# - 1.0.1 (15.12.2025): перенос лога инициализации Docker Swarm из /tmp в /opt, добавлен вывод версии (-V|--version)
# - 1.0.0: базовая версия скрипта (установка окружения и Docker/Swarm)
#
# Требования: sudo права, интернет
# Опционально: сертификат nexus.netlab.local.crt (если включена регистрация сертификатов)
#
# Исправления:
# - Разрешение конфликтов пакетов Docker для RHEL-based систем
# - Улучшенное определение ОС и версий
# - Поддержка старых систем с yum
# - Поэтапная установка компонентов Docker для избежания конфликтов
# - Исправление ошибки 404 для репозиториев Docker (использование CentOS репозиториев для RHEL)
# - Альтернативные методы установки Docker при недоступности репозиториев
# - Поддержка установки Docker из стандартных репозиториев системы
# - Исправление несовместимости --live-restore с Docker Swarm
# - Автоматическое исправление конфигурации Docker для работы со Swarm
#
# Основные этапы:
# 1. Определение ОС и пакетного менеджера
# 2. Установка Python3, pip и необходимых пакетов (ansible, docker, etc.)
# 3. Установка и настройка Docker (включая Swarm)
# 4. Настройка сертификатов для Docker реестра (опционально)
# 5. Проверка установки всех компонентов
#
# Переменные окружения:
# - ENABLE_CERT_REGISTRATION - включить регистрацию сертификатов (по умолчанию: false). При true, имя сертификата должно быть в формате: DOCKER_REGISTRY.crt.
# - DOCKER_REGISTRY - адрес Docker реестра (по умолчанию: nexus.netlab.local)
# - ENABLE_DOCKER_TCP - включить TCP доступ к docker.sock на порту 2375 (по умолчанию: false)
#   Пример: sudo ENABLE_CERT_REGISTRATION=true DOCKER_REGISTRY=my-registry.local ENABLE_DOCKER_TCP=false ./lab_environment_setup.sh

# Примеры использования:
#   sudo ./lab_environment_setup.sh
#       - базовая установка окружения (Docker, Ansible и зависимости)
#   sudo ENABLE_CERT_REGISTRATION=true DOCKER_REGISTRY=nexus.netlab.local ./lab_environment_setup.sh
#       - установка с регистрацией сертификата для альтернативного реестра
#   sudo ENABLE_DOCKER_TCP=true ./lab_environment_setup.sh
#       - установка с включением TCP доступа к docker.sock на порту 2375
#   ./lab_environment_setup.sh -V
#       - вывод версии скрипта и даты сборки
#
set -euo pipefail

SCRIPT_VERSION="1.0.2"
SCRIPT_VERSION_DATE="15.12.2025 19:00"

if [[ "${1:-}" == "-V" || "${1:-}" == "--version" ]]; then
    echo "lab_environment_setup.sh версия ${SCRIPT_VERSION} от ${SCRIPT_VERSION_DATE}"
    exit 0
fi

# Определяем путь к директории скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Настройки сертификатов
ENABLE_CERT_REGISTRATION="${ENABLE_CERT_REGISTRATION:-false}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-nexus.netlab.local}"

# Настройка TCP доступа к docker.sock
ENABLE_DOCKER_TCP="${ENABLE_DOCKER_TCP:-false}"

# Флаг для отслеживания установки Docker из стандартных репозиториев
DOCKER_INSTALLED_FROM_REPO=false

# Функция для вывода сообщения об ошибке и выхода
function error_exit {
    echo "ERROR: $1"
    exit 1
}

# Функция для разрешения конфликтов пакетов
function resolve_package_conflicts {
    local pkg_manager=$1
    local packages=$2
    
    echo "Проверяем и разрешаем конфликты пакетов..."
    
    if [ "$pkg_manager" = "dnf" ] || [ "$pkg_manager" = "yum" ]; then
        # Для RHEL-based систем проверяем конфликты
        echo "Проверяем конфликты для RHEL-based системы..."
        
        # Удаляем конфликтующие пакеты если они установлены
        for pkg in docker-ce-cli docker-buildx-plugin; do
            if rpm -q "$pkg" &>/dev/null; then
                echo "Удаляем конфликтующий пакет: $pkg"
                if [ "$pkg_manager" = "yum" ]; then
                    sudo yum remove -y "$pkg" || echo "Предупреждение: не удалось удалить $pkg"
                else
                    sudo dnf remove -y "$pkg" || echo "Предупреждение: не удалось удалить $pkg"
                fi
            fi
        done
        
        # Очищаем кэш пакетов
        if [ "$pkg_manager" = "yum" ]; then
            sudo yum clean all || echo "Предупреждение: не удалось очистить кэш yum"
        else
            sudo dnf clean all || echo "Предупреждение: не удалось очистить кэш dnf"
        fi
        
    elif [ "$pkg_manager" = "apt" ]; then
        # Для Debian-based систем
        echo "Проверяем конфликты для Debian-based системы..."
        
        # Удаляем конфликтующие пакеты если они установлены
        for pkg in docker-ce-cli docker-buildx-plugin; do
            if dpkg -l | grep -q "^ii.*$pkg "; then
                echo "Удаляем конфликтующий пакет: $pkg"
                sudo apt remove -y "$pkg" || echo "Предупреждение: не удалось удалить $pkg"
            fi
        done
        
        # Очищаем кэш пакетов
        sudo apt clean || echo "Предупреждение: не удалось очистить кэш apt"
    fi
}

# Определение дистрибутива
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
    # Дополнительная информация для лучшего определения
    OS_LIKE=${ID_LIKE:-}
    OS_VERSION_CODENAME=${VERSION_CODENAME:-}
else
    error_exit "Не удалось определить операционную систему"
fi

echo "Обнаружена операционная система: $OS $VERSION"
if [ -n "$OS_LIKE" ]; then
    echo "Основана на: $OS_LIKE"
fi

# Проверка поддержки дистрибутива
case $OS in
    "astra")
        echo "Поддерживаемая ОС: Astra Linux"
        PKG_MANAGER="apt"
        ;;
    "debian"|"ubuntu")
        echo "Поддерживаемая ОС: $OS"
        PKG_MANAGER="apt"
        ;;
    "rhel"|"centos"|"almalinux"|"rocky"|"redos")
        echo "Поддерживаемая ОС: $OS"
        PKG_MANAGER="dnf"
        ;;
    "fedora")
        echo "Поддерживаемая ОС: $OS"
        PKG_MANAGER="dnf"
        ;;
    *)
        # Проверяем по ID_LIKE для лучшего определения
        case $OS_LIKE in
            "debian"|"ubuntu")
                echo "Поддерживаемая ОС: $OS (основана на $OS_LIKE)"
                PKG_MANAGER="apt"
                ;;
            "rhel"|"fedora")
                echo "Поддерживаемая ОС: $OS (основана на $OS_LIKE)"
                PKG_MANAGER="dnf"
                ;;
            *)
                echo "Предупреждение: Неизвестная ОС $OS. Пытаемся определить по менеджеру пакетов..."
                if command -v apt &>/dev/null; then
                    PKG_MANAGER="apt"
                    echo "Используем apt"
                elif command -v dnf &>/dev/null; then
                    PKG_MANAGER="dnf"
                    echo "Используем dnf"
                elif command -v yum &>/dev/null; then
                    PKG_MANAGER="yum"
                    echo "Используем yum"
                else
                    error_exit "Не удалось определить менеджер пакетов"
                fi
                ;;
        esac
        ;;
esac

echo "Настройка PATH для Ansible (пользователь и sudo)"

# 1) Текущая сессия пользователя: добавляем /usr/local/bin и ~/.local/bin
if ! echo "$PATH" | grep -q "/usr/local/bin"; then
    export PATH="$PATH:/usr/local/bin"
fi
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    export PATH="$PATH:$HOME/.local/bin"
fi

# 2) Персистентно для пользователя
if ! grep -q "/usr/local/bin" "$HOME/.bashrc" 2>/dev/null; then
    echo -e "\n# Добавляем /usr/local/bin в PATH\nexport PATH=\$PATH:/usr/local/bin" >> "$HOME/.bashrc" || echo "Предупреждение: не удалось изменить $HOME/.bashrc"
fi
if ! grep -q "\$HOME/.local/bin" "$HOME/.bashrc" 2>/dev/null; then
    echo -e "\n# Добавляем ~/.local/bin в PATH\nexport PATH=\$PATH:\$HOME/.local/bin" >> "$HOME/.bashrc" || echo "Предупреждение: не удалось изменить $HOME/.bashrc"
fi

# 3) Для sudo: гарантируем, что /usr/local/bin находится в secure_path
SUDOERS_OVERRIDE="/etc/sudoers.d/10-secure-path"
NEEDED_SECURE_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

NEED_WRITE_SECURE_PATH=1
if sudo test -f "$SUDOERS_OVERRIDE"; then
    if sudo grep -q "Defaults[[:space:]]\+secure_path=\".*\/usr\/local\/bin.*\"" "$SUDOERS_OVERRIDE" 2>/dev/null; then
        NEED_WRITE_SECURE_PATH=0
    fi
fi

if [ "$NEED_WRITE_SECURE_PATH" -eq 1 ]; then
    echo "Настраиваем sudo secure_path для доступа к /usr/local/bin"
    echo "Defaults secure_path=\"$NEEDED_SECURE_PATH\"" | sudo tee "$SUDOERS_OVERRIDE" >/dev/null || echo "Предупреждение: не удалось записать $SUDOERS_OVERRIDE"
    # Проверим синтаксис sudoers
    if ! sudo visudo -cf "$SUDOERS_OVERRIDE" >/dev/null 2>&1; then
        echo "Предупреждение: обнаружена ошибка в $SUDOERS_OVERRIDE, удаляем файл"
        sudo rm -f "$SUDOERS_OVERRIDE"
    fi
fi

echo "=== Начинаем установку Python и необходимых модулей ==="

# Очистка существующих репозиториев Docker для apt-based систем
if [ "$PKG_MANAGER" = "apt" ]; then
    echo "Проверяем и очищаем существующие репозитории Docker..."
    
    # Удаляем существующие репозитории Docker, если они есть
    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        echo "Удаляем существующий репозиторий Docker..."
        sudo rm -f /etc/apt/sources.list.d/docker.list
    fi
    
    if [ -f /etc/apt/keyrings/docker.gpg ]; then
        echo "Удаляем существующий GPG ключ Docker..."
        sudo rm -f /etc/apt/keyrings/docker.gpg
    fi
    
    # Обновление списка пакетов для apt-based систем
    echo "Обновляем список пакетов..."
    sudo apt update || error_exit "Не удалось обновить список пакетов"
fi

# Установка python3 и pip если не установлены
if ! command -v python3 &>/dev/null; then
    echo "Python3 не найден, устанавливаем..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt install -y python3 python3-pip python3-venv || error_exit "Не удалось установить python3"
    else
        sudo dnf install -y python3 || error_exit "Не удалось установить python3"
    fi
else
    echo "Python3 уже установлен: $(python3 --version)"
fi

if ! command -v pip3 &>/dev/null; then
    echo "pip3 не найден, устанавливаем..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt install -y python3-pip || error_exit "Не удалось установить python3-pip"
    else
        sudo dnf install -y python3-pip || error_exit "Не удалось установить python3-pip"
    fi
else
    echo "pip3 уже установлен: $(pip3 --version)"
fi

echo "Обновляем pip и устанавливаем необходимые Python пакеты"
sudo python3 -m pip install --upgrade pip setuptools wheel requests==2.31.0 jmespath "ansible-core<2.16" ansible docker jsondiff pyyaml passlib || error_exit "Ошибка установки Python пакетов"

# Гарантируем доступность Ansible для sudo (secure_path может не включать /usr/local/bin)
for bin in ansible ansible-playbook ansible-galaxy; do
    if [ -x "/usr/local/bin/$bin" ] && [ ! -e "/usr/bin/$bin" ]; then
        echo "Создаем системную ссылку для $bin в /usr/bin"
        sudo ln -s "/usr/local/bin/$bin" "/usr/bin/$bin" || echo "Предупреждение: не удалось создать ссылку для $bin"
    fi
done

echo "=== Установка Docker ==="

# Инициализируем флаг установки Docker (на случай, если он не был установлен ранее)
DOCKER_INSTALLED_FROM_REPO=${DOCKER_INSTALLED_FROM_REPO:-false}

if ! command -v docker &>/dev/null; then
    if [ "$PKG_MANAGER" = "apt" ]; then
        if [ "$OS" = "astra" ]; then
            echo "Установка Docker для Astra Linux..."
            
            # Сначала пробуем установить Docker из официальных репозиториев Astra Linux
            echo "Проверяем наличие Docker в официальных репозиториях Astra Linux..."
            if apt-cache search docker | grep -q docker; then
                echo "Docker найден в официальных репозиториях Astra Linux"
                # Пробуем установить docker.io (стандартный пакет в Debian-based системах)
                if apt-cache show docker.io >/dev/null 2>&1; then
                    echo "Устанавливаем docker.io из официальных репозиториев..."
                    sudo apt install -y docker.io || echo "Предупреждение: не удалось установить docker.io"
                fi
                
                # Пробуем установить docker-ce если доступен
                if apt-cache show docker-ce >/dev/null 2>&1; then
                    echo "Устанавливаем docker-ce из официальных репозиториев..."
                    sudo apt install -y docker-ce docker-ce-cli containerd.io || echo "Предупреждение: не удалось установить docker-ce"
                fi
                
                # Проверяем, установился ли Docker
                if command -v docker &>/dev/null; then
                    echo "Docker успешно установлен из официальных репозиториев"
                else
                    echo "Docker не установился из официальных репозиториев, пробуем альтернативный метод..."
                fi
            else
                echo "Docker не найден в официальных репозиториях Astra Linux"
            fi
            
            # Если Docker не установился, пробуем альтернативные методы
            if ! command -v docker &>/dev/null; then
                echo "Docker не установился из официальных репозиториев, пробуем альтернативные методы..."
                
                # Пробуем установить через snap, если доступен
                if command -v snap &>/dev/null; then
                    echo "Пробуем установить Docker через snap..."
                    sudo snap install docker || echo "Предупреждение: не удалось установить Docker через snap"
                    
                    if command -v docker &>/dev/null; then
                        echo "Docker успешно установлен через snap"
                    fi
                fi
                
                # Если все еще не установлен, пробуем статический бинарник
                if ! command -v docker &>/dev/null; then
                    echo "Пробуем установить Docker через статический бинарник..."
                
                # Устанавливаем необходимые пакеты
                sudo apt install -y ca-certificates curl gnupg lsb-release || error_exit "Не удалось установить необходимые пакеты"
                
                # Определяем кодовое имя для Astra Linux (используем bullseye как базовое)
                CODENAME="bullseye"
                if [ -f /etc/os-release ]; then
                    # Пытаемся определить кодовое имя из версии
                    case "$VERSION" in
                        "1.7"*)
                            CODENAME="bullseye"
                            ;;
                        "1.6"*)
                            CODENAME="buster"
                            ;;
                        *)
                            CODENAME="bullseye"
                            ;;
                    esac
                fi
                
                echo "Используем кодовое имя: $CODENAME"
                
                # Добавляем GPG ключ Docker
                sudo mkdir -p /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || error_exit "Не удалось добавить GPG ключ Docker"
                
                # Добавляем репозиторий Docker с правильным кодовым именем
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || error_exit "Не удалось добавить репозиторий Docker"
                
                echo "Обновляем список пакетов"
                if ! sudo apt update; then
                    echo "Ошибка обновления списка пакетов, пробуем альтернативный метод установки Docker..."
                    
                    # Удаляем проблемный репозиторий Docker
                    echo "Удаляем проблемный репозиторий Docker..."
                    sudo rm -f /etc/apt/sources.list.d/docker.list
                    sudo rm -f /etc/apt/keyrings/docker.gpg
                    
                    # Альтернативный метод: установка через статический бинарник
                    echo "Скачиваем и устанавливаем Docker статический бинарник..."
                    
                    # Создаем временную директорию
                    TEMP_DIR=$(mktemp -d)
                    cd "$TEMP_DIR"
                    
                    # Скачиваем Docker
                    DOCKER_VERSION="24.0.7"
                    curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz || error_exit "Не удалось скачать Docker"
                    
                    # Распаковываем
                    tar -xzf docker.tgz || error_exit "Не удалось распаковать Docker"
                    
                    # Копируем бинарники
                    sudo cp docker/* /usr/local/bin/ || error_exit "Не удалось скопировать Docker бинарники"
                    
                    # Устанавливаем containerd отдельно
                    echo "Устанавливаем containerd..."
                    sudo apt install -y containerd.io || echo "Предупреждение: containerd.io недоступен в репозиториях"
                    
                    # Очищаем временные файлы
                    cd /
                    rm -rf "$TEMP_DIR"
                    
                    echo "Docker установлен из статического бинарника"
                else
                    echo "Устанавливаем Docker CE"
                    sudo apt install -y docker-ce docker-ce-cli containerd.io || error_exit "Не удалось установить Docker"
                fi
                
                # Устанавливаем дополнительные компоненты, если доступны
                if apt-cache search docker-buildx-plugin | grep -q docker-buildx-plugin; then
                    sudo apt install -y docker-buildx-plugin || echo "Предупреждение: docker-buildx-plugin недоступен"
                fi
                
                if apt-cache search docker-compose-plugin | grep -q docker-compose-plugin; then
                    sudo apt install -y docker-compose-plugin || echo "Предупреждение: docker-compose-plugin недоступен"
                fi
                fi
            fi
        else
            echo "Устанавливаем необходимые пакеты для apt..."
            sudo apt install -y ca-certificates curl gnupg lsb-release || error_exit "Не удалось установить необходимые пакеты"

            echo "Добавляем GPG ключ Docker"
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || error_exit "Не удалось добавить GPG ключ Docker"

            echo "Добавляем репозиторий Docker"
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || error_exit "Не удалось добавить репозиторий Docker"

            echo "Обновляем список пакетов"
            sudo apt update || error_exit "Не удалось обновить список пакетов"

            echo "Устанавливаем Docker CE"
            sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || error_exit "Не удалось установить Docker"
        fi
    else
        # Определяем, какой менеджер пакетов использовать
        if [ "$PKG_MANAGER" = "yum" ]; then
            echo "Используем yum для установки Docker"
            
            # Инициализируем флаг установки Docker
            DOCKER_INSTALLED_FROM_REPO=false
            
            # Устанавливаем необходимые пакеты для yum
            sudo yum install -y yum-utils device-mapper-persistent-data lvm2 || error_exit "Не удалось установить необходимые пакеты для yum"
            
            # Определяем правильный репозиторий для yum (RHEL 7 и старые версии)
            YUM_DOCKER_REPO="https://download.docker.com/linux/rhel/docker-ce.repo"
            if [ "$OS" = "redos" ] || [ "$OS" = "rhel" ]; then
                case "$VERSION" in
                    "7"*)
                        # RHEL 7: используем репозиторий CentOS 7
                        YUM_DOCKER_REPO="https://download.docker.com/linux/centos/7/docker-ce.repo"
                        echo "Используем репозиторий CentOS 7 для совместимости с RHEL 7"
                        ;;
                    *)
                        # Для других версий используем общий репозиторий RHEL
                        YUM_DOCKER_REPO="https://download.docker.com/linux/rhel/docker-ce.repo"
                        ;;
                esac
            fi

            echo "Добавляем репозиторий Docker: $YUM_DOCKER_REPO"
            if ! sudo yum-config-manager --add-repo "$YUM_DOCKER_REPO"; then
                echo "Ошибка добавления репозитория $YUM_DOCKER_REPO, пробуем альтернативные методы..."
                
                # Пробуем общий репозиторий RHEL
                echo "Пробуем общий репозиторий RHEL..."
                if ! sudo yum-config-manager --add-repo "https://download.docker.com/linux/rhel/docker-ce.repo"; then
                    echo "Ошибка добавления репозитория RHEL, пробуем установку из стандартных репозиториев..."
                    
                    # Пробуем установить Docker из стандартных репозиториев
                    if ! sudo yum install -y docker; then
                        error_exit "Не удалось установить Docker ни из одного источника"
                    else
                        echo "Docker установлен из стандартных репозиториев"
                        DOCKER_INSTALLED_FROM_REPO=true
                    fi
                else
                    echo "Успешно добавлен общий репозиторий RHEL"
                fi
            else
                echo "Репозиторий Docker успешно добавлен"
            fi
            
            # Проверяем, не установлен ли уже Docker из стандартных репозиториев
            if [ "${DOCKER_INSTALLED_FROM_REPO:-false}" = "false" ]; then
                # Разрешаем конфликты пакетов перед установкой
                resolve_package_conflicts "$PKG_MANAGER" "docker-ce docker-ce-cli containerd.io"
                
                echo "Обновляем список пакетов после разрешения конфликтов"
                sudo yum makecache || echo "Предупреждение: не удалось обновить кэш пакетов"
                
                echo "Устанавливаем Docker CE (основные компоненты)"
                if ! sudo yum install -y docker-ce containerd.io; then
                    echo "Ошибка установки основных компонентов Docker, пробуем альтернативный подход..."
                    sudo yum install -y docker || error_exit "Не удалось установить Docker"
                fi
                
                # Пробуем установить дополнительные компоненты
                sudo yum install -y docker-ce-cli || echo "Предупреждение: не удалось установить docker-ce-cli"
                sudo yum install -y docker-buildx-plugin || echo "Предупреждение: не удалось установить docker-buildx-plugin"
                sudo yum install -y docker-compose-plugin || echo "Предупреждение: не удалось установить docker-compose-plugin"
            else
                echo "Docker уже установлен из стандартных репозиториев, пропускаем установку CE"
            fi
            
        else
            echo "Используем dnf для установки Docker"
            
            # Инициализируем флаг установки Docker
            DOCKER_INSTALLED_FROM_REPO=false
            
            echo "Устанавливаем dnf-plugins-core"
            sudo dnf -y install dnf-plugins-core || error_exit "Не удалось установить dnf-plugins-core"

            # Определяем правильный репозиторий Docker в зависимости от версии RHEL
            DOCKER_REPO="https://download.docker.com/linux/rhel/docker-ce.repo"
            if [ "$OS" = "redos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "almalinux" ] || [ "$OS" = "rocky" ]; then
                # Для RHEL-based систем используем совместимые репозитории
                case "$VERSION" in
                    "8"*)
                        # RHEL 8: используем репозиторий CentOS 8 (совместим с RHEL 8)
                        DOCKER_REPO="https://download.docker.com/linux/centos/8/docker-ce.repo"
                        echo "Используем репозиторий CentOS 8 для совместимости с RHEL 8"
                        ;;
                    "9"*)
                        # RHEL 9: используем репозиторий CentOS 9
                        DOCKER_REPO="https://download.docker.com/linux/centos/9/docker-ce.repo"
                        echo "Используем репозиторий CentOS 9 для совместимости с RHEL 9"
                        ;;
                    *)
                        # Для других версий используем общий репозиторий RHEL
                        DOCKER_REPO="https://download.docker.com/linux/rhel/docker-ce.repo"
                        ;;
                esac
            fi

            echo "Добавляем репозиторий Docker: $DOCKER_REPO"
            if ! sudo dnf config-manager --add-repo "$DOCKER_REPO"; then
                echo "Ошибка добавления репозитория $DOCKER_REPO, пробуем альтернативные методы..."
                
                # Пробуем общий репозиторий RHEL
                echo "Пробуем общий репозиторий RHEL..."
                if ! sudo dnf config-manager --add-repo "https://download.docker.com/linux/rhel/docker-ce.repo"; then
                    echo "Ошибка добавления репозитория RHEL, пробуем установку из стандартных репозиториев..."
                    
                    # Пробуем установить Docker из стандартных репозиториев
                    if ! sudo dnf install -y docker; then
                        error_exit "Не удалось установить Docker ни из одного источника"
                    else
                        echo "Docker установлен из стандартных репозиториев"
                        DOCKER_INSTALLED_FROM_REPO=true
                    fi
                else
                    echo "Успешно добавлен общий репозиторий RHEL"
                fi
            else
                echo "Репозиторий Docker успешно добавлен"
            fi

            # Проверяем, не установлен ли уже Docker из стандартных репозиториев
            if [ "${DOCKER_INSTALLED_FROM_REPO:-false}" = "false" ]; then
                # Разрешаем конфликты пакетов перед установкой
                resolve_package_conflicts "$PKG_MANAGER" "docker-ce docker-ce-cli containerd.io"

                echo "Обновляем список пакетов после разрешения конфликтов"
                sudo dnf makecache || echo "Предупреждение: не удалось обновить кэш пакетов"

                echo "Устанавливаем Docker CE (основные компоненты)"
                if ! sudo dnf install -y docker-ce containerd.io; then
                    echo "Ошибка установки основных компонентов Docker, пробуем альтернативный подход..."
                    
                    # Пробуем установить только docker-ce без CLI
                    if ! sudo dnf install -y docker-ce; then
                        echo "Пробуем установить docker-ce из репозитория по умолчанию..."
                        sudo dnf install -y docker || error_exit "Не удалось установить Docker"
                    fi
                fi
            else
                echo "Docker уже установлен из стандартных репозиториев, пропускаем установку CE"
            fi

            # Устанавливаем дополнительные компоненты по отдельности (только если Docker CE установлен)
            if [ "${DOCKER_INSTALLED_FROM_REPO:-false}" = "false" ]; then
                echo "Устанавливаем дополнительные компоненты Docker..."
                
                # Пробуем установить docker-ce-cli отдельно
                if ! sudo dnf install -y docker-ce-cli; then
                    echo "Предупреждение: не удалось установить docker-ce-cli, пробуем альтернативы..."
                    # Пробуем установить docker-cli из репозитория по умолчанию
                    sudo dnf install -y docker-cli || echo "Предупреждение: docker-cli недоступен"
                fi

                # Пробуем установить docker-buildx-plugin отдельно
                if ! sudo dnf install -y docker-buildx-plugin; then
                    echo "Предупреждение: не удалось установить docker-buildx-plugin"
                fi

                # Пробуем установить docker-compose-plugin отдельно
                if ! sudo dnf install -y docker-compose-plugin; then
                    echo "Предупреждение: не удалось установить docker-compose-plugin"
                fi
            else
                echo "Docker установлен из стандартных репозиториев, дополнительные компоненты могут быть недоступны"
            fi

            # Проверяем, что Docker установился
            if ! command -v docker &>/dev/null; then
                error_exit "Docker не установился после всех попыток"
            fi
        fi
    fi
else
    echo "Docker уже установлен: $(docker --version)"
fi

echo "Добавляем пользователя ${SUDO_USER:-$USER} в группу docker"
sudo usermod -aG docker "${SUDO_USER:-$USER}" || error_exit "Не удалось добавить пользователя в группу docker"
sudo usermod -aG docker root || error_exit "Не удалось добавить пользователя root в группу docker"

echo "Включаем и запускаем сервис docker"
sudo systemctl enable --now docker || error_exit "Не удалось запустить docker сервис"

echo "Инициализация Docker Swarm"

# Проверяем и исправляем конфигурацию Docker для совместимости со Swarm
echo "Проверяем конфигурацию Docker для совместимости со Swarm..."

# Проверяем, есть ли --live-restore в конфигурации Docker
if [ -f /etc/docker/daemon.json ]; then
    if grep -q "live-restore" /etc/docker/daemon.json; then
        echo "Обнаружена опция --live-restore в конфигурации Docker, которая несовместима со Swarm"
        echo "Создаем резервную копию конфигурации и отключаем --live-restore..."
        
        # Создаем резервную копию
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
        
        # Удаляем live-restore из конфигурации
        if command -v python3 &>/dev/null; then
            sudo python3 -c "
import json
import sys

try:
    with open('/etc/docker/daemon.json', 'r') as f:
        config = json.load(f)
    
    # Удаляем live-restore если он есть
    if 'live-restore' in config:
        del config['live-restore']
        print('Удалена опция live-restore из конфигурации Docker')
    
    with open('/etc/docker/daemon.json', 'w') as f:
        json.dump(config, f, indent=2)
    
    print('Конфигурация Docker обновлена')
except Exception as e:
    print(f'Ошибка обновления конфигурации: {e}')
    sys.exit(1)
" || echo "Предупреждение: не удалось обновить конфигурацию через Python"
        else
            echo "Python3 недоступен, используем альтернативный метод..."
            # Альтернативный метод через sed
            sudo sed -i '/"live-restore"/d' /etc/docker/daemon.json || echo "Предупреждение: не удалось обновить конфигурацию через sed"
        fi
        
        echo "Перезапускаем Docker для применения изменений..."
        sudo systemctl restart docker || error_exit "Не удалось перезапустить Docker"
        
        # Ждем, пока Docker запустится
        sleep 5
        
        # Проверяем, что Docker запустился
        if ! sudo docker info >/dev/null 2>&1; then
            echo "Ошибка: Docker не запустился после перезапуска"
            echo "Восстанавливаем резервную копию конфигурации..."
            sudo cp /etc/docker/daemon.json.backup.* /etc/docker/daemon.json 2>/dev/null || true
            sudo systemctl restart docker
            error_exit "Не удалось запустить Docker с обновленной конфигурацией"
        fi
        
        echo "Docker успешно перезапущен с обновленной конфигурацией"
    else
        echo "Конфигурация Docker совместима со Swarm"
    fi
else
    echo "Конфигурационный файл Docker не найден, создаем базовую конфигурацию..."
    sudo mkdir -p /etc/docker
    echo '{}' | sudo tee /etc/docker/daemon.json >/dev/null
fi

# Проверяем, что Docker работает
if ! sudo docker info >/dev/null 2>&1; then
    error_exit "Docker не работает, невозможно инициализировать Swarm"
fi

if ! sudo docker info | grep -q 'Swarm: active'; then
    if ! sudo docker swarm init 2>&1 | tee /opt/docker_swarm_init.log; then
        if grep -q "This node is already part of a swarm" /opt/docker_swarm_init.log; then
            echo "Docker Swarm уже инициализирован (обнаружено при попытке init)"
        else
            echo "Ошибка инициализации Swarm, проверяем логи:"
            cat /opt/docker_swarm_init.log
            error_exit "Не удалось инициализировать Docker Swarm"
        fi
    else
        echo "Docker Swarm инициализирован успешно"
    fi
else
    echo "Docker Swarm уже инициализирован"
fi
rm -f /opt/docker_swarm_init.log

# Настройка сертификатов для Docker реестра (опционально)
if [ "$ENABLE_CERT_REGISTRATION" = "true" ]; then
    echo "=== Настройка сертификатов для $DOCKER_REGISTRY ==="
    CERT_DIR="/etc/docker/certs.d/$DOCKER_REGISTRY"
    CERT_SRC="$SCRIPT_DIR/$DOCKER_REGISTRY.crt"
    CERT_DEST="$CERT_DIR/ca.crt"

    if [ ! -f "$CERT_SRC" ]; then
        error_exit "Файл сертификата $CERT_SRC не найден. Поместите его в нужное место."
    fi

    # Проверяем, нужно ли добавлять сертификат
    if [ ! -f "$CERT_DEST" ]; then
        echo "Сертификат не найден, добавляем..."
        sudo mkdir -p "$CERT_DIR" || error_exit "Не удалось создать каталог $CERT_DIR"
        sudo cp "$CERT_SRC" "$CERT_DEST" || error_exit "Не удалось скопировать сертификат"
        
        echo "Перезапуск Docker после добавления сертификата"
        sudo systemctl restart docker || error_exit "Не удалось перезапустить docker после добавления сертификата"
    else
        echo "✓ Сертификат уже добавлен, перезапуск Docker не требуется"
    fi

    echo "✓ Настройка сертификатов завершена"
else
    echo "=== Пропуск настройки сертификатов (ENABLE_CERT_REGISTRATION=false) ==="
    echo "Для включения регистрации сертификатов запустите:"
    echo "ENABLE_CERT_REGISTRATION=true ./lab_environment_setup.sh"
fi

# Настройка docker.sock с доступом по TCP (опционально)
if [ "$ENABLE_DOCKER_TCP" = "true" ]; then
    echo "=== Настройка docker.sock с доступом по TCP ==="
    
    # Проверяем, настроен ли уже TCP доступ
    if [ -f "/etc/systemd/system/docker.service.d/override.conf" ] && grep -q "tcp://0.0.0.0:2375" "/etc/systemd/system/docker.service.d/override.conf"; then
        echo "✓ TCP доступ к docker.sock уже настроен"
    else
        echo "Настраиваем TCP доступ к docker.sock..."
        sudo mkdir -p /etc/systemd/system/docker.service.d/ || error_exit "Не удалось создать каталог для override файла docker.service"

        sudo bash -c 'cat > /etc/systemd/system/docker.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock
EOF' || error_exit "Не удалось создать override файл для docker.service"

        echo "Перезагрузка systemd и перезапуск Docker после изменения конфигурации"
        sudo systemctl daemon-reload || error_exit "Не удалось обновить systemd"
        sudo systemctl restart docker || error_exit "Не удалось перезапустить docker"
        sudo systemctl status docker --no-pager
    fi
    
    echo "✓ Настройка TCP доступа завершена"
else
    echo "=== Пропуск настройки TCP доступа к docker.sock (ENABLE_DOCKER_TCP=false) ==="
    echo "Для включения TCP доступа запустите:"
    echo "ENABLE_DOCKER_TCP=true ./lab_environment_setup.sh"
fi

echo "=== Дополнительные настройки для Astra Linux ==="

# Проверка и настройка для Astra Linux
if [ "$OS" = "astra" ]; then
    echo "Выполняем дополнительные настройки для Astra Linux..."
    
    # Проверка уровня доверия
    if command -v astra-level &>/dev/null; then
        echo "Текущий уровень доверия Astra Linux:"
        astra-level || echo "Не удалось определить уровень доверия"
    fi
    
    # Проверка и настройка SELinux (если включен)
    if command -v getenforce &>/dev/null; then
        SELINUX_STATUS=$(getenforce 2>/dev/null || echo "Disabled")
        echo "Статус SELinux: $SELINUX_STATUS"
        if [ "$SELINUX_STATUS" = "Enforcing" ]; then
            echo "Внимание: SELinux включен. Возможно потребуется дополнительная настройка для Docker."
        fi
    fi
    
    # Проверка наличия необходимых пакетов для Astra Linux
    echo "Проверяем наличие необходимых пакетов для Astra Linux..."
    MISSING_PACKAGES=""
    
    for package in curl wget ca-certificates; do
        if ! dpkg -l | grep -q "^ii.*$package "; then
            MISSING_PACKAGES="$MISSING_PACKAGES $package"
        fi
    done
    
    if [ -n "$MISSING_PACKAGES" ]; then
        echo "Устанавливаем недостающие пакеты:$MISSING_PACKAGES"
        sudo apt install -y $MISSING_PACKAGES || echo "Предупреждение: не удалось установить некоторые пакеты"
    else
        echo "Все необходимые пакеты установлены"
    fi
fi

echo "=== Проверка установки ==="

echo "Проверяем установленные компоненты:"

# Проверка Python
if command -v python3 &>/dev/null; then
    echo "✓ Python3: $(python3 --version)"
else
    echo "✗ Python3 не найден"
fi

# Проверка pip
if command -v pip3 &>/dev/null; then
    echo "✓ pip3: $(pip3 --version | cut -d' ' -f1-2)"
else
    echo "✗ pip3 не найден"
fi

# Проверка Ansible
if command -v ansible &>/dev/null; then
    echo "✓ Ansible: $(ansible --version | head -n1)"
else
    echo "✗ Ansible не найден"
fi

# Проверка Docker
if command -v docker &>/dev/null; then
    echo "✓ Docker: $(docker --version)"
else
    echo "✗ Docker не найден"
fi

# Проверка Docker Swarm
if sudo docker info | grep -q 'Swarm: active'; then
    echo "✓ Docker Swarm: активен"
else
    echo "✗ Docker Swarm не активен"
fi

echo ""
echo "=== Установка и настройка Docker завершена успешно! ==="
echo ""
echo "Текущие настройки:"
echo "- Docker реестр: $DOCKER_REGISTRY"
echo "- Регистрация сертификатов: $ENABLE_CERT_REGISTRATION"
echo "- TCP доступ к docker.sock: $ENABLE_DOCKER_TCP"
echo ""
echo "ВАЖНО! Для применения изменений группы docker необходимо:"
echo "1. ЗАВЕРШИТЬ текущую сессию и открыть НОВУЮ"
echo "2. После входа в новую сессию запустить: ./deploy.sh"
echo ""
echo "Скрипт deploy.sh выполнит:"
echo "- Запуск Portainer для управления Docker"
echo "- Развертывание сайта с документацией"
echo "- Предоставит ссылки на все доступные сервисы"
echo ""
if [ "$ENABLE_CERT_REGISTRATION" = "false" ]; then
    echo "Для настройки сертификатов:"
    echo "ENABLE_CERT_REGISTRATION=true ./lab_environment_setup.sh"
fi
if [ "$ENABLE_DOCKER_TCP" = "false" ]; then
    echo "Для включения TCP доступа к docker.sock:"
    echo "ENABLE_DOCKER_TCP=true ./lab_environment_setup.sh"
fi
echo ""
if [ "$OS" = "astra" ]; then
    echo "Специфичные рекомендации для Astra Linux:"
    echo "- Убедитесь, что уровень доверия системы соответствует требованиям"
    echo "- При необходимости настройте SELinux для работы с Docker"
    echo "- Проверьте настройки брандмауэра для портов 8000, 9000, 9443, 37527"
fi
