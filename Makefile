.DEFAULT_GOAL := help

COMPOSE ?= docker compose
COMPOSE_FILE ?= compose.yaml
ENV_FILE ?= .env
SERVICES ?= zabbix-server zabbix-web-nginx-pgsql postgres-server
ARGS ?=
ANSIBLE_INVENTORY ?= ansible/inventory/hosts.ini
ANSIBLE_PLAYBOOK ?= ansible/playbooks/prepare-vm.yml
ANSIBLE_ARGS ?=

compose = $(COMPOSE) -f $(COMPOSE_FILE) --env-file $(ENV_FILE)

.PHONY: help init config pull up down stop restart ps logs logs-follow update backup restore psql shell clean destroy ansible-deps ansible-prepare

help:
	@echo "Zabbix production deployment helper"
	@echo ""
	@echo "Usage:"
	@echo "  make init                         prepare /srv/zabbix and local secrets"
	@echo "  make config                       render and validate docker compose config"
	@echo "  make pull                         pull official images"
	@echo "  make up                           init + start stack"
	@echo "  make down                         stop and remove containers/networks"
	@echo "  make stop                         stop containers"
	@echo "  make restart                      restart stack"
	@echo "  make ps                           show container status"
	@echo "  make logs                         show logs for core services"
	@echo "  make logs-follow                  follow logs for core services"
	@echo "  make update                       init + pull + up"
	@echo "  make backup                       create PostgreSQL dump and config archive"
	@echo "  make restore FILE=/path/file.dump restore DB dump; requires CONFIRM_RESTORE=yes"
	@echo "  make psql                         open psql inside postgres container"
	@echo "  make destroy CONFIRM_DESTROY=yes  destructive: down -v"
	@echo "  make ansible-deps                 install Ansible Galaxy dependencies"
	@echo "  make ansible-prepare              prepare VM with ansible/playbooks/prepare-vm.yml"
	@echo ""
	@echo "Overrides:"
	@echo "  COMPOSE='docker compose' COMPOSE_FILE=compose.yaml ENV_FILE=.env ARGS='...'"

init:
	@./scripts/init-production.sh

config:
	@$(compose) config

pull:
	@$(compose) pull

up: init
	@$(compose) up -d

update: init pull
	@$(compose) up -d --remove-orphans

stop:
	@$(compose) stop $(ARGS)

down:
	@$(compose) down $(ARGS)

restart:
	@$(compose) restart $(ARGS)

ps:
	@$(compose) ps $(ARGS)

logs:
	@$(compose) logs $(ARGS) $(SERVICES)

logs-follow:
	@$(compose) logs -f $(ARGS) $(SERVICES)

backup:
	@./scripts/backup-zabbix-db.sh

restore:
	@if [ -z "$(FILE)" ]; then \
	  echo "ERROR: FILE=/path/to/zabbix.dump is required" >&2; \
	  exit 2; \
	fi
	@CONFIRM_RESTORE="$${CONFIRM_RESTORE:-no}" ./scripts/restore-zabbix-db.sh "$(FILE)"

psql:
	@$(compose) exec postgres-server psql -U "$$(cat env_vars/.POSTGRES_USER)" -d zabbix

shell:
	@$(compose) exec zabbix-server bash

clean:
	@$(compose) down --remove-orphans

destroy:
	@if [ "$${CONFIRM_DESTROY:-no}" != "yes" ]; then \
	  echo "Refusing to destroy without CONFIRM_DESTROY=yes" >&2; \
	  exit 3; \
	fi
	@$(compose) down -v --remove-orphans

ansible-deps:
	@ansible-galaxy install -r ansible/requirements.yml

ansible-prepare:
	@ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i $(ANSIBLE_INVENTORY) $(ANSIBLE_PLAYBOOK) $(ANSIBLE_ARGS)