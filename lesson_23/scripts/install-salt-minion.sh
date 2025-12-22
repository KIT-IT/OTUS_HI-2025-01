#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
step()   { echo -e "${BLUE}[STEP]${NC} $*"; }
err()    { echo -e "${RED}[ERR ]${NC} $*"; }

# Check if SALT_MASTER_IP is provided
if [ -z "${SALT_MASTER_IP:-}" ]; then
  err "SALT_MASTER_IP environment variable is not set"
  err "Usage: SALT_MASTER_IP=<ip> ./install-salt-minion.sh"
  exit 1
fi

step "Installing Salt Minion..."

# Update system
log "Updating system packages..."
sudo apt-get update

# Install Salt Minion
log "Installing Salt Minion..."
curl -L https://bootstrap.saltproject.io | sudo sh -s -- -A "$SALT_MASTER_IP"

# Configure Salt Minion
step "Configuring Salt Minion..."

# Backup original config
sudo cp /etc/salt/minion /etc/salt/minion.bak

# Configure Salt Minion
sudo tee /etc/salt/minion > /dev/null <<EOF
# Salt Minion Configuration
master: $SALT_MASTER_IP
master_port: 4506

# Minion ID (will be hostname by default)
id: \$(hostname)

# Logging
log_level: info
log_file: /var/log/salt/minion
EOF

# Start and enable Salt Minion
log "Starting Salt Minion service..."
sudo systemctl restart salt-minion
sudo systemctl enable salt-minion

# Check status
log "Checking Salt Minion status..."
sudo systemctl status salt-minion --no-pager | head -n 10

log "Salt Minion installed and configured successfully!"
log "Minion will connect to Salt Master at $SALT_MASTER_IP"
log "On Salt Master, accept the key with: sudo salt-key -A"

