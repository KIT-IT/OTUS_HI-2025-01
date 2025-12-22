#!/bin/bash
###############################################################################
# Копирование и загрузка локальных Docker-образов на все Docker-ноды кластера
#
# Источник образов: 
#   /home/sedunovsv/OTUS/OTUS_HI-2025-01/project/docker/*.tar
# Цель:
#   - скопировать .tar файлы на все Docker manager/worker CT
#   - выполнить docker load для каждого образа на каждой ноде
#
# Формат имени файла:
#   nexus.netlab.local_cardgateway_2.3.1-master-250314.1.tar
#   соответствует образу:
#   nexus.netlab.local/cardgateway:2.3.1-master-250314.1
#   (реальный тег берётся из самого tar, docker load его восстановит)
#
# Требования:
#   - из WSL должен быть доступен SSH к CT:
#       root@192.168.50.31  (ct-docker-mgr-1)
#       root@192.168.50.32  (ct-docker-mgr-2)
#       root@192.168.50.41  (ct-docker-wkr-1)
#       root@192.168.50.42  (ct-docker-wkr-2)
#   - на всех этих CT установлен и запущен Docker
#   - есть пароль/ключ для root (или можно заменить пользователя ниже)
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGES_DIR="$PROJECT_ROOT/docker"

# Ноды Docker Swarm (можно изменить при необходимости)
DOCKER_NODES=(
  "root@192.168.50.31" # ct-docker-mgr-1.nix.netlab.local
  "root@192.168.50.32" # ct-docker-mgr-2.nix.netlab.local
  "root@192.168.50.41" # ct-docker-wkr-1.nix.netlab.local
  "root@192.168.50.42" # ct-docker-wkr-2.nix.netlab.local
)

REMOTE_DIR="/opt/docker-images"

echo "=== Копирование и загрузка Docker-образов на все Docker-ноды ==="
echo "Локальный каталог с образами: $IMAGES_DIR"
echo ""

if [ ! -d "$IMAGES_DIR" ]; then
  echo "ERROR: Каталог $IMAGES_DIR не существует"
  exit 1
fi

mapfile -t TAR_FILES < <(find "$IMAGES_DIR" -maxdepth 1 -type f -name "*.tar" | sort)

if [ "${#TAR_FILES[@]}" -eq 0 ]; then
  echo "ERROR: В каталоге $IMAGES_DIR не найдено файлов *.tar"
  exit 1
fi

echo "Найдены образы:"
for f in "${TAR_FILES[@]}"; do
  echo "  - $(basename "$f")"
done
echo ""

for NODE in "${DOCKER_NODES[@]}"; do
  echo "=== Обработка ноды $NODE ==="

  echo "Создаём каталог $REMOTE_DIR на $NODE..."
  ssh -o StrictHostKeyChecking=no "$NODE" "mkdir -p '$REMOTE_DIR'" || {
    echo "ERROR: Не удалось создать каталог $REMOTE_DIR на $NODE"
    exit 1
  }

  echo "Копируем tar-файлы на $NODE:$REMOTE_DIR ..."
  scp -o StrictHostKeyChecking=no "${TAR_FILES[@]}" "$NODE:$REMOTE_DIR/" || {
    echo "ERROR: Не удалось скопировать tar-файлы на $NODE"
    exit 1
  }

  echo "Загружаем Docker-образы на $NODE из $REMOTE_DIR ..."
  ssh -o StrictHostKeyChecking=no "$NODE" "set -euo pipefail; \
    if ! command -v docker >/dev/null 2>&1; then \
      echo 'ERROR: docker не найден на $NODE'; exit 1; \
    fi; \
    for img in '$REMOTE_DIR'/*.tar; do \
      echo \"  -> docker load -i \${img}\"; \
      docker load -i \"\${img}\"; \
    done" || {
    echo "ERROR: Не удалось выполнить docker load на $NODE"
    exit 1
  }

  echo "✓ Нода $NODE обработана успешно"
  echo ""
done

echo "=== Все Docker-ноды успешно обработаны ==="
echo "Образы из $IMAGES_DIR загружены во все Docker-ноды кластера."


