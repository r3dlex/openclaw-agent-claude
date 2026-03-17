#!/usr/bin/env bash
set -euo pipefail

# ── OpenClaw Agent Entrypoint ──
# This script initializes the workspace and starts the OpenClaw agent.

WORKSPACE="${OPENCLAW_WORKSPACE:-/workspace}"

# Validate required environment
if [ -z "${AGENT_API_KEY:-}" ]; then
  echo "ERROR: AGENT_API_KEY is not set. See .env.example for required variables." >&2
  exit 1
fi

# Ensure runtime directories exist
mkdir -p "${WORKSPACE}/memory"

# Initialize .openclaw state directory if missing
if [ ! -d "${WORKSPACE}/.openclaw" ]; then
  mkdir -p "${WORKSPACE}/.openclaw"
  echo '{"version":1}' > "${WORKSPACE}/.openclaw/workspace-state.json"
fi

echo "Starting OpenClaw agent..."
echo "  Workspace: ${WORKSPACE}"
echo "  Model:     ${AGENT_MODEL:-claude-sonnet-4-20250514}"
echo "  Log level: ${LOG_LEVEL:-info}"

# Start the agent — pass through any extra arguments
exec openclaw start \
  --workspace "${WORKSPACE}" \
  "$@"
