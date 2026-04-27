#!/usr/bin/env bash
# Inicia a stack TechNova completa em modo demo local.
# Requer: Docker Desktop em execução.
# Uso: ./start.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "==> Iniciando TechNova (demo local)..."

docker compose -f docker-compose.yml up -d --build --quiet-pull

echo "==> Aguardando serviços..."

wait_ready() {
  local url=$1 name=$2
  for i in $(seq 1 40); do
    curl -sf --max-time 3 "$url" &>/dev/null && echo "    OK  $name" && return 0
    sleep 4
  done
  echo "    TIMEOUT  $name" && return 1
}

wait_ready "http://localhost/api/health"      "App (Nginx + Node.js + MySQL)"
wait_ready "http://localhost:9090/-/ready"    "Prometheus"
wait_ready "http://localhost:9093/-/ready"    "Alertmanager"
wait_ready "http://localhost:3100/ready"      "Loki"
wait_ready "http://localhost:3000/api/health" "Grafana"
wait_ready "http://localhost:5001/"           "Webhook Listener"

echo ""
echo "==> Stack pronta!"
echo ""
echo "    App TechNova   →  http://localhost"
echo "    Grafana        →  http://localhost:3000  (admin / technova2024)"
echo "    Prometheus     →  http://localhost:9090"
echo "    Alertmanager   →  http://localhost:9093"
echo "    Webhook        →  http://localhost:5001"
echo ""
echo "    Execute: ./test.sh"
