#!/usr/bin/env bash
set -eu

echo "[INFO] ===== VM1 - Installing Bind9 Exporter (port 9153) ====="

# O prometheus-bind-exporter le as estatisticas do Bind9
# Bind9 expoe stats em http://127.0.0.1:8053 (statistics-channel)
# O exporter converte para formato Prometheus na porta 9153

# Instalar o exporter
BIND_EXPORTER_VERSION="0.7.0"
cd /tmp

echo "[INFO] Downloading bind_exporter v${BIND_EXPORTER_VERSION}..."
curl -fsSL -o bind_exporter.tar.gz \
  https://github.com/prometheus-community/bind_exporter/releases/download/v${BIND_EXPORTER_VERSION}/bind_exporter-${BIND_EXPORTER_VERSION}.linux-amd64.tar.gz

tar -xzf bind_exporter.tar.gz

sudo install -m 0755 bind_exporter-${BIND_EXPORTER_VERSION}.linux-amd64/bind_exporter /usr/local/bin/bind_exporter
sudo useradd --no-create-home --shell /usr/sbin/nologin bind_exporter 2>/dev/null || true

# Activar statistics-channel no Bind9
# Necessario para o exporter conseguir ler as metricas
NAMED_CONF="/etc/bind/named.conf.options"

if ! grep -q "statistics-channels" "${NAMED_CONF}" 2>/dev/null; then
  echo "[INFO] Adding statistics-channels to Bind9 config..."
  sudo tee -a "${NAMED_CONF}" <<'EOF'

statistics-channels {
  inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
};
EOF
  sudo named-checkconf && echo "[OK] Bind9 config valid"
  sudo systemctl restart bind9 || sudo systemctl restart named
  sleep 3
else
  echo "[SKIP] statistics-channels already configured"
fi

# Verificar que o statistics channel esta a responder
curl -s http://127.0.0.1:8053/ | head -3 && echo "[OK] Bind9 stats channel up" || echo "[WARN] Bind9 stats not responding yet"

# Service
sudo tee /etc/systemd/system/bind_exporter.service <<'EOF'
[Unit]
Description=Bind9 Exporter
Wants=network-online.target
After=network-online.target bind9.service

[Service]
User=bind_exporter
ExecStart=/usr/local/bin/bind_exporter \
  --web.listen-address=:9153 \
  --bind.stats-url=http://127.0.0.1:8053/
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now bind_exporter

sleep 3

# UFW
sudo ufw allow from 10.0.0.40 to any port 9153 2>/dev/null || true

# Validar
echo ""
echo "--- Validation ---"
systemctl is-active --quiet bind_exporter && echo "[OK] bind_exporter active" || echo "[FAIL] bind_exporter inactive"
curl -s http://127.0.0.1:9153/metrics | head -5
ss -tulpn | grep -E ':9153|:8053'

echo "[INFO] ===== Done ====="
