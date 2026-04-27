#!/bin/bash
# ============================================================
# DEMO NFS — TechNova TCC
# ============================================================

VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARELO='\033[1;33m'
NC='\033[0m' # sem cor

pause() {
  echo ""
  echo -e "${AMARELO}>>> Prima ENTER para continuar...${NC}"
  read
}

cd /opt/technova-automation

echo -e "${AZUL}=====================================================${NC}"
echo -e "${AZUL}  DEMO: NFS — Backups Centralizados na TechNova${NC}"
echo -e "${AZUL}=====================================================${NC}"
pause

# --- PASSO 1 ---
echo -e "${VERDE}[1/5] Confirmar que o NFS Server está activo na VM1${NC}"
ansible infra -m shell -a "sudo systemctl status nfs-kernel-server --no-pager | head -5"
pause

# --- PASSO 2 ---
echo -e "${VERDE}[2/5] Ver exportações activas na VM1${NC}"
ansible infra -m shell -a "sudo exportfs -v"
pause

# --- PASSO 3 ---
echo -e "${VERDE}[3/5] Confirmar mount NFS nas VMs clientes (VM2, VM3, VM4)${NC}"
ansible apps:automation:monitoring -m shell -a "mount | grep /mnt/backups"
pause

# --- PASSO 4 ---
echo -e "${VERDE}[4/5] Executar backup manual da VM2 para o NFS${NC}"
ansible apps -m shell -a "sudo /usr/local/bin/backup-technova.sh"
echo ""
echo "A aguardar 5 segundos..."
sleep 5
pause

# --- PASSO 5 ---
echo -e "${VERDE}[5/5] Confirmar ficheiros de backup na VM1 (partilha NFS)${NC}"
ansible infra -m shell -a "sudo ls -lah /srv/nfs/backups/"
echo ""
ansible apps -m shell -a "tail -10 /var/log/technova-backup.log"

echo ""
echo -e "${AZUL}=====================================================${NC}"
echo -e "${AZUL}  DEMO CONCLUÍDA ✅${NC}"
echo -e "${AZUL}  Backups centralizados no NFS — VM1 como servidor${NC}"
echo -e "${AZUL}  VM2 como cliente — backup MySQL + App automatizado${NC}"
echo -e "${AZUL}=====================================================${NC}"
