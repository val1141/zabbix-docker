# Ansible VM preparation

This Ansible profile prepares an Ubuntu/Debian VM for the repository's production Zabbix Compose stack.
It intentionally avoids custom roles. Docker is installed through `geerlingguy.docker`; UFW is managed with
`community.general.ufw`; optional Compose startup uses `community.docker.docker_compose_v2`.

## Install dependencies on the control node

```bash
cd ansible
ansible-galaxy install -r requirements.yml
```

## Create inventory

```bash
cp inventory/hosts.example.ini inventory/hosts.ini
vim inventory/hosts.ini
vim inventory/group_vars/zabbix_vm.yml
```

At minimum, set the VM IP/user in `hosts.ini`. Then review:

- `zabbix_data_directory`, default `/srv/zabbix`
- `zabbix_compose_project_path`, default `/opt/zabbix`
- `zabbix_trapper_allowed_sources`, allowed sources for `10051/tcp`
- `zabbix_docker_users`, users allowed to run Docker directly

## Prepare the VM

```bash
ansible-playbook -i inventory/hosts.ini playbooks/prepare-vm.yml
```

From the repository root you can also run:

```bash
make ansible-deps
make ansible-prepare ANSIBLE_INVENTORY=ansible/inventory/hosts.ini
```

## Optional repository sync and stack startup

By default, the playbook prepares the VM only. To copy this repository from the controller to the VM:

```yaml
zabbix_compose_copy_from_controller: true
zabbix_compose_run_init: true
```

To also start the Compose stack:

```yaml
zabbix_compose_up: true
```

The playbook then uses `community.docker.docker_compose_v2` against `compose.yaml` in `zabbix_compose_project_path`.

## Firewall notes

The Compose file binds the web UI to loopback (`127.0.0.1:8080` and `127.0.0.1:8443`). Put a reverse proxy or VPN in
front of it if users need remote access.

Port `10051/tcp` is published for active agents and proxies. Docker-published ports can bypass plain UFW filtering,
so the playbook also installs a small `DOCKER-USER` chain service when `zabbix_manage_docker_user_firewall` is true.
Keep `zabbix_trapper_allowed_sources` limited to trusted agent/proxy networks.

## Backup timer

When `zabbix_backup_timer_enabled` is true, the playbook installs `zabbix-compose-backup.timer`, which runs the existing
`scripts/backup-zabbix-db.sh` from `zabbix_compose_project_path`. The service has `ConditionPathExists`, so it is safe to
enable before the repository is copied.
