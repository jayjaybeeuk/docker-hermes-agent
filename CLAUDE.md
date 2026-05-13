# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

For full operational reference (setup, commands, env vars, security, troubleshooting, migration) see [AGENTS.md](AGENTS.md).

## What this repo is

A security-hardened Docker Compose setup for **Hermes Agent** — a self-improving, model-agnostic AI agent by Nous Research (https://github.com/nousresearch/hermes-agent). Similar in structure to the openclaw-clawdwrap project but focused on self-learning rather than Claude Code automation.

Upstream Docker docs: https://hermes-agent.nousresearch.com/docs/user-guide/docker

## Key files

| File | Purpose |
|---|---|
| `docker-compose.yml` | Stack definition — services, mounts, ports, resource limits |
| `.env` | Docker Compose vars only — paths, ports, resource limits (gitignored) |
| `.env.example` | Template for the Docker `.env` — safe to commit |
| `Makefile` | Developer shortcuts wrapping `docker compose` |
| `setup.sh` | Creates host directories, sets permissions, prints next steps |
| `AGENTS.md` | Operational reference — setup, commands, troubleshooting, migration |

## Two separate .env files — do not confuse them

| File | Owner | Purpose |
|---|---|---|
| `docker-hermes-agent/.env` | Docker Compose | Port bindings, data dir paths, resource limits. Safe to edit directly. |
| `~/.hermes/.env` | Hermes agent | LLM API keys, messaging platform tokens, allowed users. Edit carefully. |

Hermes reads credentials from `/opt/data/.env` (mounted from `~/.hermes/.env`), **not** from Docker container environment variables. Never edit the Docker `.env` to add API keys — they belong in `~/.hermes/.env`.

## Modifying the stack

- Do not add new bind-mounts without understanding what the agent can access through them.
- Resource limits (`HERMES_MEMORY_LIMIT`, `HERMES_CPU_LIMIT`, `HERMES_SHM_SIZE`) are set in `.env` — do not hardcode them in `docker-compose.yml`.
- Increase `HERMES_SHM_SIZE` (default `1g`) if enabling Playwright/browser skills.
