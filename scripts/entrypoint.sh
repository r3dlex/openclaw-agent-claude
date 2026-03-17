#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/workspace"
DATA_DIR="${AGENT_DATA_DIR:-/workspace/data}"

# ── Link workspace ──
if ! openclaw config get agents.defaults.workspace &>/dev/null 2>&1; then
  echo "[entrypoint] Linking workspace: ${WORKSPACE}"
  openclaw config set agents.defaults.workspace "${WORKSPACE}"
fi

# ── Ensure runtime directories ──
mkdir -p "${DATA_DIR}/memory" "${DATA_DIR}/logs" "${DATA_DIR}/sessions"
mkdir -p "${WORKSPACE}/memory"

# ── Symlink data dir into workspace for agent access ──
if [ ! -L "${WORKSPACE}/data" ] && [ ! -d "${WORKSPACE}/data" ]; then
  ln -sf "${DATA_DIR}" "${WORKSPACE}/data"
fi

# ── Onboarding ──
if [ ! -f /root/.openclaw/openclaw.json ]; then
  echo "[entrypoint] First run. Running onboard..."
  openclaw onboard --install-daemon || true
fi

# ── Start gateway ──
echo "[entrypoint] Starting OpenClaw gateway on port ${OPENCLAW_GATEWAY_PORT:-18789}"
exec openclaw gateway --port "${OPENCLAW_GATEWAY_PORT:-18789}"
