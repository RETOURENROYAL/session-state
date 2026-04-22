# test-all-engines.ps1 — R3 LLM Engine Healthcheck (PowerShell / RAZER)
# Tests all engines via LiteLLM Gateway and direct Ollama endpoints
# Usage: .\scripts\test-all-engines.ps1 [-Verbose]
# Requires: PowerShell 5.1+ or pwsh

param(
  [switch]$Verbose
)

$BASE_URL = "http://localhost:4000/v1"
$API_KEY  = "r3-local"
$PROMPT   = "Say 'OK' in one word."
$Pass     = 0
$Fail     = 0

function Log($msg) { Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" }

function Test-Model {
  param($Label, $Model)
  if ($Verbose) { Log "Testing: $Label ($Model)" }
  try {
    $body = @{
      model    = $Model
      messages = @(@{ role = "user"; content = $PROMPT })
      max_tokens = 10
    } | ConvertTo-Json -Depth 5

    $resp = Invoke-RestMethod `
      -Uri "$BASE_URL/chat/completions" `
      -Method POST `
      -Headers @{ Authorization = "Bearer $API_KEY"; "Content-Type" = "application/json" } `
      -Body $body `
      -TimeoutSec 30

    Write-Host "  ✅ $Label" -ForegroundColor Green
    if ($Verbose) {
      Write-Host "    → $($resp.choices[0].message.content.Trim())" -ForegroundColor DarkGray
    }
    $script:Pass++
  }
  catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "  ❌ $Label (HTTP $code)" -ForegroundColor Red
    $script:Fail++
  }
}

function Test-Ollama {
  param($Label, $Host, $Model)
  if ($Verbose) { Log "Testing Ollama: $Label ($Host)" }
  try {
    $body = @{ model = $Model; prompt = $PROMPT; stream = $false } | ConvertTo-Json

    $resp = Invoke-RestMethod `
      -Uri "$Host/api/generate" `
      -Method POST `
      -Headers @{ "Content-Type" = "application/json" } `
      -Body $body `
      -TimeoutSec 30

    Write-Host "  ✅ $Label" -ForegroundColor Green
    $script:Pass++
  }
  catch {
    Write-Host "  ❌ $Label (may be offline)" -ForegroundColor Yellow
    $script:Fail++
  }
}

Write-Host ""
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  R3 Engine Registry — Full Healthcheck"   -ForegroundColor Cyan
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan

Write-Host ""
Write-Host "── LiteLLM Gateway (:4000) ─────────────" -ForegroundColor DarkCyan
try {
  $gw = Invoke-RestMethod -Uri "http://localhost:4000/health" `
    -Headers @{ Authorization = "Bearer $API_KEY" } -TimeoutSec 10
  Write-Host "  Gateway: healthy:$($gw.healthy_count) unhealthy:$($gw.unhealthy_count)" -ForegroundColor Green
} catch {
  Write-Host "  Gateway: UNREACHABLE — start LiteLLM first!" -ForegroundColor Red
}

Write-Host ""
Write-Host "── Free Engines (via LiteLLM) ──────────" -ForegroundColor DarkCyan
Test-Model "Groq Llama 3.3 70B"       "groq/llama-3.3-70b"
Test-Model "Groq Llama 3.1 8B"        "groq/llama-3.1-8b"
Test-Model "Cerebras Llama 3.3 70B"   "cerebras/llama-3.3-70b"
Test-Model "SambaNova Llama 3.3 70B"  "sambanova/llama-3.3-70b"
Test-Model "OpenRouter Auto"          "openrouter/auto"

Write-Host ""
Write-Host "── Local Engines (Ollama) ──────────────" -ForegroundColor DarkCyan
Test-Ollama "Ollama RAZER — gemma2:2b"  "http://localhost:11434"       "gemma2:2b"
Test-Ollama "Ollama appsen — llama3.2"  "http://192.168.1.226:11434"   "llama3.2"

Write-Host ""
Write-Host "── Paid Engines (via LiteLLM) ──────────" -ForegroundColor DarkCyan
Test-Model "GPT-4o"            "gpt-4o"
Test-Model "Claude 3.5 Sonnet" "claude-3-5-sonnet"
Test-Model "Gemini 2.0 Flash"  "gemini-2.0-flash"

Write-Host ""
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
$passColor = if ($Pass -gt 0) { "Green" } else { "Gray" }
$failColor = if ($Fail -gt 0) { "Red" }  else { "Gray" }
Write-Host "  Results: " -NoNewline
Write-Host "✅ $Pass passed" -ForegroundColor $passColor -NoNewline
Write-Host "   " -NoNewline
Write-Host "❌ $Fail failed" -ForegroundColor $failColor
Write-Host "══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

exit $Fail
