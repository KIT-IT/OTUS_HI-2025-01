#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
err()    { echo -e "${RED}[ERR ]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }

ROOT_DIR="/home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_16"
TF_DIR="$ROOT_DIR/terraform"

echo ""
warn "═══════════════════════════════════════════════════════════════"
warn "⚠️  WARNING: This will destroy all infrastructure!"
warn "═══════════════════════════════════════════════════════════════"
echo ""
warn "This will delete:"
warn "  - Kafka node with 2 brokers"
warn "  - ELK node (OpenSearch, Logstash, Dashboards)"
warn "  - APP node (nginx, Fluent Bit)"
warn "  - VPC network and subnet"
warn "  - All data and logs"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  log "Cancelled. No changes made."
  exit 0
fi

log "Destroying infrastructure..."
cd "$TF_DIR"

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
  log "Terraform not initialized. Running init..."
  terraform init -input=false
fi

log "Running terraform destroy..."
terraform destroy -auto-approve -input=false

log ""
log "═══════════════════════════════════════════════════════════════"
log "Cleanup complete! All resources have been destroyed."
log "═══════════════════════════════════════════════════════════════"
echo ""
