#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# R3 n8n GitHub API Stack — Install Script (Linux/Mac/Codespace)
# Usage: curl -fsSL https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/install-r3-n8n.sh | bash
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY"
TARGET_DIR="${HOME}/.r3-n8n"
WF_DIR="${TARGET_DIR}/workflows"
DASH_DIR="${TARGET_DIR}/dashboard"

echo ""
echo "  ██████╗ ██████╗     ███╗   ██╗ █████╗ ███╗   ██╗"
echo "  ██╔══██╗╚════██╗    ████╗  ██║██╔══██╗████╗  ██║"
echo "  ██████╔╝ █████╔╝    ██╔██╗ ██║╚█████╔╝██╔██╗ ██║"
echo "  ██╔══██╗ ╚═══██╗    ██║╚██╗██║██╔══██╗██║╚██╗██║"
echo "  ██║  ██║██████╔╝    ██║ ╚████║╚█████╔╝██║ ╚████║"
echo "  ╚═╝  ╚═╝╚═════╝     ╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═══╝"
echo ""
echo "  GitHub API n8n Stack Installer"
echo "  Target: ${TARGET_DIR}"
echo ""

mkdir -p "${WF_DIR}" "${DASH_DIR}"

# ── Download dashboard ────────────────────────────────────────────────────────
echo "[1/4] Downloading dashboard..."
curl -fsSL "${REPO_RAW}/dashboard/index.html" -o "${DASH_DIR}/index.html"
echo "      ✓ dashboard/index.html"

# ── Download universal workflow ───────────────────────────────────────────────
echo "[2/4] Downloading universal workflow..."
curl -fsSL "${REPO_RAW}/n8n-workflows/n8n-github-universal.json" -o "${WF_DIR}/n8n-github-universal.json"
echo "      ✓ n8n-github-universal.json"

# ── Download all individual workflows ─────────────────────────────────────────
echo "[3/4] Downloading individual workflows..."
WORKFLOWS=(
  wf-workflow-runs-list wf-workflow-runs-trigger wf-workflow-runs-cancel wf-workflow-runs-rerun
  wf-secrets-repo-list wf-secrets-repo-pubkey wf-secrets-org-list
  wf-runners-self-list-repo wf-runners-self-list-org wf-runners-self-reg-token
  wf-runners-hosted-list wf-runners-hosted-images
  wf-runner-groups-list wf-runner-groups-create
  wf-codespaces-list wf-codespaces-start wf-codespaces-stop wf-codespaces-secrets-list
  wf-git-refs-list wf-git-blob-create wf-git-commit-create
  wf-orgs-members-list wf-orgs-repos-list wf-orgs-audit-log
  wf-auth-rate-limit wf-auth-user wf-installations-list
)
for wf in "${WORKFLOWS[@]}"; do
  curl -fsSL "${REPO_RAW}/n8n-workflows/workflows/${wf}.json" -o "${WF_DIR}/${wf}.json" \
    && echo "      ✓ ${wf}.json" \
    || echo "      ✗ FAILED: ${wf}.json"
done

# ── Download config reference ─────────────────────────────────────────────────
echo "[4/4] Downloading endpoint reference..."
curl -fsSL "${REPO_RAW}/config/github-api-endpoints.json" -o "${TARGET_DIR}/github-api-endpoints.json"
echo "      ✓ github-api-endpoints.json"

# ── Write docker-compose ──────────────────────────────────────────────────────
cat > "${TARGET_DIR}/docker-compose.yml" << 'DCEOF'
version: "3.8"
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: r3-n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=false
      - WEBHOOK_URL=http://localhost:5678
      - GENERIC_TIMEZONE=Europe/Berlin
      - N8N_DEFAULT_LOCALE=de
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GITHUB_PERSONAL_ACCESS_TOKEN=${GITHUB_TOKEN}
    volumes:
      - n8n_data:/home/node/.n8n
      - ./workflows:/workflows:ro
volumes:
  n8n_data:
DCEOF

# ── Set GITHUB_TOKEN if not set ───────────────────────────────────────────────
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo ""
  echo "  ⚠  GITHUB_TOKEN is not set."
  echo "     Set it before starting n8n:"
  echo "     export GITHUB_TOKEN=ghp_..."
  echo ""
fi

# ── Start n8n ─────────────────────────────────────────────────────────────────
echo ""
read -rp "  ▶ n8n jetzt starten? (Docker required) [y/N] " START
if [[ "${START,,}" == "y" ]]; then
  cd "${TARGET_DIR}"
  docker compose up -d
  sleep 5
  echo "  ✓ n8n läuft auf http://localhost:5678"
  echo "  ✓ Dashboard: open ${DASH_DIR}/index.html"
  # Try to open browser
  command -v xdg-open &>/dev/null && xdg-open "${DASH_DIR}/index.html" || true
  command -v open &>/dev/null && open "${DASH_DIR}/index.html" || true
else
  echo ""
  echo "  Manuelle Schritte:"
  echo "    cd ${TARGET_DIR}"
  echo "    export GITHUB_TOKEN=ghp_..."
  echo "    docker compose up -d"
  echo "    open ${DASH_DIR}/index.html"
fi

echo ""
echo "  ═══════════════════════════════════════════════════"
echo "  ✓ Installation abgeschlossen"
echo "  📁 Dateien: ${TARGET_DIR}"
echo "  🌐 Dashboard: ${DASH_DIR}/index.html"
echo "  🔗 n8n: http://localhost:5678"
echo "  ═══════════════════════════════════════════════════"
