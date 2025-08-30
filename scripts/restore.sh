#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR=${1:-}
if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
  echo "用法: $0 backups/20240101_120000" >&2
  exit 1
fi

# 停止 Ghost 以避免写入冲突
docker compose stop ghost || true

# 确保数据库服务启动
docker compose up -d db

# 等待数据库就绪（最长 60 秒）
echo "等待数据库就绪..."
for i in {1..60}; do
  if docker compose exec -T db sh -lc 'mysqladmin ping -h 127.0.0.1 --silent' >/dev/null 2>&1; then
    echo "数据库已就绪。"
    break
  fi
  sleep 1
  if [[ $i -eq 60 ]]; then
    echo "数据库未就绪，放弃恢复。" >&2
    exit 1
  fi
done

# 恢复数据库
if [[ -f "$BACKUP_DIR/db.sql" ]]; then
  echo "Restoring DB from $BACKUP_DIR/db.sql"
  # 若有 root 密码，优先使用 root，并确保数据库存在
  if docker compose exec -T db sh -lc '[ -n "$MYSQL_ROOT_PASSWORD" ]'; then
    docker compose exec -T db sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`"'
    docker compose exec -T db sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' < "$BACKUP_DIR/db.sql"
  else
    docker compose exec -T db sh -lc 'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' < "$BACKUP_DIR/db.sql"
  fi
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
