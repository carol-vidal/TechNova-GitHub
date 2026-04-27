#!/usr/bin/env bash
# Inicia os serviços da VM1 (srv-infra) em modo demo local.
# Requer: Docker Desktop em execução.
# Uso: ./start.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "==> Iniciando VM1 — srv-infra (demo local)..."
docker compose -f docker-compose.yml up -d --quiet-pull

echo "==> Aguardando serviços..."

wait_ready() {
  local name=$1 check=$2
  for i in $(seq 1 30); do
    eval "$check" &>/dev/null && echo "    OK  $name" && return 0
    sleep 3
  done
  echo "    TIMEOUT  $name" && return 1
}

wait_ready "DNS  (Bind9)"  "docker logs vm1-dns 2>&1 | grep -q 'all zones loaded'"
wait_ready "NTP  (Chrony)" "docker exec vm1-ntp chronyc tracking"
wait_ready "NFS  (Server)" "docker exec vm1-nfs rpcinfo -p localhost | grep -q 100003"

echo ""
echo "==> VM1 pronta!"
echo ""
echo "    DNS  →  127.0.0.1:5353  (zona technova.local)"
echo "    NTP  →  127.0.0.1:1123  (UDP)"
echo "    NFS  →  127.0.0.1:2049"
echo ""
echo "    Execute: ./test.sh"
