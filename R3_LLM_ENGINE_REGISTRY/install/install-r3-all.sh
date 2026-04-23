#!/usr/bin/env bash
# ============================================================
# install-r3-all.sh — R³ VIB.E Complete Stack (Bash/Codespace)
# ============================================================
# Starts: LiteLLM :4000  +  n8n :5678  (ChatLegs = Windows-only)
#
# Remote one-liner:
#   curl -fsSL 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/install-r3-all.sh' | bash
# ============================================================

set -euo pipefail

REG="/workspaces/session-state/R3_LLM_ENGINE_REGISTRY"
ACTION="${1:-start}"

# ── Colours ──────────────────────────────────────────────────
GRN='\033[0;32m'; YLW='\033[0;33m'; RED='\033[0;31m'; CYN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "  ${GRN}[OK]${NC}   $*"; }
skip() { echo -e "  ${YLW}[SKIP]${NC} $*"; }
warn() { echo -e "  ${YLW}[WARN]${NC} $*"; }
err()  { echo -e "  ${RED}[ERR]${NC}  $*"; }
info() { echo -e "  ${CYN}[..]${NC}   $*"; }

header() {
    echo ""
    echo -e "  ${CYN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${CYN}║   R³ VIB.E — Complete Stack (Bash/Codespace)                ║${NC}"
    echo -e "  ${CYN}║   LiteLLM :4000  │  n8n :5678  │  Ollama RAZER/APPSEN       ║${NC}"
    echo -e "  ${CYN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

test_port() {
    local port=$1
    (echo >/dev/tcp/127.0.0.1/"$port") 2>/dev/null && return 0 || return 1
}

wait_port() {
    local port=$1 secs=${2:-20}
    local i=0
    while [ $i -lt $secs ]; do
        test_port "$port" && return 0
        sleep 1; i=$((i+1))
    done
    return 1
}

show_status() {
    echo ""
    echo "  ══════════════════════════════════════════"
    echo "    R³ VIB.E — Live Status"
    echo "  ══════════════════════════════════════════"
    for entry in "LiteLLM :4000:4000" "n8n :5678:5678" "Ollama RAZER :11434:11434"; do
        name="${entry%%:*}"
        port="${entry##*:}"
        if test_port "$port"; then
            echo -e "    ${GRN}[OK]${NC}  $name"
        else
            echo -e "    ${RED}[--]${NC}  $name"
        fi
    done
    echo "  ══════════════════════════════════════════"
    echo ""
    echo "  LiteLLM routes (via :4000/v1):"
    echo "    r3/code, r3/reasoning, r3/fast, r3/chat,"
    echo "    r3/chat-heavy, r3/large, r3/autocomplete,"
    echo "    r3/embed (APPSEN), r3/appsen-chat (+5 more)"
    echo ""
}

header

if [ "$ACTION" = "status" ]; then
    show_status; exit 0
fi

if [ "$ACTION" = "stop" ]; then
    info "Stopping r3-litellm..."
    docker stop r3-litellm 2>/dev/null || true
    ok "r3-litellm stopped"
    exit 0
fi

# ── STEP 1: LiteLLM :4000 ────────────────────────────────────
info "Step 1/3 — LiteLLM Gateway :4000"
if test_port 4000; then
    skip "LiteLLM :4000 already running"
else
    CONFIG="$REG/config/litellm-config.yaml"
    if [ ! -f "$CONFIG" ]; then
        err "litellm-config.yaml not found at $CONFIG"
        exit 1
    fi

    # Check if r3-litellm container exists
    if docker ps -a --format '{{.Names}}' | grep -q '^r3-litellm$'; then
        info "Starting existing r3-litellm container..."
        docker start r3-litellm
    else
        info "Creating r3-litellm container..."
        docker run -d \
            --name r3-litellm \
            --restart unless-stopped \
            --add-host host.docker.internal:host-gateway \
            -p 4000:4000 \
            -v "$CONFIG:/app/config.yaml:ro" \
            -e LITELLM_MASTER_KEY=r3-local \
            ghcr.io/berriai/litellm:main-latest \
            --config /app/config.yaml --port 4000 --detailed_debug 2>/dev/null || \
        docker run -d \
            --name r3-litellm \
            --restart unless-stopped \
            --add-host host.docker.internal:host-gateway \
            -p 4000:4000 \
            -v "$CONFIG:/app/config.yaml:ro" \
            -e LITELLM_MASTER_KEY=r3-local \
            ghcr.io/berriai/litellm:latest \
            --config /app/config.yaml --port 4000
    fi

    info "Waiting for LiteLLM to start (max 30s)..."
    if wait_port 4000 30; then
        ok "LiteLLM :4000 live → http://localhost:4000/v1"
    else
        warn "LiteLLM :4000 timeout — check: docker logs r3-litellm"
    fi
fi

# ── STEP 2: Export env for current shell session ──────────────
info "Step 2/3 — Exporting LiteLLM env vars"
export OPENAI_BASE_URL="http://localhost:4000/v1"
export OPENAI_API_BASE="http://localhost:4000/v1"
export OPENAI_API_KEY="r3-local"
export LITELLM_ENDPOINT="http://localhost:4000/v1"
export LITELLM_KEY="r3-local"
export DEFAULT_MODEL="r3/fast"
export CHAT_MODEL="r3/chat"
export CODE_MODEL="r3/code"
export EMBED_MODEL="r3/embed"

# Write .env.litellm for reference
cat > "$REG/.env.litellm" <<'EOF'
# R³ VIB.E — LiteLLM Backend env (auto-written by install-r3-all.sh)
OPENAI_BASE_URL=http://localhost:4000/v1
OPENAI_API_BASE=http://localhost:4000/v1
OPENAI_API_KEY=r3-local
LITELLM_ENDPOINT=http://localhost:4000/v1
LITELLM_KEY=r3-local
DEFAULT_MODEL=r3/fast
CHAT_MODEL=r3/chat
CODE_MODEL=r3/code
EMBED_MODEL=r3/embed
EOF
ok "Env exported + .env.litellm written"

# ── STEP 3: n8n :5678 ────────────────────────────────────────
info "Step 3/3 — n8n Automation :5678"
if test_port 5678; then
    skip "n8n :5678 already running"
else
    N8N_COMPOSE="$REG/n8n-workflows/docker-compose.yml"
    if [ -f "$N8N_COMPOSE" ]; then
        info "Starting n8n via docker compose..."
        docker compose -f "$N8N_COMPOSE" up -d
        if wait_port 5678 30; then
            ok "n8n :5678 live → http://localhost:5678"
        else
            warn "n8n :5678 timeout — check: docker logs n8n"
        fi
    else
        warn "docker-compose.yml not found at $N8N_COMPOSE"
    fi
fi

show_status

# ── Usage hint ────────────────────────────────────────────────
echo "  Quick test (LiteLLM):"
echo "    curl -s http://localhost:4000/v1/chat/completions \\"
echo "      -H 'Authorization: Bearer r3-local' \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"model\":\"r3/fast\",\"messages\":[{\"role\":\"user\",\"content\":\"OK?\"}],\"max_tokens\":5}' \\"
echo "      | python3 -c \"import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'])\""
echo ""
