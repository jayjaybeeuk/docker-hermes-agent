.DEFAULT_GOAL := help
COMPOSE := docker compose -f docker-compose.yml

.PHONY: help setup up down restart logs shell pull upgrade health

help:
	@echo "Hermes Agent — available targets:"
	@echo ""
	@echo "  make setup      Copy .env.example to .env and create data directories"
	@echo "  make up         Start all services in the background"
	@echo "  make down       Stop and remove containers"
	@echo "  make restart    Restart all services"
	@echo "  make logs       Tail logs from the gateway container"
	@echo "  make shell      Open a shell inside the hermes gateway container"
	@echo "  make pull       Pull the latest image from Docker Hub"
	@echo "  make upgrade    Pull latest image and recreate containers"
	@echo "  make health     Check gateway health endpoint"
	@echo ""

setup:
	@if [ -f .env ]; then \
		echo ".env already exists — skipping copy."; \
	else \
		cp .env.example .env; \
		echo ".env created. Edit it before running 'make up'."; \
	fi
	@bash setup.sh

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs -f hermes

shell:
	$(COMPOSE) exec hermes bash

pull:
	docker pull nousresearch/hermes-agent:latest

upgrade: pull
	$(COMPOSE) up -d --force-recreate

health:
	@. ./.env && curl -sf "http://$${HERMES_BIND_ADDR:-127.0.0.1}:$${HERMES_GATEWAY_PORT:-8642}/health" \
		&& echo "Gateway healthy" || echo "Gateway not responding"
