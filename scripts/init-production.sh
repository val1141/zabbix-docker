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

DATA_DIRECTORY="${DATA_DIRECTORY:-/srv/zabbix}"
ENV_VARS_DIRECTORY="${ENV_VARS_DIRECTORY:-./env_vars}"
POSTGRES_USER_FILE="${ENV_VARS_DIRECTORY}/.POSTGRES_USER"
POSTGRES_PASSWORD_FILE="${ENV_VARS_DIRECTORY}/.POSTGRES_PASSWORD"

mkdir -p "$ENV_VARS_DIRECTORY"

if [[ ! -f "$POSTGRES_USER_FILE" ]]; then
  printf 'zabbix\n' > "$POSTGRES_USER_FILE"
fi

if [[ ! -f "$POSTGRES_PASSWORD_FILE" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32 > "$POSTGRES_PASSWORD_FILE"
  else
    tr -dc 'A-Za-z0-9_@%+=:,.-' </dev/urandom | head -c 48 > "$POSTGRES_PASSWORD_FILE"
    printf '\n' >> "$POSTGRES_PASSWORD_FILE"
  fi
fi

chown root:1995 "$POSTGRES_USER_FILE" "$POSTGRES_PASSWORD_FILE"
chmod 0440 "$POSTGRES_USER_FILE" "$POSTGRES_PASSWORD_FILE"

mkdir -p \
  "$DATA_DIRECTORY/backups" \
  "$DATA_DIRECTORY/etc/ssl/nginx" \
  "$DATA_DIRECTORY/usr/lib/zabbix/alertscripts" \
  "$DATA_DIRECTORY/usr/lib/zabbix/externalscripts" \
  "$DATA_DIRECTORY/usr/share/zabbix/modules" \
  "$DATA_DIRECTORY/var/lib/postgresql/data" \
  "$DATA_DIRECTORY/var/lib/zabbix/dbscripts" \
  "$DATA_DIRECTORY/var/lib/zabbix/enc" \
  "$DATA_DIRECTORY/var/lib/zabbix/export" \
  "$DATA_DIRECTORY/var/lib/zabbix/mibs" \
  "$DATA_DIRECTORY/var/lib/zabbix/modules" \
  "$DATA_DIRECTORY/var/lib/zabbix/ssh_keys" \
  "$DATA_DIRECTORY/var/lib/zabbix/ssl/certs" \
  "$DATA_DIRECTORY/var/lib/zabbix/ssl/keys" \
  "$DATA_DIRECTORY/var/lib/zabbix/ssl/ssl_ca"

# The official Zabbix containers use uid/gid 1997:1995 for writable Zabbix paths.
if command -v chown >/dev/null 2>&1; then
  chown -R 1997:1995 \
    "$DATA_DIRECTORY/usr/lib/zabbix" \
    "$DATA_DIRECTORY/usr/share/zabbix" \
    "$DATA_DIRECTORY/var/lib/zabbix" 2>/dev/null || true
fi

chmod 750 "$ENV_VARS_DIRECTORY" 2>/dev/null || true
chmod -R u+rwX,g+rX,o-rwx "$DATA_DIRECTORY" 2>/dev/null || true

cat <<INFO
Production directories and secrets are ready.

Data directory:      $DATA_DIRECTORY
Env vars directory:  $ENV_VARS_DIRECTORY
PostgreSQL user:     $(cat "$POSTGRES_USER_FILE")
PostgreSQL password: $POSTGRES_PASSWORD_FILE
INFO
