#!/usr/bin/env bash
set -euo pipefail

# Backup directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups/${TIMESTAMP}"
mkdir -p "${BACKUP_DIR}"

# Database dump (use env from running db container)
docker compose exec -T db sh -lc 'mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' > "${BACKUP_DIR}/db.sql"

# Content archive (images, themes, routes.yaml, etc.)
tar -czf "${BACKUP_DIR}/content.tar.gz" -C data/ghost .

# Manifest
{
  echo "timestamp=${TIMESTAMP}"
  echo "ghost_url=${GHOST_URL:-http://localhost:2368}"
} > "${BACKUP_DIR}/manifest.env"

echo "Backup created at ${BACKUP_DIR}"
