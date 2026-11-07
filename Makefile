# Runs the headless Throne compose stack and wraps thronectl, which has to run inside the
# container after loading the API connection info from `Throne --print-connection`.
#
#   make                      list these targets (same as `make help`)
#
#   make up                   start Throne in the background
#   make down                 stop and remove the container (the throne-data volume is kept)
#   make restart              restart the container
#   make recreate             recreate the container, needed after changing THRONE_WEB_PASSWORD in .env
#   make pull                 pull the image set by THRONE_REGISTRY and THRONE_VERSION in .env
#   make update               pull, then recreate the container on the new image
#   make logs                 follow the logs (first start prints the web UI password and cert fingerprint)
#   make ps                   list the container
#   make config               validate and print the resolved compose file
#   make shell                open a shell in the container
#
#   make status               thronectl status
#   make import               import share links from a file (FILE=links.txt by default)
#   make lan-inbound          let the mapped port 2080 reach the proxy now (inbound_address=0.0.0.0;
#                             THRONE_INBOUND_ADDRESS in .env does this on every start)
#   make passwd               change the web UI password
#   make ctl CMD="..."        any thronectl command, e.g. `make ctl CMD="settings get"`
#                             (CMD runs inside single quotes, so it cannot contain one)
#
#   Compose: the `docker compose` v2 plugin when it exists, else legacy `docker-compose`.
#   Force one with COMPOSE_BIN=..., e.g. `make up COMPOSE_BIN=docker-compose`

SERVICE := throne
FILE ?= links.txt
CMD ?=
# v2 plugin if present, else v1; recursive, so it is only probed when a compose target runs
COMPOSE_BIN ?= $(shell docker compose version >/dev/null 2>&1 && echo 'docker compose' || echo docker-compose)
# Pinned so `make -C` from elsewhere still finds the same project and volume
COMPOSE_PROJECT ?= docker-throne
COMPOSE = $(COMPOSE_BIN) -p $(COMPOSE_PROJECT) -f $(CURDIR)/docker-compose.yaml
# thronectl needs THRONE_API_* from --print-connection; $$ escapes make, the single quotes the host shell
THRONECTL = sh -c 'eval "$$(/opt/Throne/Throne --print-connection)" && thronectl $(1)'

.PHONY: all help up down restart recreate pull update logs ps config shell status import lan-inbound passwd ctl

all: help

help:
	@sed -n 's/^#   //p' $(firstword $(MAKEFILE_LIST)) | grep -v '^Compose\|^Force'

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

# a changed secret value (THRONE_WEB_PASSWORD) does not make Compose recreate on its own
recreate:
	$(COMPOSE) up -d --force-recreate

pull:
	$(COMPOSE) pull

update: pull
	$(COMPOSE) up -d

logs:
	$(COMPOSE) logs -f $(SERVICE)

ps:
	$(COMPOSE) ps

config:
	$(COMPOSE) config

shell:
	$(COMPOSE) exec $(SERVICE) bash

status:
	$(COMPOSE) exec $(SERVICE) $(call THRONECTL,status)

# -T: stdin is the links file, not a terminal
import:
	@test -f "$(FILE)" || { echo "no such file: $(FILE) (set FILE=...)"; exit 1; }
	$(COMPOSE) exec -T $(SERVICE) $(call THRONECTL,import -) < "$(FILE)"

lan-inbound:
	$(COMPOSE) exec $(SERVICE) $(call THRONECTL,settings set inbound_address=0.0.0.0)

passwd:
	$(COMPOSE) exec $(SERVICE) thronectl web passwd

ctl:
	@test -n "$(CMD)" || { echo 'usage: make ctl CMD="<thronectl args>"'; exit 1; }
	$(COMPOSE) exec $(SERVICE) $(call THRONECTL,$(CMD))
