#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TF_DIR="$SCRIPT_DIR/../terraform"

cd "$TF_DIR"

CONSUL_SERVERS=($(terraform output -json consul_servers_ips | jq -r '.[]'))
CONSUL_SERVER_PRIVATES=($(terraform output -json consul_servers_private_ips | jq -r '.[]'))
CONSUL_CLIENT=$(terraform output -raw consul_client_ip)
CONSUL_CLIENT_PRIVATE=$(terraform output -raw consul_client_private_ip)
WEB_PUBLICS=($(terraform output -json web_servers_ips | jq -r '.[]'))
WEB_PRIVATES=($(terraform output -json web_servers_private_ips | jq -r '.[]'))
OPENSEARCH_PUBLICS=($(terraform output -json opensearch_ips | jq -r '.[]'))
OPENSEARCH_PRIVATES=($(terraform output -json opensearch_private_ips | jq -r '.[]'))

cat > "$SCRIPT_DIR/inventory.yml" << INVENTORY
all:
  children:
    consul_servers:
      hosts:
        consul-server-1:
          ansible_host: ${CONSUL_SERVERS[0]}
          consul_node_name: consul-server-1
        consul-server-2:
          ansible_host: ${CONSUL_SERVERS[1]}
          consul_node_name: consul-server-2
        consul-server-3:
          ansible_host: ${CONSUL_SERVERS[2]}
          consul_node_name: consul-server-3
      vars:
        consul_mode: server
        consul_bootstrap_expect: 3

    consul_clients:
      hosts:
        consul-client-1:
          ansible_host: ${CONSUL_CLIENT}
          consul_node_name: consul-client-1
      vars:
        consul_mode: client

    web_servers:
      hosts:
        web-1:
          ansible_host: ${WEB_PUBLICS[0]}
          ansible_host_private: ${WEB_PRIVATES[0]}
        web-2:
          ansible_host: ${WEB_PUBLICS[1]}
          ansible_host_private: ${WEB_PRIVATES[1]}
        web-3:
          ansible_host: ${WEB_PUBLICS[2]}
          ansible_host_private: ${WEB_PRIVATES[2]}

    opensearch_servers:
      hosts:
        opensearch-1:
          ansible_host: ${OPENSEARCH_PUBLICS[0]}
          ansible_host_private: ${OPENSEARCH_PRIVATES[0]}

  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: /home/sedunovsv/.ssh/id_ed25519
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    consul_version: 1.19.0
    consul_bind_ip: "{{ ansible_default_ipv4.address }}"
    consul_datacenter: dc1
    consul_domain: consul
    consul_log_level: INFO
INVENTORY

echo "Inventory updated!"
