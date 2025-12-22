#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
step()   { echo -e "${BLUE}[STEP]${NC} $*"; }

step "Installing Salt Master..."

# Update system
log "Updating system packages..."
sudo apt-get update

# Install Salt Master
log "Installing Salt Master..."
curl -L https://bootstrap.saltproject.io | sudo sh -s -- -M -N

# Configure Salt Master
step "Configuring Salt Master..."

# Create salt directories
sudo mkdir -p /srv/salt
sudo mkdir -p /srv/pillar

# Backup original config
sudo cp /etc/salt/master /etc/salt/master.bak

# Configure Salt Master
sudo tee /etc/salt/master > /dev/null <<EOF
# Salt Master Configuration
interface: 0.0.0.0
publish_port: 4505
ret_port: 4506

# File roots
file_roots:
  base:
    - /srv/salt

# Pillar roots
pillar_roots:
  base:
    - /srv/pillar

# Auto accept minions (для тестирования, в продакшене лучше вручную)
auto_accept: True

# Logging
log_level: info
log_file: /var/log/salt/master
EOF

# Start and enable Salt Master
log "Starting Salt Master service..."
sudo systemctl restart salt-master
sudo systemctl enable salt-master

# Check status
log "Checking Salt Master status..."
sudo systemctl status salt-master --no-pager | head -n 10

log "Salt Master installed and configured successfully!"
log "Salt Master is listening on ports 4505 (publish) and 4506 (ret)"

