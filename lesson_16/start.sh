#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
step()   { echo -e "${BLUE}[STEP]${NC} $*"; }

ROOT_DIR="/home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_16"

step "Exporting Yandex Cloud authentication variables..."
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)

log "YC_TOKEN exported"
log "YC_CLOUD_ID: $YC_CLOUD_ID"
log "YC_FOLDER_ID: $YC_FOLDER_ID"

echo ""
step "Running deployment script..."
echo ""

"$ROOT_DIR/deploy-cluster.sh"
