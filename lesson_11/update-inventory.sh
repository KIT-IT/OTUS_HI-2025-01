#!/bin/bash

# Script to update Ansible inventory with Terraform outputs
# This script extracts IP addresses from terraform output and updates inventory.ini

set -e

# Get Terraform outputs
echo "Getting Terraform outputs..."
TERRAFORM_OUTPUT=$(terraform output -json)

# Extract IP addresses
MYSQL_NODE_1_EXT=$(echo $TERRAFORM_OUTPUT | jq -r '.mysql_node_1_external_ip.value')
MYSQL_NODE_1_INT=$(echo $TERRAFORM_OUTPUT | jq -r '.mysql_node_1_internal_ip.value')
MYSQL_NODE_2_EXT=$(echo $TERRAFORM_OUTPUT | jq -r '.mysql_node_2_external_ip.value')
MYSQL_NODE_2_INT=$(echo $TERRAFORM_OUTPUT | jq -r '.mysql_node_2_internal_ip.value')
MYSQL_NODE_3_EXT=$(echo $TERRAFORM_OUTPUT | jq -r '.mysql_node_3_external_ip.value')
MYSQL_NODE_3_INT=$(echo $TERRAFORM_OUTPUT | jq -r '.mysql_node_3_internal_ip.value')

# Update inventory file
echo "Updating Ansible inventory..."
cat > ansible/inventory.ini << EOF
[mysql_cluster]
mysql-node-1 ansible_host=$MYSQL_NODE_1_EXT internal_ip=$MYSQL_NODE_1_INT node_id=1
mysql-node-2 ansible_host=$MYSQL_NODE_2_EXT internal_ip=$MYSQL_NODE_2_INT node_id=2
mysql-node-3 ansible_host=$MYSQL_NODE_3_EXT internal_ip=$MYSQL_NODE_3_INT node_id=3

[mysql_cluster:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=/home/sedunovsv/.ssh/id_ed25519
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
cluster_name=pxc-cluster
sst_user=sstuser
sst_password=sstpass
EOF

echo "Inventory updated successfully!"
echo "MySQL Cluster nodes:"
echo "  Node 1: $MYSQL_NODE_1_EXT (internal: $MYSQL_NODE_1_INT)"
echo "  Node 2: $MYSQL_NODE_2_EXT (internal: $MYSQL_NODE_2_INT)"
echo "  Node 3: $MYSQL_NODE_3_EXT (internal: $MYSQL_NODE_3_INT)"
