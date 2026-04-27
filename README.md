# Hermes Agent — Docker Setup

A security-hardened Docker Compose stack for [Hermes Agent](https://github.com/nousresearch/hermes-agent) by Nous Research — a self-improving, model-agnostic AI agent that runs a closed learning loop: it curates memory, auto-creates skills after complex tasks, and builds a user model over time.

- **Upstream docs:** https://hermes-agent.nousresearch.com/docs
- **Upstream repo:** https://github.com/nousresearch/hermes-agent

---

## What you get

| Container | Role | Default URL |
|---|---|---|
| `hermes` | Gateway — OpenAI-compatible API + chat platform bridge | http://localhost:8642 |
| `hermes-dashboard` | Web UI — sessions, memory, and skill viewer | http://localhost:9119 |

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Mac or Windows)
- On **Windows**: WSL2 integration enabled in Docker Desktop settings
- `make` — included on Mac; on Windows install via WSL2 (`sudo apt install make`) or [Git for Windows](https://gitforwindows.org/)

---

## First-time setup

### macOS / Linux

```bash
# 1. Clone and enter the repo
git clone https://github.com/your-org/docker-hermes-agent.git
cd docker-hermes-agent

# 2. Create .env and data directories
make setup

# 3. (Optional) Edit .env — set ports, resource limits, or API key overrides
#    Most AI credentials are configured in the next step, not here.
nano .env

# 4. Run the interactive config wizard (sets LLM keys, Telegram token, etc.)
docker run -it --rm -v ~/.hermes:/opt/data nousresearch/hermes-agent setup

# 5. Start the stack
make up
```

Open http://localhost:9119 to access the dashboard.

### Windows (WSL2)

Run all commands inside a **WSL2 terminal** (Ubuntu or equivalent).

```bash
# 1. Clone and enter the repo (from your WSL2 home directory)
cd ~
git clone https://github.com/your-org/docker-hermes-agent.git
cd docker-hermes-agent

# 2. Create .env and data directories
make setup

# 3. Edit .env — set the data dir paths to WSL2-style Linux paths
nano .env
```

Update these two lines in `.env`:
```
HERMES_DATA_DIR=/home/youruser/.hermes
HERMES_WORKSPACE_DIR=/home/youruser/.hermes/workspace
```

> **Important:** Use Linux-style paths inside the WSL2 filesystem. Do **not** use `/mnt/c/...` NTFS paths — `chmod 700` does not behave correctly on NTFS mounts.

```bash
# 4. Run the interactive config wizard
docker run -it --rm -v ~/.hermes:/opt/data nousresearch/hermes-agent setup

# 5. Start the stack
make up
```

Open http://localhost:9119 in your Windows browser.

---

## Configuration

### Two separate `.env` files — do not confuse them

| File | Who reads it | Purpose |
|---|---|---|
| `docker-hermes-agent/.env` | Docker Compose | Port bindings, data dir paths, resource limits |
| `~/.hermes/.env` | Hermes agent | LLM API keys, Telegram bot token, allowed users |

The agent reads credentials from `~/.hermes/.env` (written by the setup wizard), **not** from Docker environment variables. To change LLM keys or Telegram settings, edit `~/.hermes/.env` directly or re-run the wizard:

```bash
docker run -it --rm -v ~/.hermes:/opt/data nousresearch/hermes-agent setup
```

### Key `.env` variables

| Variable | Default | Description |
|---|---|---|
| `HERMES_DATA_DIR` | `~/.hermes` | Host path for all agent state |
| `HERMES_WORKSPACE_DIR` | `~/.hermes/workspace` | Host path the agent can read/write |
| `HERMES_BIND_ADDR` | `127.0.0.1` | Bind address — keep as `127.0.0.1` for localhost-only |
| `HERMES_GATEWAY_PORT` | `8642` | Gateway API port |
| `HERMES_DASHBOARD_PORT` | `9119` | Dashboard UI port |
| `HERMES_MEMORY_LIMIT` | `4G` | Gateway container memory cap |
| `HERMES_CPU_LIMIT` | `2.0` | Gateway container CPU cap |
| `HERMES_SHM_SIZE` | `1g` | Shared memory (increase to `2g` for browser/Playwright skills) |

---

## Daily usage

```bash
make up         # Start the stack in the background
make down       # Stop all containers
make restart    # Restart all containers
make logs       # Tail gateway logs
make shell      # Bash shell inside the gateway container
make health     # Check the gateway /health endpoint
make upgrade    # Pull latest image and recreate containers
```

---

## Persistent data

Everything the agent learns lives in `HERMES_DATA_DIR` (`~/.hermes` by default):

```
~/.hermes/
  .env            # API keys (written by setup wizard — edit carefully)
  config.yaml     # Agent configuration
  SOUL.md         # Agent personality definition
  sessions/       # Conversation history
  memories/       # Long-term memory
  skills/         # Auto-created and custom skills
  cron/           # Scheduled tasks
  hooks/          # Lifecycle hooks
  logs/           # Agent logs
  workspace/      # The only path the agent can read/write (HERMES_WORKSPACE_DIR)
```

---

## Security

- All ports bind to `127.0.0.1` (localhost only) by default. Set `HERMES_BIND_ADDR=0.0.0.0` only when remote/LAN access is required, and apply firewall rules.
- The agent has no access to the host filesystem beyond `HERMES_DATA_DIR` and `HERMES_WORKSPACE_DIR`. Do not add bind-mounts without understanding what the agent can do with them.
- The dashboard mount is `read_only: true` — it cannot mutate agent state.
- No privileged containers; no host network mode.
- API keys are injected at runtime and are never baked into the image.

---

## Upgrading

```bash
make upgrade
```

This pulls the latest image and recreates containers. All data in `HERMES_DATA_DIR` is preserved.

---

## Migrating to a new machine

All agent state is plain files in `HERMES_DATA_DIR` — fully portable.

**1. On the source machine:**
```bash
make down
tar -czf hermes-data-backup.tar.gz -C ~ .hermes
```

**2. Copy the archive** to the target machine (USB, cloud, `scp`, etc.).

**3. On the target machine:**
```bash
mkdir -p ~/.hermes
tar -xzf hermes-data-backup.tar.gz -C ~
```

**4. Update `.env`** with the correct paths for the new machine.

**5. Check `~/.hermes/config.yaml`** for any absolute paths (e.g. `terminal.cwd`, `skills.external_dirs`) and update them to match the new machine.

**6. Start the stack:**
```bash
make setup   # creates dirs if missing, sets permissions
make up
```

What transfers: memories, sessions, skills, credentials, config, personality (`SOUL.md`), cron jobs, hooks.
What does not: the container image (re-pulled automatically), any data outside `HERMES_DATA_DIR`.

---

## Troubleshooting

**Gateway not responding:**
```bash
make health   # should print "Gateway healthy"
make logs     # inspect startup errors
```

**Port conflict:** Edit `HERMES_GATEWAY_PORT` or `HERMES_DASHBOARD_PORT` in `.env` and run `make up`.

**Windows — `chmod 700` warning in logs:** Make sure `HERMES_DATA_DIR` points to a WSL2 Linux path, not an NTFS mount (`/mnt/c/...`).

**Never run two gateway containers against the same data directory** — this corrupts agent state.
