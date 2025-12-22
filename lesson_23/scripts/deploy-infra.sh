#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()    { echo -e "${RED}[ERR ]${NC} $*"; }
step()   { echo -e "${BLUE}[STEP]${NC} $*"; }

ROOT_DIR="/home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_23"
TF_DIR="$ROOT_DIR/terraform"

# Check prerequisites
log "Checking prerequisites..."
for bin in terraform yc ansible ansible-playbook; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    err "$bin is not installed"
    exit 1
  fi
done

# Check if YC vars are exported
if [ -z "${YC_TOKEN:-}" ] || [ -z "${YC_CLOUD_ID:-}" ] || [ -z "${YC_FOLDER_ID:-}" ]; then
  warn "YC environment variables not set. Please run:"
  echo "export YC_TOKEN=\$(yc iam create-token)"
  echo "export YC_CLOUD_ID=\$(yc config get cloud-id)"
  echo "export YC_FOLDER_ID=\$(yc config get folder-id)"
  exit 1
fi

# Step 1: Terraform init and apply
step "Step 1/2: Deploying infrastructure with Terraform..."
cd "$TF_DIR"
log "Running: terraform init"
terraform init -input=false

log "Running: terraform plan"
terraform plan -out=tfplan

log "Running: terraform apply"
terraform apply tfplan

# Step 2: Wait for instances to be ready
step "Step 2/3: Waiting for instances to be ready (60s)..."
log "Waiting for cloud-init to complete..."
sleep 60

# Step 3: Run Ansible playbooks
step "Step 3/3: Running Ansible playbooks..."
ANS_DIR="$ROOT_DIR/ansible"

log "Testing connectivity..."
cd "$ANS_DIR"
ansible all -m ping

log "Installing Salt Master and Minions..."
ansible-playbook playbooks/site.yml

# Show results
step "Deployment complete!"
log "Getting IPs..."

cd "$TF_DIR"
SALT_MASTER_IP=$(terraform output -raw salt_master_external_ip)
log "Salt Master IP: $SALT_MASTER_IP"

echo ""
log "═══════════════════════════════════════════════════════════════"
log "Infrastructure deployed successfully!"
log "═══════════════════════════════════════════════════════════════"
echo ""
log "Salt Master:"
log "  External IP: $SALT_MASTER_IP"
log "  SSH: ssh ubuntu@$SALT_MASTER_IP"
echo ""
log "Next steps:"
log "1. Apply Salt States: cd ansible && ansible-playbook playbooks/apply-salt-states.yml"
log "2. Or manually on Salt Master: sudo salt '*' state.apply"
echo ""

