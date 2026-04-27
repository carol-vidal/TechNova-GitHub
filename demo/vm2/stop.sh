#!/usr/bin/env bash
# Para e remove todos os containers da stack TechNova.
# Os volumes de dados são preservados por omissão.
# Para apagar tudo: docker compose -f docker-compose.yml down --volumes
# Uso: ./stop.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "==> Parando TechNova..."
docker compose -f docker-compose.yml down --remove-orphans
echo "==> Parado. (volumes preservados — use --volumes para apagar dados)"
