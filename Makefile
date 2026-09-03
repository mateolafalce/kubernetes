SHELL := /bin/bash

.PHONY: help check start deploy status url requests scale-up self-heal evidence reset stop

help:
	@./scripts/lab.sh help

check:
	@bash -n scripts/lab.sh
	@./scripts/lab.sh validate

start:
	@./scripts/lab.sh start

deploy:
	@./scripts/lab.sh deploy

status:
	@./scripts/lab.sh status

url:
	@./scripts/lab.sh url

requests:
	@./scripts/lab.sh request "$(TP_URL)"

scale-up:
	@./scripts/lab.sh scale 4

self-heal:
	@./scripts/lab.sh self-heal

evidence:
	@./scripts/lab.sh evidence

reset:
	@./scripts/lab.sh reset

stop:
	@./scripts/lab.sh stop
