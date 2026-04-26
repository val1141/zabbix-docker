#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

COMPOSE="${COMPOSE:-docker compose}"
COMPOSE_FILE="${COMPOSE_FILE:-compose.yaml}"
ENV_FILE="${ENV_FILE:-.env}"
ENV_VARS_DIRECTORY="${ENV_VARS_DIRECTORY:-./env_vars}"
BACKUP_DIRECTORY="${BACKUP_DIRECTORY:-${DATA_DIRECTORY:-/srv/zabbix}/backups}"
POSTGRES_SERVICE="${POSTGRES_SERVICE:-postgres-server}"
DB_NAME="${POSTGRES_DB:-zabbix}"
DB_USER="$(cat "${ENV_VARS_DIRECTORY}/.POSTGRES_USER")"
STAMP="$(date +%Y%m%d-%H%M%S)"
DUMP_FILE="${BACKUP_DIRECTORY}/zabbix-${STAMP}.dump"
CONFIG_FILE="${BACKUP_DIRECTORY}/zabbix-config-${STAMP}.tar.gz"

mkdir -p "$BACKUP_DIRECTORY"

$COMPOSE -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T "$POSTGRES_SERVICE" \
  pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc > "${DUMP_FILE}.tmp"
mv "${DUMP_FILE}.tmp" "$DUMP_FILE"
chmod 600 "$DUMP_FILE"

tar --exclude='env_vars/.MYSQL_*' \
    --exclude='*.dump' \
    --exclude='*.sql' \
    --exclude='*.sql.gz' \
    -czf "$CONFIG_FILE" \
    .env compose.yaml Makefile README.md env_vars scripts
chmod 600 "$CONFIG_FILE"

printf 'Database backup: %s\n' "$DUMP_FILE"
printf 'Config backup:   %s\n' "$CONFIG_FILE"
