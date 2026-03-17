#!/usr/bin/env bash
set -euo pipefail

# ── Software Factory Setup ──
#
# Sets up the OpenClaw agent workspace and Factory backend.
#
# Usage:
#   ./scripts/setup.sh                    # Local: link workspace
#   ./scripts/setup.sh --agent work       # Local: named agent
#   ./scripts/setup.sh --docker           # Docker: build & start all services
#   ./scripts/setup.sh --docker --detach  # Docker: start in background

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_ID=""
USE_DOCKER=false
DETACH=false

usage() {
  cat <<'EOF'
Usage: setup.sh [OPTIONS]

Options:
  --agent <id>    Configure a named agent (default: agents.defaults)
  --docker        Use Docker (builds openclaw + factory containers)
  --detach        Run containers in background (implies --docker)
  -h, --help      Show this help

Examples:
  ./scripts/setup.sh                     # Link workspace for default agent
  ./scripts/setup.sh --agent work        # Link workspace for agent "work"
  ./scripts/setup.sh --docker --detach   # Build and run everything in Docker
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)  AGENT_ID="$2"; shift 2 ;;
    --docker) USE_DOCKER=true; shift ;;
    --detach) USE_DOCKER=true; DETACH=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# ── Docker mode ──
if $USE_DOCKER; then
  if ! command -v docker &>/dev/null; then
    echo "ERROR: docker not found."
    echo "Install Docker: https://docs.docker.com/get-docker/"
    exit 1
  fi

  if [ ! -f "${REPO_DIR}/.env" ]; then
    echo "No .env found. Creating from .env.example..."
    cp "${REPO_DIR}/.env.example" "${REPO_DIR}/.env"
    echo ""
    echo "Edit .env with your settings before starting:"
    echo "  \$EDITOR .env"
    echo ""
    echo "At minimum, set AGENT_DATA_DIR to your data directory."
    exit 1
  fi

  echo "Building and starting Software Factory via Docker..."
  COMPOSE_ARGS=("up" "--build")
  if $DETACH; then
    COMPOSE_ARGS+=("-d")
  fi

  docker compose -f "${REPO_DIR}/docker-compose.yml" "${COMPOSE_ARGS[@]}"
  exit 0
fi

# ── Local mode ──
if ! command -v openclaw &>/dev/null; then
  echo "ERROR: openclaw CLI not found."
  echo ""
  echo "Install it:"
  echo "  npm install -g openclaw@latest"
  echo "  openclaw onboard --install-daemon"
  echo ""
  echo "Or use Docker mode:"
  echo "  $0 --docker"
  exit 1
fi

echo "Linking workspace: ${REPO_DIR}"

if [[ -n "$AGENT_ID" ]]; then
  echo "Agent: ${AGENT_ID}"
  openclaw config set "agents.list" --merge "{\"id\":\"${AGENT_ID}\",\"workspace\":\"${REPO_DIR}\"}"
else
  echo "Agent: default"
  openclaw config set agents.defaults.workspace "${REPO_DIR}"
fi

# Ensure data dir from .env or default
if [ -f "${REPO_DIR}/.env" ]; then
  # shellcheck source=/dev/null
  source "${REPO_DIR}/.env"
fi
DATA_DIR="${AGENT_DATA_DIR:-${REPO_DIR}/data}"
mkdir -p "${DATA_DIR}/memory" "${DATA_DIR}/logs" "${DATA_DIR}/sessions"

echo ""
echo "Done. Workspace linked."
echo ""
echo "To start the Factory (Elixir backend):"
echo "  cd factory && mix deps.get && mix run --no-halt"
echo ""
echo "Or use Docker for everything:"
echo "  $0 --docker --detach"
echo ""
echo "To pair a messaging channel:"
echo "  openclaw pairing whatsapp     # Scan QR code"
echo "  openclaw pairing telegram     # Enter bot token"
echo "  openclaw dashboard            # Open web chat UI"
