#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR=${1:-}
if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
  echo "用法: $0 backups/20240101_120000" >&2
  exit 1
fi

# 停止 Ghost 以避免写入冲突
docker compose stop ghost

# 恢复数据库
if [[ -f "$BACKUP_DIR/db.sql" ]]; then
  echo "Restoring DB from $BACKUP_DIR/db.sql"
  docker compose exec -T db sh -lc 'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' < "$BACKUP_DIR/db.sql"
else
  echo "警告: 未找到 $BACKUP_DIR/db.sql，跳过数据库恢复"
fi

# 恢复内容目录
if [[ -f "$BACKUP_DIR/content.tar.gz" ]]; then
  echo "Restoring Ghost content from $BACKUP_DIR/content.tar.gz"
  rm -rf data/ghost/*
  mkdir -p data/ghost
  tar -xzf "$BACKUP_DIR/content.tar.gz" -C data/ghost
else
  echo "警告: 未找到 $BACKUP_DIR/content.tar.gz，跳过内容恢复"
fi

# 重新启动 Ghost
docker compose up -d ghost

echo "恢复完成。"
