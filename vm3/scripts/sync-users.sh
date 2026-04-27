#!/bin/bash
set -euo pipefail
SOURCE_HOST=$1
cd /opt/technova-automation
echo "[$(date)] Sync disparado por ${SOURCE_HOST}" >> logs/sync-users.log
sudo -u deploy ansible-playbook playbooks/sync-users.yml \
    -e "source_host=${SOURCE_HOST}" >> logs/sync-users.log 2>&1
