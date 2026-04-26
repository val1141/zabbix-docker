# Zabbix production deployment

This repository is a deployment-only Compose profile for a single Zabbix VM, for example a VM running in Proxmox.

Target stack:

- Zabbix Server 7.0 LTS, PostgreSQL build
- Zabbix Web Nginx 7.0 LTS, PostgreSQL build
- PostgreSQL 17 with TimescaleDB 2.18
- local persistent data under `/srv/zabbix`
- local PostgreSQL credentials stored as Docker secrets through files in `env_vars/`


> [!IMPORTANT]
> Для production-развёртывания в Proxmox VM используй минимальный профиль из [README.production.md](README.production.md).
> Дефолтный `compose.yaml` в этом форке настроен на Zabbix LTS + PostgreSQL/TimescaleDB + Nginx.

The repository intentionally does **not** contain Dockerfiles, GitHub Actions, image build/bake configuration, Kubernetes manifests, proxy profiles, Selenium, Java Gateway, SNMP traps, Elasticsearch, MySQL, or containerized Zabbix Agent. Use `zabbix-agent2` as a host package when you need to monitor the VM itself.

## First run

```bash
sudo make init
make config
make pull
make up
make ps
```

The web UI is bound to loopback by default:

```text
http://127.0.0.1:8080
https://127.0.0.1:8443
```

Put a reverse proxy or VPN in front of it. Port `10051/tcp` is published on `0.0.0.0` for active agents and proxies; restrict it with the host firewall to trusted networks.

## Secrets

Real secret files are ignored by Git:

```text
env_vars/.POSTGRES_USER
env_vars/.POSTGRES_PASSWORD
```

`make init` creates them if missing. Example files are kept only as placeholders:

```text
env_vars/.POSTGRES_USER.example
env_vars/.POSTGRES_PASSWORD.example
```

## Data layout

`DATA_DIRECTORY=/srv/zabbix` is set in `.env`. In Proxmox, prefer a dedicated virtual disk mounted to `/srv/zabbix`.

Important paths:

```text
/srv/zabbix/var/lib/postgresql/data   PostgreSQL data
/srv/zabbix/backups                   pg_dump/config backups
/srv/zabbix/usr/lib/zabbix/*          alert and external scripts
/srv/zabbix/var/lib/zabbix/*          Zabbix runtime mounts
```

## Operations

```bash
make logs-follow
make restart
make update
make backup
```

Restore is intentionally guarded:

```bash
CONFIRM_RESTORE=yes make restore FILE=/srv/zabbix/backups/zabbix-YYYYMMDD-HHMMSS.dump
```

Destructive volume removal is also guarded:

```bash
CONFIRM_DESTROY=yes make destroy
```

## Optional overrides

Create ignored override files when you need local changes without changing tracked defaults:

```text
env_vars/.env_srv_override
env_vars/.env_web_override
env_vars/.env_db_pgsql_override
```
Typical examples are cache sizes, poller counts, reverse-proxy headers, and PostgreSQL-specific settings.


## VM preparation with Ansible

The `ansible/` directory contains a VM preparation playbook for this Compose profile.
It uses existing Galaxy content instead of custom roles:

- `geerlingguy.docker` installs Docker Engine and the Docker Compose plugin.
- `community.general.ufw` manages UFW rules.
- `community.docker.docker_compose_v2` can optionally start the stack.

Install Ansible dependencies and run the preparation playbook:

```bash
make ansible-deps
cp ansible/inventory/hosts.example.ini ansible/inventory/hosts.ini
vim ansible/inventory/hosts.ini
vim ansible/inventory/group_vars/zabbix_vm.yml
make ansible-prepare ANSIBLE_INVENTORY=ansible/inventory/hosts.ini
```

By default the playbook prepares the VM only: packages, Docker, qemu guest agent, UFW, `/srv/zabbix`,
backup timer, and Docker `DOCKER-USER` filtering for `10051/tcp`. Set these variables when you want the
playbook to copy the repository and start Compose too:

```yaml
zabbix_compose_copy_from_controller: true
zabbix_compose_run_init: true
zabbix_compose_up: true
```

Keep `zabbix_trapper_allowed_sources` limited to trusted active-agent/proxy networks. Docker-published ports can bypass plain UFW filtering, so the playbook installs an additional `DOCKER-USER` chain service by default.