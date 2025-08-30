#!/usr/bin/env bash
set -euo pipefail

# 仅上传生产部署所需文件到远程服务器
# 策略：以 .gitignore 为基础（不上传被忽略的文件），并额外包含 Ghost 内容目录（images/files/media等）；
# 可选 --with-backup：本地打包数据库与内容并上传到远程，同时可在远程用 restore.sh 恢复。
# 默认使用 ssh 别名 tecentserver，目标目录 /home/www/cv-ghost-blog
# 可通过环境变量或参数覆盖：REMOTE_HOST、REMOTE_DIR

REMOTE_HOST="${REMOTE_HOST:-tecentserver}"
REMOTE_DIR="${REMOTE_DIR:-/home/www/cv-ghost-blog}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

WITH_BACKUP=0
RESTORE_AFTER_UPLOAD=0
REMOTE_HOST_OVERRIDE=""
REMOTE_DIR_OVERRIDE=""

usage() {
  cat <<USAGE
用法: scripts/upload_prod.sh [--with-backup] [--restore] [--remote-host <host>] [--remote-dir <dir>]

选项:
  --with-backup            本地创建最新备份(数据库+内容)，上传至远程 backups/ 并可用于远程恢复
  --restore                搭配 --with-backup 使用：上传后在远程自动执行 restore.sh 恢复到最新备份
  --remote-host <host>     覆盖远程主机(默认: ${REMOTE_HOST})
  --remote-dir <dir>       覆盖远程目录(默认: ${REMOTE_DIR})
  -h, --help               显示帮助
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-backup)
      WITH_BACKUP=1
      shift
      ;;
    --restore)
      RESTORE_AFTER_UPLOAD=1
      shift
      ;;
    --remote-host)
      REMOTE_HOST_OVERRIDE="$2"
      shift 2
      ;;
    --remote-dir)
      REMOTE_DIR_OVERRIDE="$2"
      shift 2
      ;;
    -h|--help)
      usage; exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage; exit 1
      ;;
  esac
done

if [[ -n "${REMOTE_HOST_OVERRIDE}" ]]; then
  REMOTE_HOST="${REMOTE_HOST_OVERRIDE}"
fi
if [[ -n "${REMOTE_DIR_OVERRIDE}" ]]; then
  REMOTE_DIR="${REMOTE_DIR_OVERRIDE}"
fi

echo "本地项目根目录: ${PROJECT_ROOT}"
echo "远程: ${REMOTE_HOST}:${REMOTE_DIR}"

if [[ ! -f "${PROJECT_ROOT}/.env.prod" ]]; then
  echo "未找到 ${PROJECT_ROOT}/.env.prod，请先创建生产环境变量文件 (.env.prod)" >&2
  exit 1
fi

command -v rsync >/dev/null 2>&1 || { echo "需要 rsync，请先安装" >&2; exit 1; }
command -v ssh >/dev/null 2>&1 || { echo "需要 ssh，请先安装" >&2; exit 1; }

echo "在远程创建目录（若不存在）..."
ssh "${REMOTE_HOST}" "mkdir -p '${REMOTE_DIR}'"

echo "开始同步文件（以 .gitignore 为基础，不直接同步 data/ghost 内容）..."

# 基于 .gitignore 的过滤 + 额外 include 生产 compose、nginx、themes、scripts 等
rsync -avz -e ssh \
  --filter=':- .gitignore' \
  --exclude='.git/' \
  --exclude='**/.git/' \
  --include='docker-compose.yml' \
  --include='docker-compose.prod.yml' \
  --include='.env.prod' \
  --include='ssl/***' \
  --include='nginx/***' \
  --include='themes/***' \
  --include='scripts/***' \
  "${PROJECT_ROOT}/" "${REMOTE_HOST}:${REMOTE_DIR}/"

echo "上传并覆盖远程 .env.prod 文件..."
rsync -avz -e ssh "${PROJECT_ROOT}/.env.prod" "${REMOTE_HOST}:${REMOTE_DIR}/.env.prod"
echo "在远程将 .env.prod 复制为 .env（docker compose 默认读取 .env）..."
ssh "${REMOTE_HOST}" bash -lc "cd '${REMOTE_DIR}' && cp -f .env.prod .env && chmod 600 .env .env.prod"

if [[ ${WITH_BACKUP} -eq 1 ]]; then
  echo "执行本地备份(数据库+内容)..."
  # 运行现有备份脚本，生成 backups/<timestamp>
  (cd "${PROJECT_ROOT}" && bash scripts/backup.sh)
  LATEST_BACKUP_DIR="$(cd "${PROJECT_ROOT}" && ls -1dt backups/* 2>/dev/null | head -1 || true)"
  if [[ -z "${LATEST_BACKUP_DIR}" ]]; then
    echo "未找到本地备份目录，跳过备份上传" >&2
  else
    echo "上传备份目录: ${LATEST_BACKUP_DIR}"
    LATEST_BACKUP_BASENAME="$(basename "${LATEST_BACKUP_DIR}")"
    rsync -avz -e ssh \
      --exclude='.git/' --exclude='**/.git/' \
      "${PROJECT_ROOT}/${LATEST_BACKUP_DIR}" "${REMOTE_HOST}:${REMOTE_DIR}/backups/"

    if [[ ${RESTORE_AFTER_UPLOAD} -eq 1 ]]; then
      echo "在远程恢复备份: backups/${LATEST_BACKUP_BASENAME}"
      ssh "${REMOTE_HOST}" bash -lc '
        set -e
        if command -v docker compose >/dev/null 2>&1; then
          COMPOSE="docker compose"
        elif command -v docker-compose >/dev/null 2>&1; then
          COMPOSE="docker-compose"
        else
          echo "[ERROR] 远程未安装 docker compose 或 docker-compose" >&2; exit 1
        fi
        cd '"'"${REMOTE_DIR}"'"'
        ${COMPOSE} -f docker-compose.yml -f docker-compose.prod.yml pull db
        ${COMPOSE} -f docker-compose.yml -f docker-compose.prod.yml up -d db
        bash scripts/restore.sh 'backups/${LATEST_BACKUP_BASENAME}'
      '
    fi
  fi
fi

cat <<EOS
上传完成。
- 远程目录: ${REMOTE_HOST}:${REMOTE_DIR}
- 基于 .gitignore 同步了仓库文件，并额外包含：themes/**、nginx/**、scripts/**、docker-compose.prod.yml
- 已在远程将 .env.prod 复制为 .env
$( [[ ${WITH_BACKUP} -eq 1 ]] && echo "- 已上传本地最新备份到 ${REMOTE_DIR}/backups/" )
$( [[ ${WITH_BACKUP} -eq 1 && ${RESTORE_AFTER_UPLOAD} -eq 1 ]] && echo "- 已在远程自动执行恢复到最新备份" )

后续步骤（在远程执行）：
  ssh ${REMOTE_HOST} "cd ${REMOTE_DIR} && docker compose -f docker-compose.yml -f docker-compose.prod.yml pull && docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d"

如需自定义：
  scripts/upload_prod.sh --with-backup
  scripts/upload_prod.sh --with-backup --restore
  scripts/upload_prod.sh --remote-host myserver --remote-dir /path/to/dir

说明：
- 默认不直接同步 data/ghost 内容，请用 --with-backup 生成并上传备份，在远程用 scripts/restore.sh 恢复；或使用 --with-backup --restore 自动恢复。
- 未直接上传 MySQL 原始数据目录(不安全且易损坏)。
EOS


