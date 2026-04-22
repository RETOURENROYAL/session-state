#!/usr/bin/env bash
# Start-LiteLLM.sh — R3 LiteLLM Gateway persistent launcher
# Survives Codespace restarts. Source a .env file for real API keys.
# Usage: bash _automation/Start-LiteLLM.sh [--bg]
#   --bg  run in background (nohup), log to /tmp/litellm.log

set -euo pipefail

LITELLM_BIN="/home/codespace/.python/current/bin/litellm"
CONFIG="/workspaces/session-state/litellm-config.yaml"
PORT=4000
HOST="0.0.0.0"
LOGFILE="/tmp/litellm.log"
ENV_FILE="/workspaces/session-state/.env"

# Load real keys if .env exists
if [[ -f "$ENV_FILE" ]]; then
  echo "[Start-LiteLLM] Loading $ENV_FILE"
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
else
  echo "[Start-LiteLLM] No .env found — using placeholder values (models will be unhealthy)"
  export GROQ_API_KEY="${GROQ_API_KEY:-placeholder}"
  export CEREBRAS_API_KEY="${CEREBRAS_API_KEY:-placeholder}"
  export SAMBANOVA_API_KEY="${SAMBANOVA_API_KEY:-placeholder}"
  export OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-placeholder}"
  export OPENAI_API_KEY="${OPENAI_API_KEY:-placeholder}"
  export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-placeholder}"
  export GEMINI_API_KEY="${GEMINI_API_KEY:-placeholder}"
fi

export LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-r3-local}"

# Check if already running
if ss -tlnp 2>/dev/null | grep -q ":${PORT}"; then
  echo "[Start-LiteLLM] ✅ Already running on :$PORT — nothing to do"
  exit 0
fi

if [[ "${1:-}" == "--bg" ]]; then
  echo "[Start-LiteLLM] Starting in background → $LOGFILE"
  nohup "$LITELLM_BIN" --config "$CONFIG" --port "$PORT" --host "$HOST" \
    > "$LOGFILE" 2>&1 &
  echo "[Start-LiteLLM] PID $! — tail -f $LOGFILE to monitor"
else
  echo "[Start-LiteLLM] Starting on :$PORT (foreground)"
  exec "$LITELLM_BIN" --config "$CONFIG" --port "$PORT" --host "$HOST"
fi
