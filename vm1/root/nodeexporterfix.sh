#!/usr/bin/env bash
set -eu

echo "[INFO] ===== VM1 - Installing node_exporter ====="

NODE_VERSION="1.8.1"
cd /tmp

# Download
echo "[INFO] Downloading node_exporter v${NODE_VERSION}..."
curl -fsSL -o ne.tar.gz \
  https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/node_exporter-${NODE_VERSION}.linux-amd64.tar.gz

tar -xzf ne.tar.gz

# Install
sudo install -m 0755 node_exporter-${NODE_VERSION}.linux-amd64/node_exporter /usr/local/bin/node_exporter
sudo useradd --no-create-home --shell /usr/sbin/nologin node_exporter 2>/dev/null || true

# Service
sudo tee /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

sleep 3

# UFW - permitir VM4 aceder a 9100
sudo ufw allow from 10.0.0.40 to any port 9100 2>/dev/null || true

# Validar
echo ""
echo "--- Validation ---"
systemctl is-active --quiet node_exporter && echo "[OK] node_exporter active" || echo "[FAIL] node_exporter inactive"
curl -s http://127.0.0.1:9100/metrics | head -3
ss -tulpn | grep :9100

echo "[INFO] ===== Done ====="
