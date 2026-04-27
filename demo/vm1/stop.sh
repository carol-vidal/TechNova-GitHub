#!/usr/bin/env bash
# Para e remove os containers da VM1 (srv-infra).
# Uso: ./stop.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "==> A parar VM1 (srv-infra)..."
docker compose -f docker-compose.yml down
echo "==> VM1 parada."
