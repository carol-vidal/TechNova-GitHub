#!/usr/bin/env bash
# Valida UFW e fail2ban nas 4 VMs TechNova via SSH (apenas leitura, sem alterações).
# Concebido para correr no VM3 (srv-auto, 10.0.0.30) — dentro da rede Azure.
#
# Como usar:
#   1. Ligar ao VM3 via Azure Bastion ou IP público
#   2. Copiar este script para o VM3:
#        scp demo/security/test.sh deploy@<VM3>:~/test-security.sh
#   3. Correr:
#        bash ~/test-security.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# ── Configuração SSH ──────────────────────────────────
SSH_KEY="${SSH_KEY:-/home/deploy/.ssh/id_ed25519}"
SSH_USER="${SSH_USER:-deploy}"
SSH_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes -i "$SSH_KEY")

VM_LABELS=("srv-infra (VM1)" "srv-apps  (VM2)" "srv-auto  (VM3)" "srv-monit (VM4)")
VM_HOSTS=("10.0.0.10"        "10.0.0.20"        "10.0.0.30"        "10.0.0.40")

PASS=0; FAIL=0; WARN=0

ok()   { echo "  SUCESSO: $1"; PASS=$((PASS+1)); }
fail() { echo "  FALHA:   $1"; FAIL=$((FAIL+1)); }
warn() { echo "  AVISO:   $1"; WARN=$((WARN+1)); }

# IP do host actual — usado para detectar quando o VM3 testa a si próprio.
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")

# Script de verificação remota (apenas leitura).
REMOTE_CHECKS=$(cat << 'REMOTE'
ufw_installed=$(command -v ufw             &>/dev/null && echo yes || echo no)
f2b_installed=$(command -v fail2ban-client &>/dev/null && echo yes || echo no)
ufw_active=$(systemctl  is-active  ufw        2>/dev/null || true)
ufw_enabled=$(systemctl is-enabled ufw        2>/dev/null || true)
f2b_active=$(systemctl  is-active  fail2ban   2>/dev/null || true)
f2b_enabled=$(systemctl is-enabled fail2ban   2>/dev/null || true)
f2b_jaillocal=$(test -f /etc/fail2ban/jail.local && echo yes || echo no)
f2b_jailconf=$(test  -f /etc/fail2ban/jail.conf  && echo yes || echo no)
printf "ufw_installed=%s\n" "$ufw_installed"
printf "ufw_active=%s\n"    "$ufw_active"
printf "ufw_enabled=%s\n"   "$ufw_enabled"
printf "f2b_installed=%s\n" "$f2b_installed"
printf "f2b_active=%s\n"    "$f2b_active"
printf "f2b_enabled=%s\n"   "$f2b_enabled"
printf "f2b_jaillocal=%s\n" "$f2b_jaillocal"
printf "f2b_jailconf=%s\n"  "$f2b_jailconf"
REMOTE
)

echo ""
echo "--- TECHNOVA SEGURANÇA: RELATÓRIO DE VALIDAÇÃO ---"
echo "    UFW + fail2ban — verificação remota das VMs"
echo "--------------------------------------------------"
echo "  Utilizador SSH : $SSH_USER"
echo "  Chave SSH      : $SSH_KEY"
echo "  Host actual    : ${LOCAL_IP:-desconhecido}"

# ── Validação por VM ──────────────────────────────────
for i in "${!VM_LABELS[@]}"; do
  label="${VM_LABELS[$i]}"
  host="${VM_HOSTS[$i]}"

  echo ""
  echo "[$label — $host]"

  # Se for o próprio host (VM3 a testar-se a si próprio), correr localmente.
  if [ "$host" = "$LOCAL_IP" ]; then
    ok "Host local — verificações sem SSH"
    RESULT=$(bash <<< "$REMOTE_CHECKS" 2>/dev/null) \
      || { fail "Erro ao executar verificações locais"; continue; }
  else
    # Testar conectividade SSH antes de avançar.
    if ! ssh "${SSH_OPTS[@]}" "$SSH_USER@$host" true 2>/dev/null; then
      fail "Sem conectividade SSH com $host — verificações ignoradas"
      continue
    fi
    ok "Conectividade SSH estabelecida ($SSH_USER@$host)"

    # Recolher estado numa única ligação SSH.
    RESULT=$(ssh "${SSH_OPTS[@]}" "$SSH_USER@$host" bash <<< "$REMOTE_CHECKS" 2>/dev/null) \
      || { fail "Erro ao executar verificações remotas em $host"; continue; }
  fi

  # Extrai valor de uma linha "chave=valor" do output.
  get() { echo "$RESULT" | grep "^$1=" | cut -d= -f2; }

  # ── UFW ──────────────────────────────────────────────
  echo "  · UFW"

  if [ "$(get ufw_installed)" = "yes" ]; then
    ok "UFW instalado"
  else
    fail "UFW não instalado em $host"
  fi

  ufw_active=$(get ufw_active)
  if [ "$ufw_active" = "active" ]; then
    ok "Serviço UFW activo (systemd: active)"
  else
    fail "Serviço UFW inactivo (systemd: ${ufw_active:-unknown})"
  fi

  ufw_enabled=$(get ufw_enabled)
  if [ "$ufw_enabled" = "enabled" ]; then
    ok "UFW activado no arranque (systemd: enabled)"
  else
    fail "UFW não activado no arranque (systemd: ${ufw_enabled:-unknown})"
  fi

  # ── fail2ban ─────────────────────────────────────────
  echo "  · fail2ban"

  if [ "$(get f2b_installed)" = "yes" ]; then
    ok "fail2ban instalado"
  else
    fail "fail2ban não instalado em $host"
  fi

  f2b_active=$(get f2b_active)
  if [ "$f2b_active" = "active" ]; then
    ok "Serviço fail2ban activo (systemd: active)"
  else
    fail "Serviço fail2ban inactivo (systemd: ${f2b_active:-unknown})"
  fi

  f2b_enabled=$(get f2b_enabled)
  if [ "$f2b_enabled" = "enabled" ]; then
    ok "fail2ban activado no arranque (systemd: enabled)"
  else
    fail "fail2ban não activado no arranque (systemd: ${f2b_enabled:-unknown})"
  fi

  if [ "$(get f2b_jaillocal)" = "yes" ]; then
    ok "Configuração fail2ban presente (/etc/fail2ban/jail.local)"
  elif [ "$(get f2b_jailconf)" = "yes" ]; then
    warn "Apenas jail.conf encontrado em $host — recomendado criar jail.local"
  else
    fail "Nenhum ficheiro de configuração fail2ban em /etc/fail2ban/ ($host)"
  fi

done

# ── Sumário ───────────────────────────────────────────
echo ""
echo "--------------------------------------------------"
printf "  PASS: %-3s  FAIL: %-3s  AVISO: %-3s\n" "$PASS" "$FAIL" "$WARN"
echo "--------------------------------------------------"
echo "  Relatório gerado em: $(date)"
echo ""

exit "$FAIL"
