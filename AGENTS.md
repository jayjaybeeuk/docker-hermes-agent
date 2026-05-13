# Agent Instructions (Hermes Docker Stack)

Hermes is a self-improving, model-agnostic AI agent by Nous Research.
It runs a **closed learning loop**: it curates its own memory, creates skills autonomously after complex tasks, and models the user over time.

Upstream docs: https://hermes-agent.nousresearch.com/docs
Upstream repo: https://github.com/nousresearch/hermes-agent

---

## Stack overview

| Container | Role | Default port |
|---|---|---|
| `hermes` | Gateway — OpenAI-compatible API + chat platform bridge | 8642 (localhost) |
| `hermes-dashboard` | Web UI — session/memory/skill viewer | 9119 (localhost) |

Both containers share the **`HERMES_DATA_DIR`** bind-mount (`/opt/data` inside the container).
The dashboard mounts it **read-only**. The workspace sub-directory (`HERMES_WORKSPACE_DIR`) is the only host path the agent can read/write.

**Never run two gateway containers against the same data directory simultaneously** — this corrupts agent state.

---

## Two separate .env files — do not confuse them

| File | Owner | Purpose |
|---|---|---|
| `docker-hermes-agent/.env` | Docker Compose | Port bindings, data dir paths, resource limits. Safe to edit directly. |
| `~/.hermes/.env` | Hermes agent | LLM API keys, messaging platform tokens, allowed users. Written by `hermes setup` — edit carefully. |

Hermes reads credentials from `/opt/data/.env` (mounted from `~/.hermes/.env`), **not** from Docker container environment variables. To change LLM keys, platform tokens, or allowed users, edit `~/.hermes/.env` directly or re-run the setup wizard:
```bash
docker run -it --rm -v ~/.hermes:/opt/data nousresearch/hermes-agent setup
```

---

## First-time setup

```bash
cp .env.example .env          # then edit .env with your paths and ports
make setup                    # creates data/workspace dirs with correct permissions
docker run -it --rm \
  -v "$HERMES_DATA_DIR:/opt/data" \
  nousresearch/hermes-agent setup   # interactive config wizard (sets API keys, platform tokens)
make up                       # start gateway + dashboard
```

---

## Common operations

```bash
make up          # start stack (background)
make down        # stop stack
make logs        # tail gateway logs
make shell       # bash shell inside gateway container
make upgrade     # pull latest image + recreate containers
make health      # curl the /health endpoint
```

---

## Persistent data (`/opt/data` inside container)

| Path | Purpose |
|---|---|
| `.env` | API keys and secrets (never commit this) |
| `config.yaml` | Agent configuration |
| `SOUL.md` | Agent personality definition |
| `sessions/` | Conversation history |
| `memories/` | Long-term persistent memory |
| `skills/` | Auto-created and user-defined skills |
| `cron/` | Scheduled tasks |
| `hooks/` | Lifecycle hooks |
| `logs/` | Agent logs |

---

## Environment variables

| Variable | Purpose | Default |
|---|---|---|
| `HERMES_DATA_DIR` | Host path for all agent state | `~/.hermes` |
| `HERMES_WORKSPACE_DIR` | Host path the agent can read/write | `~/.hermes/workspace` |
| `HERMES_BIND_ADDR` | Port binding address (`127.0.0.1` = localhost only) | `127.0.0.1` |
| `HERMES_GATEWAY_PORT` | Host port for gateway API | `8642` |
| `HERMES_DASHBOARD_PORT` | Host port for dashboard UI | `9119` |
| `HERMES_MEMORY_LIMIT` | Gateway container memory cap | `4G` |
| `HERMES_CPU_LIMIT` | Gateway container CPU cap | `2.0` |
| `HERMES_SHM_SIZE` | Shared memory for Playwright/browser tools | `1g` |

---

## Security constraints

- Ports bind to `HERMES_BIND_ADDR` (`127.0.0.1` by default). Change to `0.0.0.0` only when LAN/remote access is explicitly required, and apply firewall rules accordingly.
- The agent has **no access to the host filesystem** beyond `HERMES_DATA_DIR` and `HERMES_WORKSPACE_DIR`. Do not add additional bind-mounts without understanding what the agent can do with them.
- The dashboard mount is **read-only** — it cannot modify agent state.
- No privileged mode; no host networking.
- `HERMES_DATA_DIR` is created with `chmod 700` by `setup.sh`.
- API keys are injected via `~/.hermes/.env` at runtime, never baked into the image.

---

## Windows (WSL2) notes

Set paths to Linux-style paths inside WSL2:
```
HERMES_DATA_DIR=/home/youruser/.hermes
HERMES_WORKSPACE_DIR=/home/youruser/.hermes/workspace
```
Avoid mounting Windows NTFS paths (`/mnt/c/...`) for the data dir — `chmod 700` will not behave correctly on NTFS.

---

## Troubleshooting

### Agent not responding / gateway unhealthy

If `docker compose ps` shows the `hermes` container as `unhealthy`, or the gateway logs show `No messaging platforms enabled`, perform a clean restart:

```bash
make down && make up
```

This clears transient state that can accumulate after long-running sessions (the gateway health check looks for `/opt/data/gateway.pid`, which may not be written if startup is interrupted). A clean restart is sufficient in most cases — no data is lost.

If the gateway comes up but immediately shows `No messaging platforms enabled`, the credentials in `~/.hermes/.env` are missing or incomplete. Re-run the setup wizard:
```bash
docker run -it --rm -v ~/.hermes:/opt/data nousresearch/hermes-agent setup
```

### Checking gateway health manually

```bash
make health          # curl /health endpoint
docker compose ps    # check container status
make logs            # tail gateway logs
docker exec hermes sh -c "cat /opt/data/logs/gateway.log | tail -50"
```

---

## Upgrade procedure

```bash
make upgrade
# Equivalent to:
docker pull nousresearch/hermes-agent:latest
docker compose up -d --force-recreate
```

Data in `HERMES_DATA_DIR` is preserved across upgrades.

---

## Migrating data between machines (Mac ↔ Windows)

All Hermes state lives in `HERMES_DATA_DIR` (`~/.hermes/` by default) on the host. It is plain files — fully portable.

### Steps

**1. On the source machine — stop the stack and archive the data dir:**
```bash
make down
tar -czf hermes-data-backup.tar.gz -C ~ .hermes
```

**2. Copy the archive to the target machine** (USB, cloud storage, `scp`, etc.)

**3. On the target machine — extract:**

macOS / Linux:
```bash
mkdir -p ~/.hermes
tar -xzf hermes-data-backup.tar.gz -C ~
```

Windows (WSL2 — run inside WSL2 terminal):
```bash
mkdir -p ~/.hermes
tar -xzf hermes-data-backup.tar.gz -C ~
```

**4. Update `HERMES_DATA_DIR` and `HERMES_WORKSPACE_DIR` in the new machine's `.env`:**
```
HERMES_DATA_DIR=/home/youruser/.hermes
HERMES_WORKSPACE_DIR=/home/youruser/.hermes/workspace
```

**5. Check `~/.hermes/config.yaml` for absolute paths** (e.g. `terminal.cwd`, `skills.external_dirs`) and update them to match the new machine's filesystem.

**6. Start the stack:**
```bash
make setup   # creates dirs if missing, sets permissions
make up
```

### What transfers

| Transfers with the archive | Does not transfer |
|---|---|
| Memories, sessions, skills | Container image (re-pulled automatically) |
| Credentials, config, personality (`SOUL.md`) | Any data outside `HERMES_DATA_DIR` |
| Cron jobs, hooks, logs | Host-specific absolute paths in `config.yaml` |
