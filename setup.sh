#!/usr/bin/env bash
# First-run setup: creates data directories defined in .env.
set -euo pipefail

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Run: cp .env.example .env  then edit it." >&2
  exit 1
fi

# Load only the two path variables we need
HERMES_DATA_DIR=$(grep -E '^HERMES_DATA_DIR=' .env | cut -d= -f2- | sed "s|^~|$HOME|")
HERMES_WORKSPACE_DIR=$(grep -E '^HERMES_WORKSPACE_DIR=' .env | cut -d= -f2- | sed "s|^~|$HOME|")

if [ -z "$HERMES_DATA_DIR" ]; then
  echo "ERROR: HERMES_DATA_DIR is not set in .env" >&2
  exit 1
fi

if [ -z "$HERMES_WORKSPACE_DIR" ]; then
  echo "ERROR: HERMES_WORKSPACE_DIR is not set in .env" >&2
  exit 1
fi

echo "Creating data directory:      $HERMES_DATA_DIR"
mkdir -p "$HERMES_DATA_DIR"

echo "Creating workspace directory: $HERMES_WORKSPACE_DIR"
mkdir -p "$HERMES_WORKSPACE_DIR"

# Restrict permissions: owner-only access to the data dir
chmod 700 "$HERMES_DATA_DIR"

DASHBOARD_PORT=$(grep -E '^HERMES_DASHBOARD_PORT=' .env | cut -d= -f2- || echo "9119")

echo ""
echo "Setup complete. Next steps:"
echo "  1. Edit .env — add your API keys (ANTHROPIC_API_KEY / OPENAI_API_KEY)"
echo "  2. Run the first-time config wizard:"
echo "       docker run -it --rm -v \"$HERMES_DATA_DIR:/opt/data\" nousresearch/hermes-agent setup"
echo "  3. Start the stack:  make up"
echo "  4. Open dashboard:   http://127.0.0.1:${DASHBOARD_PORT}"
echo ""
