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

ROOT_DIR="/home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_14"
TF_DIR="$ROOT_DIR/terraform"
ANS_DIR="$ROOT_DIR/ansible"

# Check prerequisites
log "Checking prerequisites..."
for bin in terraform ansible ansible-playbook jq yc; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    err "$bin is not installed"
    exit 1
  fi
done

# Step 1: Terraform init and apply
step "Step 1/5: Deploying infrastructure with Terraform..."
cd "$TF_DIR"
log "Running: terraform init"
terraform init -input=false

log "Running: terraform apply"
terraform apply -auto-approve -input=false

# Step 2: Get outputs and update inventory
step "Step 2/5: Updating Ansible inventory..."
cd "$ANS_DIR"
log "Running: update-inventory.sh"
"$ANS_DIR/update-inventory.sh"

# Step 3: Wait for instances to be ready
step "Step 3/5: Waiting for instances to be ready (60s)..."
log "Waiting for cloud-init to complete..."
sleep 60

# Step 4: Run Ansible playbooks
step "Step 4/5: Running Ansible playbooks..."

log "Testing connectivity..."
ansible -i inventory.yml all -m ping

log "Deploying Consul cluster..."
ansible-playbook -i inventory.yml playbook-consul.yml

log "Installing nginx on web servers..."
ansible-playbook -i inventory.yml playbook-web.yml

log "Registering services in Consul..."
ansible-playbook -i inventory.yml playbook-register-services.yml

log "Configuring DNS..."
ansible-playbook -i inventory.yml playbook-dns-config.yml

log "Deploying OpenSearch..."
ansible-playbook -i inventory.yml playbook-opensearch.yml

log "Configuring Fluentd for log shipping..."
ansible-playbook -i inventory.yml playbook-fluentd.yml

# Step 5: Show results
step "Step 6/6: Deployment complete!"
log "Getting IPs..."

cd "$TF_DIR"
CONSUL_SERVER=$(terraform output -json consul_servers_ips | jq -r '.[0]')
OPENSEARCH_IP=$(terraform output -json opensearch_ips | jq -r '.[0]')

log "Consul UI: http://$CONSUL_SERVER:8500/ui/"
log "OpenSearch: http://$OPENSEARCH_IP:9200"
log "OpenSearch Dashboard: http://$OPENSEARCH_IP:5601"

echo ""
log "Getting web servers IPs..."
terraform output web_servers_ips

echo ""
log "Verification:"
echo "  - Run healthcheck: cd $ANS_DIR && ./healthcheck.sh $CONSUL_SERVER web"
echo "  - Check DNS: dig @$CONSUL_SERVER -p 8600 web.service.consul"
echo "  - Access web: curl http://\$(dig @$CONSUL_SERVER -p 8600 web.service.consul +short)"


