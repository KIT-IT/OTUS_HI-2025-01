#!/bin/bash

set -euo pipefail

ROOT_DIR="/home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_12"
TF_DIR="$ROOT_DIR/pg_ha/terraform"
ANS_DIR="$ROOT_DIR/pg_ha/ansible"

HAPROXY_IP_ARG="${1:-}"

echo "Getting Terraform outputs..."
cd "$TF_DIR"
TERRAFORM_OUTPUT=$(terraform output -json)

# Patroni nodes: query YC by label role=patroni within the subnet
echo "Discovering Patroni nodes via YC CLI..."
PATRONI_IPS=$(yc compute instance list --format json | jq -r '.[] | select(.labels.role=="patroni") | .network_interfaces[0].primary_v4_address.one_to_one_nat.address')

if [ -z "$PATRONI_IPS" ]; then
  echo "No Patroni nodes found via labels. Falling back to instance group introspection (terraform state)."
  # As a fallback, use subnet CIDR to filter NAT instances; user may need to adjust manually
  PATRONI_IPS=$(yc compute instance list --format json | jq -r '.[].network_interfaces[0].primary_v4_address.address')
fi

HAPROXY_IP=${HAPROXY_IP_ARG:-$(terraform output -raw haproxy_public_ip)}
SALEOR_PUBLIC_IP=$(terraform output -raw saleor_public_ip)
STOREFRONT_PUBLIC_IP=$(terraform output -raw storefront_public_ip)

echo "Writing inventory to $ANS_DIR/inventories/prod/hosts.ini"
{
  echo "[haproxy]"
  echo "$HAPROXY_IP ansible_user=ubuntu"
  echo
  echo "[patroni]"
  i=1
  for ip in $PATRONI_IPS; do
    echo "patroni-$i ansible_host=$ip"
    i=$((i+1))
  done
  echo
  echo "[saleor]"
  echo "$SALEOR_PUBLIC_IP ansible_user=ubuntu"
  echo
  echo "[storefront]"
  echo "$STOREFRONT_PUBLIC_IP ansible_user=ubuntu"
  echo
  echo "[all:vars]"
  echo "ansible_user=ubuntu"
  echo "ansible_ssh_private_key_file=/home/sedunovsv/.ssh/id_ed25519"
  echo "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
} > "$ANS_DIR/inventories/prod/hosts.ini"

echo "Inventory updated successfully!"
echo "HAProxy: $HAPROXY_IP"
echo "Patroni nodes:"
nl -ba <<< "$PATRONI_IPS" | sed 's/^/  /'
