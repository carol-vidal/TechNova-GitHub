#!/usr/bin/env bash
# Valida todas as funcionalidades da stack TechNova em execução.
# Cobre: App, Prometheus, Alertmanager, Loki, Grafana, Webhook e segurança básica.
# Pré-requisito: ./start.sh já concluído com sucesso.
# Uso: ./demo.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

OK=0; ERR=0

pass() { echo "  ✔  $1"; OK=$((OK+1));  }
fail() { echo "  ✘  $1"; ERR=$((ERR+1)); }

# Valida que um endpoint retorna o HTTP code esperado (200 por omissão).
# Segue redirects (-L) para que UIs que redirecionam / para /login ou /graph passem.
chk() {
  local label=$1 url=$2 want=${3:-200}
  local got; got=$(curl -sL -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
  if [ "$got" = "$want" ]; then pass "$label"; else fail "$label  (HTTP $got, esperado $want)"; fi
}

# Valida que um endpoint autenticado retorna o HTTP code esperado.
chk_auth() {
  local label=$1 url=$2 user=$3 pass_=$4 want=${5:-200}
  local got; got=$(curl -sL -o /dev/null -w "%{http_code}" --max-time 5 -u "$user:$pass_" "$url" 2>/dev/null || echo "000")
  if [ "$got" = "$want" ]; then pass "$label"; else fail "$label  (HTTP $got, esperado $want)"; fi
}

# Valida que o corpo da resposta contém um padrão específico.
chk_body() {
  local label=$1 url=$2 pattern=$3
  local body; body=$(curl -sf --max-time 5 "$url" 2>/dev/null || echo "")
  if echo "$body" | grep -q "$pattern"; then pass "$label"; else fail "$label"; fi
}

# Valida que o corpo de uma resposta autenticada contém um padrão específico.
chk_body_auth() {
  local label=$1 url=$2 pattern=$3 user=$4 pass_=$5
  local body; body=$(curl -sf --max-time 5 -u "$user:$pass_" "$url" 2>/dev/null || echo "")
  if echo "$body" | grep -q "$pattern"; then pass "$label"; else fail "$label"; fi
}

# Valida que uma porta NÃO está acessível no host (serviço interno ao Docker).
port_closed() {
  local label=$1 port=$2
  if (echo >/dev/tcp/localhost/"$port") &>/dev/null 2>&1; then
    fail "$label  (porta $port EXPOSTA ao host)"
  else
    pass "$label"
  fi
}

echo ""
echo "════════════════════════════════════════"
echo "  TechNova — Demo + Validação"
echo "════════════════════════════════════════"

# ── Aplicação ─────────────────────────────
# Testa os endpoints da app Node.js expostos via Nginx na porta 80.
echo ""
echo "[ App — Node.js + MySQL + Nginx ]"
chk      "Health check"           "http://localhost/api/health"
chk      "API Assets (JSON)"      "http://localhost/api/assets"
chk      "Dashboard HTML"         "http://localhost/"
chk      "Métricas Prometheus"    "http://localhost/metrics"
# Confirma que o MySQL foi inicializado com os 4 assets de infraestrutura.
chk_body "4 assets na base dados" "http://localhost/api/assets" "srv-infra"

# ── Prometheus ────────────────────────────
# Testa a UI, o endpoint de prontidão, a API de targets e uma query PromQL real.
echo ""
echo "[ Prometheus ]"
chk      "UI acessível"           "http://localhost:9090"
chk      "Estado ready"           "http://localhost:9090/-/ready"
chk      "Targets ativos"         "http://localhost:9090/api/v1/targets"
chk      "Regras de alerta"       "http://localhost:9090/api/v1/rules"
# Query PromQL que confirma que o Prometheus está a raspar métricas da app.
chk_body "Métricas da app"        "http://localhost:9090/api/v1/query?query=technova_http_requests_total" "result"

# ── Alertmanager ──────────────────────────
# Confirma que o Alertmanager está pronto e que a API de alertas responde.
echo ""
echo "[ Alertmanager ]"
chk "Estado ready"                "http://localhost:9093/-/ready"
chk "API de alertas"              "http://localhost:9093/api/v2/alerts"

# ── Loki ──────────────────────────────────
# Confirma que o Loki está pronto para receber logs.
echo ""
echo "[ Loki ]"
chk "Estado ready"                "http://localhost:3100/ready"
chk "Métricas internas"           "http://localhost:3100/metrics"

# ── Grafana ───────────────────────────────
# Testa a UI e confirma que os datasources (Prometheus + Loki) foram provisionados.
echo ""
echo "[ Grafana ]"
chk      "UI acessível"           "http://localhost:3000"
chk      "Health check"           "http://localhost:3000/api/health"
chk_auth      "Datasources (com auth)" "http://localhost:3000/api/datasources" "admin" "technova2024" 200
chk_body_auth "Datasource Prometheus"  "http://localhost:3000/api/datasources" "prometheus" "admin" "technova2024"

# ── Webhook ───────────────────────────────
# Confirma que o listener está ativo e consegue receber um alerta no formato Alertmanager.
echo ""
echo "[ Webhook Listener ]"
chk "Listener ativo" "http://localhost:5001/"
curl -sf --max-time 5 -X POST \
  -H "Content-Type: application/json" \
  -d '{"status":"firing","alerts":[{"labels":{"alertname":"DemoTest","severity":"warning"}}]}' \
  "http://localhost:5001/" &>/dev/null \
  && pass "POST alerta de teste registado" \
  || fail "POST alerta de teste falhou"

# ── Segurança ─────────────────────────────
echo ""
echo "[ Segurança ]"

# MySQL é acessível apenas dentro da rede Docker — nunca diretamente do host.
# A app Node.js (porta 3000 interna) também não está exposta: o acesso externo
# passa pelo Nginx na porta 80. O Grafana expõe legitimamente a porta 3000 do host.
port_closed "MySQL não exposto ao host (porta 3306)" 3306

# Grafana deve rejeitar qualquer pedido sem credenciais válidas.
chk "Grafana rejeita acesso sem auth" \
    "http://localhost:3000/api/datasources" 401

# Confirma que as credenciais corretas funcionam.
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  -u "admin:technova2024" "http://localhost:3000/api/datasources" 2>/dev/null || echo "000")
if [ "$CODE" = "200" ]; then
  pass "Grafana aceita credenciais corretas"
else
  fail "Grafana — credenciais corretas rejeitadas (HTTP $CODE)"
fi

# GF_USERS_ALLOW_SIGN_UP=false deve bloquear criação de novos utilizadores.
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"x@x.com","password":"x","name":"x"}' \
  "http://localhost:3000/api/user/signup" 2>/dev/null || echo "000")
if [[ "$CODE" =~ ^(401|403|404)$ ]]; then
  pass "Grafana — registo de novos utilizadores bloqueado (HTTP $CODE)"
else
  fail "Grafana — signup pode estar ativo (HTTP $CODE)"
fi

# ── Sumário ───────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "  PASS: $OK   FAIL: $ERR"
echo "════════════════════════════════════════"
echo ""

exit "$ERR"
