#!/usr/bin/env bash
set -euo pipefail

KEY_PUB="/home/deploy/.ssh/id_ed25519.pub"
USER="deploy"
HOSTS=("10.0.0.10" "10.0.0.20" "10.0.0.40")

if [ ! -f "${KEY_PUB}" ]; then
  echo "[ERROR] Public key not found: ${KEY_PUB}"
  exit 1
fi

for host in "${HOSTS[@]}"; do
  echo "[INFO] Copying key to ${USER}@${host}"
  ssh-copy-id -i "${KEY_PUB}" -o StrictHostKeyChecking=no "${USER}@${host}"
done

echo "[OK] SSH key distribution complete"
