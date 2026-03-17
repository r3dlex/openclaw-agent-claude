#!/usr/bin/env bash
set -euo pipefail

# ── OpenClaw Agent Workspace Setup ──
# Links this repo as the agent workspace for an OpenClaw instance.
#
# Usage:
#   ./scripts/setup.sh                    # Uses default agent
#   ./scripts/setup.sh --agent my-agent   # Uses a specific agent
#
# Prerequisites:
#   - OpenClaw installed: curl -fsSL https://openclaw.ai/install.sh | bash
#   - Gateway running:    openclaw gateway status

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT_ID="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--agent <agent-id>]"
      echo ""
      echo "Links this repo as the OpenClaw agent workspace."
      echo "If --agent is omitted, configures the default agent."
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Check OpenClaw is installed
if ! command -v openclaw &>/dev/null; then
  echo "ERROR: openclaw CLI not found."
  echo "Install it: curl -fsSL https://openclaw.ai/install.sh | bash"
  exit 1
fi

# Check gateway is running
if ! openclaw gateway status &>/dev/null; then
  echo "WARNING: Gateway is not running."
  echo "Start it: openclaw gateway"
  echo ""
fi

# Configure workspace
echo "Linking workspace: ${REPO_DIR}"

if [[ -n "$AGENT_ID" ]]; then
  echo "Agent: ${AGENT_ID}"
  openclaw config set "agents.list" --merge "{\"id\":\"${AGENT_ID}\",\"workspace\":\"${REPO_DIR}\"}"
else
  echo "Agent: default"
  openclaw config set agents.defaults.workspace "${REPO_DIR}"
fi

# Ensure runtime directories exist
mkdir -p "${REPO_DIR}/memory"

echo ""
echo "Done. Workspace configured."
echo ""
echo "Next steps:"
echo "  1. Pair a channel:  openclaw pairing whatsapp"
echo "  2. Or use web chat: openclaw dashboard"
echo "  3. Start chatting — the agent will bootstrap on first message."
