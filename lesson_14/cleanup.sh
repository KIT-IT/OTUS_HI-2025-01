#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
err()    { echo -e "${RED}[ERR ]${NC} $*"; }

ROOT_DIR="/home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_14"
TF_DIR="$ROOT_DIR/terraform"

echo "⚠️  WARNING: This will destroy all infrastructure!"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  log "Cancelled"
  exit 0
fi

log "Destroying infrastructure..."
cd "$TF_DIR"
terraform destroy -auto-approve

log "Cleanup complete"

