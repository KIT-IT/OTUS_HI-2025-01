#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()    { echo -e "${RED}[ERR ]${NC} $*"; }

ROOT_DIR="/home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_12"
TF_DIR="$ROOT_DIR/pg_ha/terraform"
ANS_DIR="$ROOT_DIR/pg_ha/ansible"

log "Checking prerequisites..."
for bin in terraform ansible ansible-playbook jq yc; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    err "$bin is not installed"; exit 1;
  fi
done

log "Authenticating to Yandex Cloud (using yc config)"
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)

log "Terraform: init & apply ($TF_DIR)"
cd "$TF_DIR"
terraform init -input=false
terraform apply -auto-approve -input=false

HAPROXY_IP=$(terraform output -raw haproxy_public_ip)
log "HAProxy public IP: $HAPROXY_IP"

cd "$ROOT_DIR"
log "Updating Ansible inventory..."
"$ROOT_DIR/update-inventory.sh" "$HAPROXY_IP"

log "Waiting 60s for instances cloud-init"
sleep 60

log "Running Ansible playbook"
cd "$ANS_DIR"
ansible -i inventories/prod/hosts.ini all -m ping
ansible-playbook -i inventories/prod/hosts.ini playbooks/site.yml

log "Cluster ready. Next steps:"
echo " - Put HAProxy IP into Saleor .env (DATABASE_URL)"
echo " - cd $ROOT_DIR/saleor && docker compose up -d && docker compose exec api python manage.py migrate"
echo " - API: http://localhost:8000/graphql/  Dashboard: http://localhost:9000/"
