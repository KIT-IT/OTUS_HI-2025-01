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

ROOT_DIR="/home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_16"
TF_DIR="$ROOT_DIR/terraform"
ANS_DIR="$ROOT_DIR/ansible"

# Check prerequisites
log "Checking prerequisites..."
for bin in terraform ansible ansible-playbook yc; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    err "$bin is not installed"
    exit 1
  fi
done

# Check if YC vars are exported
if [ -z "${YC_TOKEN:-}" ] || [ -z "${YC_CLOUD_ID:-}" ] || [ -z "${YC_FOLDER_ID:-}" ]; then
  warn "YC environment variables not set. Please run: source start.sh"
  exit 1
fi

# Step 1: Terraform init and apply
step "Step 1/4: Deploying infrastructure with Terraform..."
cd "$TF_DIR"
log "Running: terraform init"
terraform init -input=false

log "Running: terraform apply"
terraform apply -auto-approve -input=false

# Step 2: Wait for instances to be ready
step "Step 2/4: Waiting for instances to be ready (60s)..."
log "Waiting for cloud-init to complete..."
sleep 60

# Step 3: Run Ansible playbooks
step "Step 3/4: Running Ansible playbooks..."

log "Testing connectivity..."
cd "$ANS_DIR"
ansible all -m ping

log "Deploying Kafka (2 brokers on single node)..."
ansible-playbook playbooks/site.yml --limit kafka

log "Deploying APP (nginx + Fluent Bit)..."
ansible-playbook playbooks/site.yml --limit app

log "Deploying ELK stack (OpenSearch + Logstash + Dashboards)..."
ansible-playbook playbooks/site.yml --limit elk

# Step 4: Show results
step "Step 4/4: Deployment complete!"
log "Getting IPs..."

cd "$TF_DIR"
KAFKA_IP=$(terraform output -raw kafka_external_ip)
ELK_IP=$(terraform output -raw elk_external_ip)
APP_IP=$(terraform output -raw app_external_ip)

echo ""
log "═══════════════════════════════════════════════════════════════"
log "Deployment Summary:"
log "═══════════════════════════════════════════════════════════════"
echo ""
log "Kafka Node:"
echo "  - IP: $KAFKA_IP"
echo "  - Broker 1: $KAFKA_IP:9092"
echo "  - Broker 2: $KAFKA_IP:9093"
echo "  - Topics: nginx, wordpress (2 partitions, RF=2)"
echo ""
log "ELK Node:"
echo "  - IP: $ELK_IP"
echo "  - OpenSearch: http://$ELK_IP:9200"
echo "  - Dashboards: http://$ELK_IP:5601"
echo "  - Login: admin / Admin@OpenSearch2025!"
echo ""
log "APP Node:"
echo "  - IP: $APP_IP"
echo "  - Nginx: http://$APP_IP"
echo "  - Fluent Bit: collecting nginx and wordpress logs"
echo ""
log "═══════════════════════════════════════════════════════════════"
echo ""
log "Verification commands:"
echo ""
echo "  # Check Kafka topics:"
echo "  ssh -i ~/.ssh/id_ed25519 ubuntu@$KAFKA_IP 'sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 kafka-topics --bootstrap-server localhost:9092,localhost:9093 --list'"
echo ""
echo "  # Check Kafka topic details:"
echo "  ssh -i ~/.ssh/id_ed25519 ubuntu@$KAFKA_IP 'sudo docker run --rm --network host confluentinc/cp-kafka:7.6.1 kafka-topics --bootstrap-server localhost:9092,localhost:9093 --describe --topic nginx'"
echo ""
echo "  # Check Fluent Bit status:"
echo "  ssh -i ~/.ssh/id_ed25519 ubuntu@$APP_IP 'sudo systemctl status fluent-bit'"
echo ""
echo "  # Check OpenSearch indices:"
echo "  curl -u admin:Admin@OpenSearch2025! http://$ELK_IP:9200/_cat/indices?v"
echo ""
echo "  # Access Dashboards:"
echo "  Open browser: http://$ELK_IP:5601"
echo ""
log "═══════════════════════════════════════════════════════════════"
