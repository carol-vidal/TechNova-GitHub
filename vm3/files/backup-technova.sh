#!/bin/bash
set -euo pipefail
BACKUP_DIR="/mnt/backups"
DATE=$(date +%F)
LOG="/var/log/technova-backup.log"

echo "[$(date)] === Iniciando backup ===" >> $LOG

source /opt/technova-app/.env

docker exec technova-mysql \
  sh -c "exec mysqldump -u\$MYSQL_USER -p\$MYSQL_PASSWORD \$MYSQL_DATABASE" \
  | gzip > $BACKUP_DIR/mysql-$DATE.sql.gz
echo "[$(date)] MySQL backup OK" >> $LOG

tar czf $BACKUP_DIR/app-$DATE.tar.gz \
  --exclude=/opt/technova-app/logs \
  --exclude=/opt/technova-app/backups \
  --exclude=/opt/technova-app/node_modules \
  --exclude=/opt/technova-app/.git \
  /opt/technova-app
echo "[$(date)] App backup OK" >> $LOG

find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
echo "[$(date)] Limpeza OK" >> $LOG

ls -lh $BACKUP_DIR >> $LOG
