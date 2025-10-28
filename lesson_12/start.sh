#!/bin/bash

set -euo pipefail

ROOT_DIR="/home/sedunovsv/OTUS/OTUS_HI-2025-01/lesson_12"

echo "Export YC auth vars"
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)

echo "Run deploy-cluster.sh"
"$ROOT_DIR/deploy-cluster.sh"