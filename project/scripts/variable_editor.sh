#!/bin/bash
#######################################################################
# ВЕРСИЯ: 1.0.1. Дата 15.12.2025 18:00
# Скрипт для интерактивного редактирования переменных Ansible
#
# История версий:
# - 1.0.1 (15.12.2025): перенос путей с /tmp на /opt, добавлен вывод версии (-V|--version)
# - 1.0.0: начальная версия скрипта
#
# Использование:
#   ./variable_editor.sh [VARS_DIR]
#   ./variable_editor.sh -h|--help
#   ./variable_editor.sh -V|--version
#
# Примеры:
#   ./variable_editor.sh
#       - использовать каталог по умолчанию (/opt/Deploy/inventories/ATM_demo/group_vars/all/main)
#   ./variable_editor.sh /path/to/vars
#       - указать произвольный каталог с YAML-переменными
#   ./variable_editor.sh -V
#       - вывести версию скрипта и дату сборки

set -e

SCRIPT_VERSION="1.0.1"
SCRIPT_VERSION_DATE="15.12.2025 18:00"

if [[ "${1:-}" == "-V" || "${1:-}" == "--version" ]]; then
    echo "variable_editor.sh версия ${SCRIPT_VERSION} от ${SCRIPT_VERSION_DATE}"
    exit 0
fi

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Путь к каталогу с переменными (по умолчанию)
DEFAULT_VARS_DIR="/opt/Deploy/inventories/ATM_demo/group_vars/all/main"
VARS_DIR=""

# Временный каталог для хранения измененных файлов
TEMP_DIR="/opt/vars_editor_$$"
BACKUP_DIR="/opt/vars_backup_$$"
mkdir -p "$TEMP_DIR"
mkdir -p "$BACKUP_DIR"

# Функция для вывода справки
show_help() {
    echo -e "${BLUE}Использование:${NC}"
    echo "  $0 [ОПЦИИ] [VARS_DIR]"
    echo
    echo -e "${BLUE}Аргументы:${NC}"
    echo "  VARS_DIR    Путь к каталогу с YAML файлами переменных"
    echo
    echo -e "${BLUE}Опции:${NC}"
    echo "  -h, --help  Показать эту справку"
    echo
    echo -e "${BLUE}Примеры:${NC}"
    echo "  $0                                                    # Использовать каталог по умолчанию"
    echo "  $0 /path/to/vars                                      # Указать конкретный каталог"
    echo "  $0 /opt/Deploy/inventories/production/group_vars/all/main"
    echo
    echo -e "${BLUE}Каталог по умолчанию:${NC} $DEFAULT_VARS_DIR"
}

# Функция для вывода заголовка
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Редактор переменных Ansible${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Каталог переменных:${NC} $VARS_DIR"
    echo
}

# Функция для вывода сообщения об ошибке
print_error() {
    echo -e "${RED}Ошибка: $1${NC}" >&2
}

# Функция для вывода сообщения об успехе
print_success() {
    echo -e "${GREEN}$1${NC}"
}

# Функция для вывода предупреждения
print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

# Функция для проверки существования каталога
check_directory() {
    if [ ! -d "$VARS_DIR" ]; then
        print_error "Каталог $VARS_DIR не существует!"
        exit 1
    fi
}

# Функция для создания резервных копий
create_backup() {
    local yaml_files=("$@")
    
    echo -e "${YELLOW}Создание резервных копий...${NC}"
    
    for file in "${yaml_files[@]}"; do
        local backup_file="$BACKUP_DIR/$(basename "$file").backup"
        cp "$file" "$backup_file"
        print_success "Резервная копия создана: $(basename "$backup_file")"
    done
    
    echo
}

# Функция для парсинга YAML файла и извлечения переменных
parse_yaml_file() {
    local file="$1"
    local temp_file="$TEMP_DIR/$(basename "$file")"
    
    # Копируем файл во временный каталог
    cp "$file" "$temp_file"
    
    # Простой парсер YAML для извлечения переменных
    python3 -c "
import yaml
import sys
import os

def parse_yaml_file(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Парсим YAML
        data = yaml.safe_load(content)
        
        if not isinstance(data, dict):
            return
        
        for key, value in data.items():
            if value is None:
                continue
                
            if isinstance(value, dict):
                # Словарь - выводим как DICT
                dict_content = ''
                for k, v in value.items():
                    dict_content += f'{k}: {v}__NEWLINE__'
                dict_content = dict_content.rstrip('__NEWLINE__')
                print(f'{key}|DICT|{dict_content}|{file_path}')
            elif isinstance(value, list):
                # Массив - выводим как ARRAY
                array_content = ''
                for item in value:
                    array_content += f'- {item}__NEWLINE__'
                array_content = array_content.rstrip('__NEWLINE__')
                print(f'{key}|ARRAY|{array_content}|{file_path}')
            else:
                # Простое значение
                print(f'{key}||{value}|{file_path}')
                
    except Exception as e:
        print(f'Error parsing {file_path}: {e}', file=sys.stderr)

parse_yaml_file('$file')
"
}

# Функция для обновления значения переменной в файле
update_variable_in_file() {
    local file="$1"
    local var_name="$2"
    local new_value="$3"
    local temp_file="$TEMP_DIR/$(basename "$file")"
    
    # Экранируем специальные символы для sed
    escaped_var_name=$(printf '%s\n' "$var_name" | sed 's/[[\.*^$()+?{|]/\\&/g')
    escaped_new_value=$(printf '%s\n' "$new_value" | sed 's/[[\.*^$()+?{|]/\\&/g')
    
    # Определяем, нужно ли заключать значение в кавычки
    local quoted_value
    if [[ "$new_value" =~ ^[0-9]+$ ]] || [[ "$new_value" =~ ^[0-9]+\.[0-9]+$ ]] || [[ "$new_value" =~ ^(true|false)$ ]]; then
        # Числовые значения и boolean без кавычек
        quoted_value="$new_value"
    else
        # Строковые значения в кавычках
        quoted_value="\"$new_value\""
    fi
    
    # Обновляем значение в файле
    sed -i "s/^${escaped_var_name}:[[:space:]]*.*/${escaped_var_name}: ${quoted_value}/" "$temp_file"
}

# Функция для интерактивного редактирования переменных
edit_variables() {
    local file="$1"
    local file_vars=()
    
    echo -e "${YELLOW}Файл: $(basename "$file")${NC}"
    echo "----------------------------------------"
    
    # Собираем все переменные из файла
    while IFS='|' read -r var_name var_type var_value source_file; do
        if [ "$source_file" = "$file" ]; then
            file_vars+=("$var_name|$var_type|$var_value")
        fi
    done < <(parse_yaml_file "$file")
    
    if [ ${#file_vars[@]} -eq 0 ]; then
        print_warning "В файле $(basename "$file") не найдено переменных для редактирования."
        return
    fi
    
    # Редактируем каждую переменную
    for var_info in "${file_vars[@]}"; do
        IFS='|' read -r var_name var_type var_value <<< "$var_info"
        
        echo
        echo -e "${BLUE}Переменная:${NC} $var_name"
        
        # Обработка разных типов данных
        case "$var_type" in
            "DICT")
                echo -e "${BLUE}Тип:${NC} словарь (YAML объект)"
                echo -e "${BLUE}Текущее значение:${NC}"
                echo "$var_value" | sed 's/__NEWLINE__/\n/g' | sed 's/^/  /'
                echo
                echo -e "${YELLOW}Открываем редактор для редактирования словаря...${NC}"
                edit_dict_variable "$file" "$var_name" "$var_value"
                ;;
            "ARRAY")
                echo -e "${BLUE}Тип:${NC} массив (YAML список)"
                echo -e "${BLUE}Текущее значение:${NC}"
                echo "$var_value" | sed 's/__NEWLINE__/\n/g' | sed 's/^/  /'
                echo
                echo -e "${YELLOW}Открываем редактор для редактирования массива...${NC}"
                edit_array_variable "$file" "$var_name" "$var_value"
                ;;
            *)
                echo -e "${BLUE}Текущее значение:${NC} $var_value"
                echo -e "${BLUE}Тип:${NC} $(get_variable_type "$var_value")"
                echo -n "Введите новое значение (Enter для пропуска): "
                
                read -r new_value
                
                if [ -n "$new_value" ]; then
                    # Валидируем новое значение
                    if validate_value "$var_value" "$new_value"; then
                        update_variable_in_file "$file" "$var_name" "$new_value"
                        print_success "Переменная $var_name обновлена: $var_value -> $new_value"
                    else
                        print_error "Неверный тип значения для переменной $var_name. Ожидается: $(get_variable_type "$var_value")"
                    fi
                else
                    echo "Переменная $var_name оставлена без изменений."
                fi
                ;;
        esac
    done
}

# Функция для редактирования словаря
edit_dict_variable() {
    local file="$1"
    local var_name="$2"
    local current_value="$3"
    local temp_file="$TEMP_DIR/$(basename "$file")"
    local edit_file="$TEMP_DIR/${var_name}_edit.yaml"
    
    # Создаем временный файл с содержимым словаря (преобразуем __NEWLINE__ в реальные переносы строк)
    echo "$current_value" | sed 's/__NEWLINE__/\n/g' > "$edit_file"
    
    # Определяем редактор
    local editor="${EDITOR:-nano}"
    if ! command -v "$editor" &> /dev/null; then
        editor="vi"
    fi
    
    echo -e "${YELLOW}Открываем редактор для переменной $var_name...${NC}"
    echo -e "${YELLOW}Редактор: $editor${NC}"
    echo -e "${YELLOW}Сохраните и закройте редактор для применения изменений.${NC}"
    echo
    
    # Открываем редактор
    if "$editor" "$edit_file"; then
        # Читаем отредактированное содержимое
        local new_value=$(cat "$edit_file")
        
        if [ "$new_value" != "$current_value" ]; then
            # Обновляем переменную в файле
            update_dict_variable_in_file "$file" "$var_name" "$new_value"
            print_success "Переменная $var_name (словарь) обновлена"
        else
            echo "Переменная $var_name оставлена без изменений."
        fi
    else
        print_error "Ошибка при редактировании переменной $var_name"
    fi
    
    # Удаляем временный файл
    rm -f "$edit_file"
}

# Функция для редактирования массива
edit_array_variable() {
    local file="$1"
    local var_name="$2"
    local current_value="$3"
    local temp_file="$TEMP_DIR/$(basename "$file")"
    local edit_file="$TEMP_DIR/${var_name}_edit.yaml"
    
    # Создаем временный файл с содержимым массива (преобразуем __NEWLINE__ в реальные переносы строк)
    echo "$current_value" | sed 's/__NEWLINE__/\n/g' > "$edit_file"
    
    # Определяем редактор
    local editor="${EDITOR:-nano}"
    if ! command -v "$editor" &> /dev/null; then
        editor="vi"
    fi
    
    echo -e "${YELLOW}Открываем редактор для переменной $var_name...${NC}"
    echo -e "${YELLOW}Редактор: $editor${NC}"
    echo -e "${YELLOW}Сохраните и закройте редактор для применения изменений.${NC}"
    echo
    
    # Открываем редактор
    if "$editor" "$edit_file"; then
        # Читаем отредактированное содержимое
        local new_value=$(cat "$edit_file")
        
        if [ "$new_value" != "$current_value" ]; then
            # Обновляем переменную в файле
            update_array_variable_in_file "$file" "$var_name" "$new_value"
            print_success "Переменная $var_name (массив) обновлена"
        else
            echo "Переменная $var_name оставлена без изменений."
        fi
    else
        print_error "Ошибка при редактировании переменной $var_name"
    fi
    
    # Удаляем временный файл
    rm -f "$edit_file"
}

# Функция для обновления словаря в файле
update_dict_variable_in_file() {
    local file="$1"
    local var_name="$2"
    local new_value="$3"
    local temp_file="$TEMP_DIR/$(basename "$file")"
    
    # Используем Python для обновления YAML в временном файле
    python3 -c "
import yaml
import sys
import os

def update_yaml_dict(file_path, var_name, new_value):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Парсим YAML
        data = yaml.safe_load(content)
        
        if not isinstance(data, dict):
            return
        
        # Парсим новое значение словаря
        new_dict = {}
        for line in new_value.split('\n'):
            line = line.strip()
            if line and ':' in line:
                key, value = line.split(':', 1)
                new_dict[key.strip()] = value.strip()
        
        # Обновляем переменную
        data[var_name] = new_dict
        
        # Записываем обратно
        with open(file_path, 'w', encoding='utf-8') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
            
    except Exception as e:
        print(f'Error updating {file_path}: {e}', file=sys.stderr)

update_yaml_dict('$temp_file', '$var_name', '''$new_value''')
"
}

# Функция для обновления массива в файле
update_array_variable_in_file() {
    local file="$1"
    local var_name="$2"
    local new_value="$3"
    local temp_file="$TEMP_DIR/$(basename "$file")"
    
    # Используем Python для обновления YAML
    python3 -c "
import yaml
import sys
import os

def update_yaml_array(file_path, var_name, new_value):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Парсим YAML
        data = yaml.safe_load(content)
        
        if not isinstance(data, dict):
            return
        
        # Парсим новое значение массива
        new_array = []
        for line in new_value.split('\n'):
            line = line.strip()
            if line and line.startswith('- '):
                new_array.append(line[2:])
            elif line and not line.startswith('- '):
                # Если строка не начинается с '- ', добавляем как есть
                new_array.append(line)
        
        # Обновляем переменную
        data[var_name] = new_array
        
        # Записываем обратно
        with open(file_path, 'w', encoding='utf-8') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
            
    except Exception as e:
        print(f'Error updating {file_path}: {e}', file=sys.stderr)

update_yaml_array('$temp_file', '$var_name', '''$new_value''')
"
}

# Функция для определения типа переменной
get_variable_type() {
    local value="$1"
    
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "число"
    elif [[ "$value" =~ ^(true|false)$ ]]; then
        echo "логическое значение"
    elif [[ "$value" =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "число с плавающей точкой"
    else
        echo "строка"
    fi
}

# Функция для валидации значения
validate_value() {
    local old_value="$1"
    local new_value="$2"
    local old_type=$(get_variable_type "$old_value")
    
    case "$old_type" in
        "число")
            [[ "$new_value" =~ ^[0-9]+$ ]]
            ;;
        "логическое значение")
            [[ "$new_value" =~ ^(true|false)$ ]]
            ;;
        "число с плавающей точкой")
            [[ "$new_value" =~ ^[0-9]+\.[0-9]+$ ]]
            ;;
        "строка")
            true  # Строки принимаем всегда
            ;;
        *)
            true
            ;;
    esac
}

# Функция для сохранения изменений
save_changes() {
    echo
    echo -e "${YELLOW}Сохранение изменений...${NC}"
    
    # Копируем измененные файлы обратно
    for temp_file in "$TEMP_DIR"/*.yaml; do
        if [ -f "$temp_file" ]; then
            original_file="$VARS_DIR/$(basename "$temp_file")"
            cp "$temp_file" "$original_file"
            print_success "Файл $(basename "$original_file") сохранен"
        fi
    done
    
    # Удаляем временный каталог
    rm -rf "$TEMP_DIR"
    
    print_success "Все изменения сохранены!"
}

# Функция для отмены изменений
cancel_changes() {
    echo
    print_warning "Изменения отменены."
    print_success "Резервные копии сохранены в: $BACKUP_DIR"
    rm -rf "$TEMP_DIR"
    exit 0
}

# Основная функция
main() {
    # Обработка аргументов командной строки
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                print_error "Неизвестная опция: $1"
                echo "Используйте -h или --help для получения справки."
                exit 1
                ;;
            *)
                if [ -z "$VARS_DIR" ]; then
                    VARS_DIR="$1"
                else
                    print_error "Слишком много аргументов. Используйте -h или --help для получения справки."
                    exit 1
                fi
                ;;
        esac
        shift
    done
    
    # Если VARS_DIR не указан, используем значение по умолчанию
    if [ -z "$VARS_DIR" ]; then
        VARS_DIR="$DEFAULT_VARS_DIR"
    fi
    
    print_header
    
    # Проверяем существование каталога
    check_directory
    
    # Получаем список YAML файлов
    yaml_files=($(find "$VARS_DIR" -name "*.yaml" -type f))
    
    if [ ${#yaml_files[@]} -eq 0 ]; then
        print_error "В каталоге $VARS_DIR не найдено YAML файлов!"
        exit 1
    fi
    
    echo -e "${GREEN}Найдено файлов: ${#yaml_files[@]}${NC}"
    for file in "${yaml_files[@]}"; do
        echo "  - $(basename "$file")"
    done
    echo
    
    # Создаем резервные копии
    create_backup "${yaml_files[@]}"
    
    # Редактируем переменные в каждом файле
    for file in "${yaml_files[@]}"; do
        edit_variables "$file"
        echo
    done
    
    # Спрашиваем о сохранении с обязательным вводом y/n
    while true; do
        echo -e "${YELLOW}Сохранить изменения? (y/n):${NC} "
        read -r save_choice
        
        case "$save_choice" in
            [Yy]|[Yy][Ee][Ss])
                save_changes
                break
                ;;
            [Nn]|[Nn][Oo])
                cancel_changes
                break
                ;;
            *)
                echo -e "${RED}Пожалуйста, введите 'y' для сохранения или 'n' для отмены${NC}"
                ;;
        esac
    done
}

# Обработка сигналов для очистки временных файлов
trap 'rm -rf "$TEMP_DIR"; print_success "Резервные копии сохранены в: $BACKUP_DIR"; exit 1' INT TERM

# Запуск основной функции
main "$@"
