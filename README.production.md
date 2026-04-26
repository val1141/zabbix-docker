# Production deployment profile

Этот репозиторий оставляет официальные Zabbix Docker-файлы как базу, но основной `compose.yaml` теперь является минимальным production-сценарием:

- `postgres-server` на TimescaleDB;
- `server-db-init` для инициализации PostgreSQL-схемы Zabbix;
- `zabbix-server`;
- `zabbix-web-nginx-pgsql`.

## Первичная подготовка VM

```bash
sudo mkdir -p /srv/zabbix
sudo ./scripts/init-production.sh
```

Скрипт создаёт runtime-каталоги, `env_vars/.POSTGRES_USER` и `env_vars/.POSTGRES_PASSWORD`. Эти файлы не должны попадать в Git.

## Запуск

```bash
docker compose config
docker compose pull
docker compose up -d
docker compose ps
docker compose logs -f server-db-init zabbix-server zabbix-web-nginx-pgsql
```

По умолчанию web-интерфейс публикуется только на loopback VM:

```text
127.0.0.1:8080 -> container:8080
127.0.0.1:8443 -> container:8443
```

Для внешнего доступа поставь reverse proxy на host или измени в `.env`:

```env
ZABBIX_WEB_NGINX_BIND_IP=0.0.0.0
```

Порт Zabbix trapper/server `10051/tcp` слушает `0.0.0.0`, потому что он нужен active agents и proxies. Ограничь доступ firewall-ом до management-сетей и сетей агентов.

## Backup

```bash
sudo ./scripts/backup-zabbix-db.sh
```

Backup кладётся в `/srv/zabbix/backups` и содержит PostgreSQL dump + архив конфигурации. Архив конфигурации включает secrets, поэтому храни его как чувствительные данные.

## Restore

```bash
sudo ./scripts/restore-zabbix-db.sh /srv/zabbix/backups/zabbix-YYYYMMDD-HHMMSS.dump
```

Перед restore скрипт останавливает application containers, поднимает PostgreSQL, пересоздаёт БД и запускает стек обратно.

## Что намеренно выключено

В минимальном профиле отключены Java Gateway, SNMP traps, browser pollers, report writers, Selenium, Elasticsearch и Zabbix agent container. Для мониторинга самой VM лучше установить `zabbix-agent2` пакетами на host.
