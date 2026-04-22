#!/usr/bin/env bash
# test-all-engines.sh — R3 LLM Engine Healthcheck
# Tests all engines via LiteLLM Gateway (localhost:4000)
# Usage: bash scripts/test-all-engines.sh [--verbose]
# Requires: curl, jq (optional for pretty output)

set -euo pipefail

BASE_URL="http://localhost:4000/v1"
API_KEY="r3-local"
PROMPT="Say 'OK' in one word."
VERBOSE=false
PASS=0
FAIL=0

[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

log()     { echo "[$(date +%H:%M:%S)] $*"; }
ok()      { echo "  ✅ $*"; ((PASS++)) || true; }
fail()    { echo "  ❌ $*"; ((FAIL++)) || true; }

test_model() {
  local label="$1"
  local model="$2"

  $VERBOSE && log "Testing: $label ($model)"

  local http_code
  http_code=$(curl -s -o /tmp/r3_test_resp.json -w "%{http_code}" \
    -X POST "$BASE_URL/chat/completions" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"$PROMPT\"}],\"max_tokens\":10}" \
    --max-time 30 2>&1 || echo "000")

  if [[ "$http_code" == "200" ]]; then
    ok "$label"
    $VERBOSE && cat /tmp/r3_test_resp.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('    →',d['choices'][0]['message']['content'].strip())" 2>/dev/null || true
  else
    fail "$label (HTTP $http_code)"
    $VERBOSE && cat /tmp/r3_test_resp.json 2>/dev/null || true
  fi
}

test_ollama() {
  local label="$1"
  local host="$2"
  local model="$3"

  $VERBOSE && log "Testing Ollama: $label ($host)"

  local http_code
  http_code=$(curl -s -o /tmp/r3_ollama_resp.json -w "%{http_code}" \
    -X POST "$host/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$model\",\"prompt\":\"$PROMPT\",\"stream\":false}" \
    --max-time 30 2>&1 || echo "000")

  if [[ "$http_code" == "200" ]]; then
    ok "$label"
  else
    fail "$label (HTTP $http_code — may be offline)"
  fi
}

echo ""
echo "══════════════════════════════════════════"
echo "  R3 Engine Registry — Full Healthcheck"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "══════════════════════════════════════════"

echo ""
echo "── LiteLLM Gateway (:4000) ─────────────"
gateway_status=$(curl -sf -H "Authorization: Bearer $API_KEY" http://localhost:4000/health 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"healthy:{d.get('healthy_count',0)} unhealthy:{d.get('unhealthy_count',0)}\")" 2>/dev/null || echo "UNREACHABLE")
echo "  Gateway: $gateway_status"

echo ""
echo "── Free Engines (via LiteLLM) ──────────"
test_model "Groq Llama 3.3 70B"         "groq/llama-3.3-70b"
test_model "Groq Llama 3.1 8B"          "groq/llama-3.1-8b"
test_model "Cerebras Llama 3.3 70B"     "cerebras/llama-3.3-70b"
test_model "SambaNova Llama 3.3 70B"    "sambanova/llama-3.3-70b"
test_model "OpenRouter Auto"            "openrouter/auto"

echo ""
echo "── Local Engines (Ollama) ──────────────"
test_ollama "Ollama RAZER — gemma2:2b"   "http://host.docker.internal:11434" "gemma2:2b"
test_ollama "Ollama appsen — llama3.2"   "http://192.168.1.226:11434"        "llama3.2"

echo ""
echo "── Paid Engines (via LiteLLM) ──────────"
test_model "GPT-4o"                     "gpt-4o"
test_model "Claude 3.5 Sonnet"          "claude-3-5-sonnet"
test_model "Gemini 2.0 Flash"           "gemini-2.0-flash"

echo ""
echo "══════════════════════════════════════════"
echo "  Results: ✅ $PASS passed   ❌ $FAIL failed"
echo "══════════════════════════════════════════"
echo ""

[[ $FAIL -gt 0 ]] && exit 1 || exit 0
