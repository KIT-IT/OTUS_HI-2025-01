#!/bin/bash

# Скрипт для расширения диска Proxmox после увеличения диска в VMware
# Использование: ./expand_disk_proxmox.sh [размер_в_GB]

echo "=========================================="
echo "Расширение диска Proxmox"
echo "=========================================="
echo ""

# Проверка текущего размера
echo "1. Текущий размер диска:"
fdisk -l /dev/sda | grep "Disk /dev/sda"
echo ""

# Проверка LVM
echo "2. Текущее состояние LVM:"
pvs
vgs
echo ""

# Шаг 1: Расширение раздела (если диск уже увеличен в VMware)
echo "3. Расширение раздела sda3..."
echo "   ВНИМАНИЕ: Убедитесь, что вы УЖЕ увеличили диск в VMware!"
read -p "   Диск увеличен в VMware? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    echo "   Сначала увеличьте диск в VMware, затем запустите скрипт снова"
    exit 1
fi

# Проверка, нужно ли расширять раздел
PARTITION_END=$(parted /dev/sda unit s print | grep "^ 3" | awk '{print $3}')
DISK_END=$(parted /dev/sda unit s print | grep "^Disk /dev/sda" | awk '{print $3}' | sed 's/s$//')

if [ "$PARTITION_END" -lt "$DISK_END" ]; then
    echo "   Расширяю раздел sda3..."
    # Удаляем раздел и создаем заново с большим размером (данные сохраняются)
    echo "   ВНИМАНИЕ: Это безопасная операция, данные не будут потеряны"
    parted /dev/sda resizepart 3 100%
    partprobe /dev/sda
    sleep 2
    echo "   ✓ Раздел расширен"
else
    echo "   ✓ Раздел уже использует весь доступный размер"
fi

# Шаг 2: Расширение физического тома
echo ""
echo "4. Расширение физического тома (PV)..."
pvresize /dev/sda3
echo "   ✓ PV расширен"

# Шаг 3: Проверка свободного места в VG
echo ""
echo "5. Проверка свободного места в Volume Group:"
vgs pve
FREE_SPACE=$(vgs --noheadings --units g pve | awk '{print $7}' | sed 's/g$//')
echo "   Свободное место: ${FREE_SPACE}G"

# Шаг 4: Расширение thin pool (если нужно)
echo ""
echo "6. Расширение thin pool 'data'..."
# Получаем текущий размер thin pool
CURRENT_SIZE=$(lvs --noheadings --units g pve/data | awk '{print $4}' | sed 's/g$//')
# Расширяем на все доступное место или на указанный размер
if [ -n "$1" ]; then
    NEW_SIZE="${1}G"
    echo "   Расширяю thin pool до ${NEW_SIZE}..."
    lvextend -L ${NEW_SIZE} pve/data
else
    # Расширяем на все доступное место
    echo "   Расширяю thin pool на все доступное место..."
    lvextend -l +100%FREE pve/data
fi
echo "   ✓ Thin pool расширен"

# Шаг 5: Итоговая информация
echo ""
echo "=========================================="
echo "Расширение завершено!"
echo "=========================================="
echo ""
echo "Текущее состояние:"
pvs
vgs
lvs | head -5
echo ""
echo "Теперь вы можете расширить контейнеры через веб-интерфейс Proxmox"
echo "или командой: pct resize <vmid> <disk> <size>"




