#!/usr/bin/env bash
# Valida os serviços da VM1 (srv-infra) em modo demo local (Docker).
# Pré-requisito: ./start-vm1.sh já concluído com sucesso.
# Uso: bash test-vm1.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

PASS=0; FAIL=0

ok()   { echo "  SUCESSO: $1"; PASS=$((PASS+1)); }
fail() { echo "  FALHA:   $1"; FAIL=$((FAIL+1)); }

echo ""
echo "--- TECHNOVA INFRAESTRUTURA: RELATÓRIO DE VALIDAÇÃO ---"
echo "--------------------------------------------------------"

# ── DNS (Bind9) ───────────────────────────────────────────
echo ""
echo "[DNS] Bind9 — Resolução de Nomes Internos"

# Resolução direta: os 4 hostnames da rede technova.local.
declare -A DNS_MAP=(
  ["srv-infra.technova.local"]="10.0.0.10"
  ["srv-apps.technova.local"]="10.0.0.20"
  ["srv-auto.technova.local"]="10.0.0.30"
  ["srv-monit.technova.local"]="10.0.0.40"
)
for host in "${!DNS_MAP[@]}"; do
  expected="${DNS_MAP[$host]}"
  got=$(docker exec vm1-dns host "$host" 127.0.0.1 2>/dev/null \
        | awk '/has address/ {print $4}' | head -1)
  if [ "$got" = "$expected" ]; then
    ok "Host '$host' resolvido para o IP $got"
  else
    fail "Host '$host' → '$got' (esperado $expected)"
  fi
done

# Resolução inversa (PTR): IP → hostname.
declare -A PTR_MAP=(
  ["10.0.0.10"]="srv-infra.technova.local."
  ["10.0.0.20"]="srv-apps.technova.local."
  ["10.0.0.30"]="srv-auto.technova.local."
  ["10.0.0.40"]="srv-monit.technova.local."
)
for ip in "${!PTR_MAP[@]}"; do
  expected="${PTR_MAP[$ip]}"
  got=$(docker exec vm1-dns dig @127.0.0.1 +short -x "$ip" 2>/dev/null | head -1)
  if [ "$got" = "$expected" ]; then
    ok "Resolução inversa $ip → $got"
  else
    fail "Resolução inversa $ip → '$got' (esperado $expected)"
  fi
done

# Forward DNS: nomes externos continuam a resolver (via forwarders).
EXT=$(docker exec vm1-dns dig @127.0.0.1 +short google.com 2>/dev/null | head -1)
if [ -n "$EXT" ]; then
  ok "Forward DNS externo funcional (google.com → $EXT)"
else
  fail "Forward DNS externo não resolve — verificar forwarders"
fi

# ── NTP (Chrony) ──────────────────────────────────────────
echo ""
echo "[NTP] Chrony — Sincronização de Tempo"

TRACKING=$(docker exec vm1-ntp chronyc tracking 2>/dev/null || echo "")

NTP_REF=$(echo "$TRACKING" | grep "Reference ID" | awk '{print $4, $5}')
if [ -n "$NTP_REF" ]; then
  ok "Sincronizado com servidor externo ($NTP_REF)"
else
  fail "O sistema não possui uma fonte de tempo ativa"
fi

# Verifica offset de tempo (deve ser inferior a 1 segundo no demo).
OFFSET=$(echo "$TRACKING" | grep "System time" | grep -oP '[\d.]+(?= seconds)' | head -1)
if [ -n "$OFFSET" ]; then
  ACEITAVEL=$(awk -v o="$OFFSET" 'BEGIN { print (o+0 < 1.0) ? "yes" : "no" }')
  if [ "$ACEITAVEL" = "yes" ]; then
    ok "Offset de tempo aceitável (${OFFSET}s < 1.0s)"
  else
    fail "Offset de tempo elevado: ${OFFSET}s (aceitável < 1.0s em prod)"
  fi
fi

# Verifica fontes NTP ativas (*).
SOURCES=$(docker exec vm1-ntp chronyc sources 2>/dev/null || echo "")
GOOD=$(echo "$SOURCES" | grep -c '^\^\*' || true)
if [ "$GOOD" -ge 1 ]; then
  ok "Pelo menos uma fonte NTP selecionada ($GOOD fonte(s) ativa(s))"
else
  fail "Nenhuma fonte NTP selecionada — Chrony não está sincronizado"
fi

# ── NFS (Server) ──────────────────────────────────────────
echo ""
echo "[NFS] NFS Server — Partilha de Ficheiros"

# Lista exportações ativas.
NFS_EXPORTS=$(docker exec vm1-nfs showmount -e localhost 2>/dev/null \
              | tail -n +2 | awk '{print $1}' | xargs 2>/dev/null || echo "")
if [ -n "$NFS_EXPORTS" ]; then
  ok "Pastas exportadas via rede: [$NFS_EXPORTS]"
else
  fail "Nenhum diretório está a ser exportado via NFS"
fi

# Verifica que /exports existe e é acessível.
if docker exec vm1-nfs test -d /exports 2>/dev/null; then
  ok "Diretório /exports existe e está acessível"
else
  fail "Diretório /exports não encontrado no servidor"
fi

# Teste de escrita e leitura no volume partilhado (simula acesso da VM2).
TFILE="/exports/.vm1-test-$$"
if docker exec vm1-nfs sh -c \
     "echo 'TechNova NFS OK' > $TFILE && cat $TFILE" 2>/dev/null | grep -q 'TechNova'; then
  ok "Escrita e leitura em /exports funcionais (simulação mount VM2)"
  docker exec vm1-nfs rm -f "$TFILE" 2>/dev/null || true
else
  fail "Não foi possível escrever em /exports"
fi

# ── Sumário ───────────────────────────────────────────────
echo ""
echo "--------------------------------------------------------"
printf "  PASS: %-3s  FAIL: %-3s\n" "$PASS" "$FAIL"
echo "--------------------------------------------------------"
echo "  Relatório gerado em: $(date)"
echo ""

exit "$FAIL"
