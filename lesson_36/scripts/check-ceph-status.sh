#!/bin/bash
# Скрипт проверки состояния Ceph кластера

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Проверка состояния Ceph кластера"
echo "=========================================="
echo ""

# Проверка наличия команды ceph
if ! command -v ceph &> /dev/null; then
    echo -e "${RED}Ошибка: команда 'ceph' не найдена${NC}"
    echo "Установите ceph-common: sudo apt-get install -y ceph-common"
    exit 1
fi

# Проверка подключения к кластеру
echo -e "${YELLOW}[1/7] Проверка подключения к кластеру...${NC}"
if ! ceph -s &> /dev/null; then
    echo -e "${RED}Ошибка: не удается подключиться к кластеру Ceph${NC}"
    echo "Убедитесь, что:"
    echo "  - Вы находитесь на узле с доступом к кластеру"
    echo "  - Файл /etc/ceph/ceph.conf существует"
    echo "  - Ключи аутентификации настроены"
    exit 1
fi
echo -e "${GREEN}✓ Подключение к кластеру успешно${NC}"
echo ""

# Общий статус кластера
echo -e "${YELLOW}[2/7] Общий статус кластера:${NC}"
ceph -s
echo ""

# Статус мониторов
echo -e "${YELLOW}[3/7] Статус мониторов (MON):${NC}"
ceph mon stat
echo ""
ceph mon dump
echo ""

# Статус OSD
echo -e "${YELLOW}[4/7] Статус OSD узлов:${NC}"
ceph osd tree
echo ""
echo "Детальная информация об OSD:"
ceph osd df tree
echo ""

# Статус пулов
echo -e "${YELLOW}[5/7] Статус пулов (Pools):${NC}"
ceph df
echo ""
echo "Детальная информация о пулах:"
ceph df detail
echo ""

# Статус Placement Groups
echo -e "${YELLOW}[6/7] Статус Placement Groups (PG):${NC}"
ceph pg stat
echo ""
echo "Распределение PG по состояниям:"
ceph pg dump | grep -E "^pg_stat|^sum" | head -2
echo ""

# Статус CephFS (если настроен)
echo -e "${YELLOW}[7/7] Статус CephFS:${NC}"
if ceph fs ls &> /dev/null && [ -n "$(ceph fs ls 2>/dev/null)" ]; then
    ceph fs status
    echo ""
    ceph fs ls
else
    echo -e "${YELLOW}CephFS не настроен${NC}"
fi
echo ""

# Проверка здоровья кластера
echo "=========================================="
echo "  Итоговая проверка здоровья"
echo "=========================================="
HEALTH=$(ceph health | awk '{print $1}')
if [ "$HEALTH" = "HEALTH_OK" ]; then
    echo -e "${GREEN}✓ Кластер здоров: $HEALTH${NC}"
    EXIT_CODE=0
else
    echo -e "${RED}✗ Проблемы в кластере: $HEALTH${NC}"
    echo ""
    echo "Детальная информация о проблемах:"
    ceph health detail
    EXIT_CODE=1
fi
echo ""

# Дополнительная информация
echo "=========================================="
echo "  Дополнительная информация"
echo "=========================================="
echo "Версия Ceph:"
ceph --version
echo ""
echo "Конфигурация кластера:"
ceph config dump | head -10
echo ""

exit $EXIT_CODE

