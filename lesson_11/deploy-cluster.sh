#!/bin/bash

# MySQL Cluster Deployment Script
# This script automates the entire deployment process

set -e

echo "=== MySQL Cluster Deployment Script ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install it first."
    exit 1
fi

# Check if ansible is installed
if ! command -v ansible &> /dev/null; then
    print_error "Ansible is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please install it first."
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_error "terraform.tfvars file not found. Please create it with your SSH public key."
    exit 1
fi

print_status "Prerequisites check passed!"
echo ""

# Step 1: Deploy infrastructure
print_status "Step 1: Deploying infrastructure with Terraform..."
echo ""

# Set up authentication
print_status "Setting up Yandex Cloud authentication..."
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)

# Initialize terraform
print_status "Initializing Terraform..."
terraform init

# Plan deployment
print_status "Planning deployment..."
terraform plan

# Ask for confirmation
echo ""
read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled by user."
    exit 0
fi

# Apply terraform
print_status "Applying Terraform configuration..."
terraform apply -auto-approve

print_status "Infrastructure deployed successfully!"
echo ""

# Step 2: Update Ansible inventory
print_status "Step 2: Updating Ansible inventory..."
./update-inventory.sh

print_status "Inventory updated successfully!"
echo ""

# Step 3: Wait for instances to be ready
print_status "Step 3: Waiting for instances to be ready..."
print_warning "Waiting 60 seconds for cloud-init to complete..."
sleep 60

# Step 4: Setup MySQL cluster
print_status "Step 4: Setting up MySQL cluster with Ansible..."
cd ansible

# Test connectivity
print_status "Testing connectivity to all nodes..."
ansible mysql_cluster -i inventory.ini -m ping

# Setup cluster
print_status "Configuring Percona XtraDB Cluster..."
ansible-playbook -i inventory.ini playbooks/setup-cluster.yml

print_status "MySQL cluster setup completed!"
echo ""

# Step 5: Test cluster functionality
print_status "Step 5: Testing cluster functionality..."

# Test failover
print_status "Running failover tests..."
ansible-playbook -i inventory.ini playbooks/test-failover.yml

print_status "Failover tests completed!"
echo ""

# Step 6: Display cluster information
print_status "Step 6: Cluster deployment summary..."
echo ""

cd ..

# Get cluster information
print_status "Getting cluster information..."
MYSQL_NODE_1_EXT=$(terraform output -raw mysql_node_1_external_ip)
MYSQL_NODE_2_EXT=$(terraform output -raw mysql_node_2_external_ip)
MYSQL_NODE_3_EXT=$(terraform output -raw mysql_node_3_external_ip)

echo "=== MySQL Cluster Information ==="
echo "Node 1: $MYSQL_NODE_1_EXT"
echo "Node 2: $MYSQL_NODE_2_EXT"
echo "Node 3: $MYSQL_NODE_3_EXT"
echo ""

print_status "Deployment completed successfully!"
echo ""

# Display next steps
echo "=== Next Steps ==="
echo "1. Connect to any node: ssh ubuntu@$MYSQL_NODE_1_EXT"
echo "2. Check cluster status: /usr/local/bin/cluster-status.sh"
echo "3. Connect to MySQL: mysql -u root"
echo "4. Test database: USE testdb; SELECT * FROM test_table;"
echo ""

print_status "MySQL Cluster is ready for use!"
