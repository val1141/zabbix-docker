#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: CONFIRM_RESTORE=yes $0 /path/to/zabbix.dump" >&2
  exit 2
fi

if [[ "${CONFIRM_RESTORE:-no}" != "yes" ]]; then
  echo "Refusing to restore without CONFIRM_RESTORE=yes because this is destructive." >&2
  exit 3
fi

DUMP_FILE="$1"
if [[ ! -f "$DUMP_FILE" ]]; then
  echo "Dump file not found: $DUMP_FILE" >&2
  exit 4
fi

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
POSTGRES_SERVICE="${POSTGRES_SERVICE:-postgres-server}"
DB_NAME="${POSTGRES_DB:-zabbix}"
DB_USER="$(cat "${ENV_VARS_DIRECTORY}/.POSTGRES_USER")"

$COMPOSE -f "$COMPOSE_FILE" --env-file "$ENV_FILE" stop zabbix-web-nginx-pgsql zabbix-server server-db-init || true
$COMPOSE -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d postgres-server

$COMPOSE -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T "$POSTGRES_SERVICE" \
  dropdb -U "$DB_USER" --if-exists "$DB_NAME"
$COMPOSE -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T "$POSTGRES_SERVICE" \
  createdb -U "$DB_USER" "$DB_NAME"
$COMPOSE -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T "$POSTGRES_SERVICE" \
  pg_restore -U "$DB_USER" -d "$DB_NAME" --clean --if-exists < "$DUMP_FILE"

$COMPOSE -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
printf 'Restore completed from %s\n' "$DUMP_FILE"
