# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A security-hardened Docker Compose setup for **Hermes Agent** — a self-improving, model-agnostic AI agent by Nous Research (https://github.com/nousresearch/hermes-agent). Hermes runs a closed learning loop: it curates memory, auto-creates skills after complex tasks, and builds a user model over time. Similar in structure to the openclaw-clawdwrap project but focused on self-learning rather than Claude Code automation.

Upstream Docker docs: https://hermes-agent.nousresearch.com/docs/user-guide/docker

## Common commands

```bash
make setup      # First run: copies .env.example → .env, creates data dirs
make up         # Start gateway + dashboard in background
make down       # Stop all containers
make logs       # Tail gateway logs
make shell      # Bash shell inside gateway container
make upgrade    # Pull latest image and recreate containers
make health     # Curl the /health endpoint
```

First-time config wizard (run once after `make setup`, before `make up`):
```bash
docker run -it --rm -v "$HERMES_DATA_DIR:/opt/data" nousresearch/hermes-agent setup
```

## Architecture

Two containers on an isolated bridge network (`hermes-internal`):

| Container | Port | Mount |
|---|---|---|
| `hermes` (gateway) | `HERMES_GATEWAY_PORT` → 8642 | `HERMES_DATA_DIR` → `/opt/data` (rw) |
| `hermes-dashboard` | `HERMES_DASHBOARD_PORT` → 9119 | `HERMES_DATA_DIR` → `/opt/data` (ro) |

The dashboard waits for the gateway healthcheck before starting. The gateway exposes an OpenAI-compatible API at `:8642` and a health endpoint at `:8642/health`.

**Only two host paths are ever mounted**: `HERMES_DATA_DIR` and `HERMES_WORKSPACE_DIR`. The agent has no access to the rest of the host filesystem.

## Security model

- `HERMES_BIND_ADDR` defaults to `127.0.0.1` — all ports are localhost-only. Change to `0.0.0.0` only with explicit intent and firewall rules in place.
- Dashboard mount is `read_only: true` — it cannot mutate agent state.
- No privileged containers; no host network mode.
- `HERMES_DATA_DIR` is created with `chmod 700` by `setup.sh`.
- API keys are injected as environment variables at runtime, never baked into the image.

## Key files

| File | Purpose |
|---|---|
| `docker-compose.yml` | Stack definition — services, mounts, ports, resource limits |
| `.env` | Local secrets and paths (gitignored, copied from `.env.example`) |
| `.env.example` | Template — safe to commit, contains no real secrets |
| `Makefile` | Developer shortcuts wrapping `docker compose` |
| `setup.sh` | Creates host directories, sets permissions, prints next steps |
| `AGENTS.md` | Operational reference for humans and AI agents working this stack |

## Cross-platform notes

**macOS / Linux:** Use `~/.hermes` or any absolute path in `.env`.

**Windows (WSL2):** Use Linux-style paths inside the WSL2 filesystem:
```
HERMES_DATA_DIR=/home/youruser/.hermes
HERMES_WORKSPACE_DIR=/home/youruser/.hermes/workspace
```
Avoid `/mnt/c/...` NTFS paths for the data dir — `chmod 700` does not behave correctly on NTFS mounts.

## Persistent data layout

```
HERMES_DATA_DIR/
  .env            # API keys (written by hermes setup wizard)
  config.yaml     # Agent config
  SOUL.md         # Agent personality
  sessions/       # Conversation history
  memories/       # Long-term memory
  skills/         # Auto-created and custom skills
  cron/           # Scheduled tasks
  hooks/          # Lifecycle hooks
  logs/           # Agent logs
  workspace/      # ← HERMES_WORKSPACE_DIR (only host path agent can write)
```

## Modifying the stack

- Do not add new bind-mounts without understanding what the agent can access through them.
- Resource limits are set in `.env` via `HERMES_MEMORY_LIMIT`, `HERMES_CPU_LIMIT`, etc. — do not hardcode them in `docker-compose.yml`.
- Increase `HERMES_SHM_SIZE` (default `1g`) if enabling Playwright/browser skills.
