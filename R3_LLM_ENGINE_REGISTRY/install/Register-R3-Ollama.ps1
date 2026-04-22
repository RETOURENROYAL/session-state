<#
.SYNOPSIS
    R3 Ollama Registry — LiteLLM Registration + Live Health Check
    Registriert alle 20 Ollama-Modelle (RAZER + APPSEN) in LiteLLM
    und testet jede Route mit einem Ping-Chat.

.USAGE
    iwr https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Register-R3-Ollama.ps1 | iex
    ODER lokal:
    C:\Users\mail\R3-DASHBOARD\R3_LLM_ENGINE_REGISTRY\install\Register-R3-Ollama.ps1

.DESCRIPTION
    - Scannt beide Ollama-Nodes (RAZER :11434, APPSEN :11434)
    - Registriert alle gefundenen Modelle in LiteLLM als r3/<task> Routen
    - Testet jede Route
    - Gibt Routing-Übersicht + Copy-Paste Kurzreferenz aus
#>

$ErrorActionPreference = 'Continue'

# ── Config ─────────────────────────────────────────────────────────────────────
$LiteLLM     = "http://localhost:4000"
$LiteLLMKey  = "r3-local"
$RazerUrl    = "http://localhost:11434"
$AppsenUrl   = "http://192.168.1.226:11434"

$RouteMap = @{
  "r3/code"          = @{ model = "ollama_chat/deepseek-coder:6.7b";      base = $RazerUrl; task = "Code / Debug / Refactor" }
  "r3/code-alt"      = @{ model = "ollama_chat/qwen2.5-coder:latest";     base = $RazerUrl; task = "Code (Qwen Coder)" }
  "r3/code-fallback" = @{ model = "ollama_chat/codellama:7b";             base = $RazerUrl; task = "Code (CodeLlama)" }
  "r3/reasoning"     = @{ model = "ollama_chat/deepseek-r1:latest";       base = $RazerUrl; task = "Reasoning / Analysis" }
  "r3/reasoning-alt" = @{ model = "ollama_chat/qwen3:latest";             base = $RazerUrl; task = "Reasoning (Qwen3)" }
  "r3/fast"          = @{ model = "ollama_chat/gemma2:2b";                base = $RazerUrl; task = "Fast / Autocomplete" }
  "r3/fast-alt"      = @{ model = "ollama_chat/qwen2.5:3b";              base = $RazerUrl; task = "Fast (Qwen 3B)" }
  "r3/chat"          = @{ model = "ollama_chat/mistral:latest";           base = $RazerUrl; task = "General Chat" }
  "r3/chat-heavy"    = @{ model = "ollama_chat/qwen2.5:14b";              base = $RazerUrl; task = "Chat Heavy (14B)" }
  "r3/large"         = @{ model = "ollama_chat/mixtral:latest";           base = $RazerUrl; task = "Large Context (46B)" }
  "r3/large-alt"     = @{ model = "ollama_chat/nemotron-cascade-2:latest";base = $RazerUrl; task = "Large (Nemotron 31B)" }
  "r3/autocomplete"  = @{ model = "ollama_chat/phi3:mini";                base = $RazerUrl; task = "Autocomplete" }
  "r3/embed"         = @{ model = "ollama/nomic-embed-text:latest";       base = $AppsenUrl; task = "Embeddings / RAG" }
  "r3/appsen-chat"   = @{ model = "ollama_chat/llama3.2:latest";          base = $AppsenUrl; task = "APPSEN Chat" }
}

function Write-Banner {
  Write-Host ""
  Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
  Write-Host "  ║   R3 OLLAMA REGISTRY — LiteLLM Registration        ║" -ForegroundColor Cyan
  Write-Host "  ║   RAZER (localhost:11434) + APPSEN (192.168.1.226) ║" -ForegroundColor Cyan
  Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
  Write-Host ""
}

function Test-Endpoint($url, $label, [switch]$Silent) {
  try {
    $r = Invoke-WebRequest "$url" -TimeoutSec 3 -UseBasicParsing -EA Stop
    if (-not $Silent) { Write-Host "  ✓ $label — online" -ForegroundColor Green }
    return $true
  } catch {
    if (-not $Silent) { Write-Host "  ✗ $label — offline" -ForegroundColor Red }
    return $false
  }
}

function Get-OllamaModels($baseUrl, $nodeName) {
  try {
    $r = Invoke-RestMethod "$baseUrl/api/tags" -TimeoutSec 5 -EA Stop
    $models = $r.models | ForEach-Object { $_.name }
    Write-Host "  $nodeName : $($models.Count) Modelle geladen" -ForegroundColor Green
    return $models
  } catch {
    Write-Host "  $nodeName : Konnte Modelle nicht abrufen" -ForegroundColor Yellow
    return @()
  }
}

function Register-LiteLLMRoute($name, $model, $apiBase) {
  $body = @{
    model_name = $name
    litellm_params = @{
      model    = $model
      api_base = $apiBase
    }
  } | ConvertTo-Json -Depth 5

  try {
    $r = Invoke-RestMethod "$LiteLLM/model/new" `
      -Method POST `
      -Body $body `
      -ContentType "application/json" `
      -Headers @{ Authorization = "Bearer $LiteLLMKey" } `
      -TimeoutSec 8 -EA Stop
    return "registered"
  } catch {
    $msg = $_.Exception.Message
    if ($msg -match "already exists|409|duplicate") { return "exists" }
    return "error: $($msg.Substring(0,[Math]::Min(60,$msg.Length)))"
  }
}

function Test-LiteLLMRoute($modelName) {
  $body = @{
    model    = $modelName
    messages = @(@{ role = "user"; content = "r3 ping" })
    max_tokens = 5
    stream   = $false
  } | ConvertTo-Json -Depth 5

  try {
    $r = Invoke-RestMethod "$LiteLLM/v1/chat/completions" `
      -Method POST `
      -Body $body `
      -ContentType "application/json" `
      -Headers @{ Authorization = "Bearer $LiteLLMKey" } `
      -TimeoutSec 30 -EA Stop
    $reply = $r.choices[0].message.content.Trim()
    return "✓ OK ($reply)"
  } catch {
    $msg = $_.Exception.Message
    # embedding models return 400 on chat — expected
    if ($msg -match "400|embed" -and $modelName -match "embed") { return "✓ OK (embed-only)" }
    return "✗ $($msg.Substring(0,[Math]::Min(50,$msg.Length)))"
  }
}

# ── MAIN ───────────────────────────────────────────────────────────────────────
Write-Banner

# 1. Ping nodes
Write-Host "[1/4] Node-Erreichbarkeit..." -ForegroundColor White
$razerOnline  = Test-Endpoint "$RazerUrl/api/tags"  "RAZER  localhost:11434"
$appsenOnline = Test-Endpoint "$AppsenUrl/api/tags" "APPSEN 192.168.1.226:11434"
$litellmOnline= Test-Endpoint "$LiteLLM/health"    "LiteLLM localhost:4000"
Write-Host ""

if (-not $litellmOnline) {
  Write-Host "  ⚠  LiteLLM offline — versuche Auto-Start..." -ForegroundColor Yellow

  # Try 1: Named service in R3-DASHBOARD docker-compose
  $R3Root = "C:\Users\mail\R3-DASHBOARD"
  $ComposeFile = "$R3Root\docker\docker-compose.yml"
  $Started = $false

  if (Test-Path $ComposeFile) {
    Write-Host "  ▶ docker compose -f $ComposeFile up litellm -d" -ForegroundColor DarkGray
    docker compose -f $ComposeFile up litellm -d 2>&1 | Out-Null
    $Started = $true
  } else {
    # Try 2: generic compose in R3-DASHBOARD root
    $RootCompose = "$R3Root\docker-compose.yml"
    if (Test-Path $RootCompose) {
      Write-Host "  ▶ docker compose -f $RootCompose up litellm -d" -ForegroundColor DarkGray
      docker compose -f $RootCompose up litellm -d 2>&1 | Out-Null
      $Started = $true
    } else {
      # Try 3: standalone LiteLLM container (minimal, no config needed for Ollama-only)
      Write-Host "  ▶ Starte standalone LiteLLM container auf :4000..." -ForegroundColor DarkGray
      docker run -d --name r3-litellm `
        -p 4000:4000 `
        -e LITELLM_MASTER_KEY="r3-local" `
        ghcr.io/berriai/litellm:main-latest `
        --port 4000 2>&1 | Out-Null
      $Started = $true
    }
  }

  if ($Started) {
    Write-Host "  ⏳ Warte auf LiteLLM (max 30s)..." -ForegroundColor DarkGray
    $waited = 0
    do {
      Start-Sleep -Seconds 3
      $waited += 3
      $litellmOnline = Test-Endpoint "$LiteLLM/health" "LiteLLM localhost:4000" -Silent
    } while (-not $litellmOnline -and $waited -lt 30)
  }

  if (-not $litellmOnline) {
    Write-Host "  ✗ LiteLLM konnte nicht gestartet werden." -ForegroundColor Red
    Write-Host "    Manuell starten:" -ForegroundColor DarkGray
    Write-Host "      cd C:\Users\mail\R3-DASHBOARD\docker && docker compose up litellm -d" -ForegroundColor DarkGray
    Write-Host "    Danach erneut ausführen: .\Register-R3-Ollama.ps1" -ForegroundColor DarkGray
  }
}

# 2. Scan live models
Write-Host "[2/4] Modelle scannen..." -ForegroundColor White
$razerModels  = if ($razerOnline)  { Get-OllamaModels $RazerUrl  "RAZER" }  else { @() }
$appsenModels = if ($appsenOnline) { Get-OllamaModels $AppsenUrl "APPSEN" } else { @() }
Write-Host ""

# 3. Register routes in LiteLLM
Write-Host "[3/4] LiteLLM Routen registrieren..." -ForegroundColor White
$results = @{}
foreach ($name in $RouteMap.Keys | Sort-Object) {
  $route   = $RouteMap[$name]
  $rawModel = $route.model -replace "ollama_chat/","" -replace "ollama/",""
  $nodeUp  = if ($route.base -eq $RazerUrl) { $razerOnline } else { $appsenOnline }
  $hasModel= if ($route.base -eq $RazerUrl) { $razerModels -contains $rawModel } else { $appsenModels -contains $rawModel }

  if (-not $litellmOnline) {
    $status = "skipped (LiteLLM offline)"
  } elseif (-not $nodeUp) {
    $status = "skipped (node offline)"
  } elseif (-not $hasModel) {
    $status = "skipped (model not found on node)"
  } else {
    $status = Register-LiteLLMRoute $name $route.model $route.base
  }

  $results[$name] = $status
  $col = if ($status -match "registered|exists") { "Green" } elseif ($status -match "skipped") { "Yellow" } else { "Red" }
  Write-Host ("    {0,-20} {1,-38} → {2}" -f $name, $route.model.Substring(0,[Math]::Min(36,$route.model.Length)), $status) -ForegroundColor $col
}
Write-Host ""

# 4. Live route test (optional — only if LiteLLM is up)
if ($litellmOnline) {
  Write-Host "[4/4] Routen testen (Ping-Chat)..." -ForegroundColor White
  Write-Host "      (Überspringe large-Modelle um Zeit zu sparen)" -ForegroundColor DarkGray
  $skipTest = @("r3/large","r3/large-alt")
  foreach ($name in $RouteMap.Keys | Sort-Object) {
    if ($results[$name] -notmatch "registered|exists") { continue }
    if ($skipTest -contains $name) {
      Write-Host ("    {0,-20} → skipped (large model)" -f $name) -ForegroundColor DarkGray
      continue
    }
    $ping = Test-LiteLLMRoute $name
    $col  = if ($ping -match "^✓") { "Green" } else { "Red" }
    Write-Host ("    {0,-20} → {1}" -f $name, $ping) -ForegroundColor $col
  }
  Write-Host ""
}

# ── Summary & Quick Reference ──────────────────────────────────────────────────
Write-Host "  ┌─────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "  │ R3 ROUTING KURZREFERENZ — via http://localhost:4000/v1     │" -ForegroundColor Cyan
Write-Host "  │ apiKey: r3-local                                           │" -ForegroundColor Cyan
Write-Host "  ├─────────────────────────────────────────────────────────────┤" -ForegroundColor Cyan
$tableData = @(
  @{ Task="Code / Debug";        Model="r3/code";         Note="deepseek-coder:6.7b (RAZER)" }
  @{ Task="Reasoning";           Model="r3/reasoning";    Note="deepseek-r1:latest (RAZER)"  }
  @{ Task="Fast / Quick";        Model="r3/fast";         Note="gemma2:2b (RAZER)"           }
  @{ Task="General Chat";        Model="r3/chat";         Note="mistral:latest (RAZER)"      }
  @{ Task="14B Heavy";           Model="r3/chat-heavy";   Note="qwen2.5:14b (RAZER)"         }
  @{ Task="Large Context";       Model="r3/large";        Note="mixtral 46.7B (RAZER)"       }
  @{ Task="Autocomplete";        Model="r3/autocomplete"; Note="phi3:mini (RAZER)"           }
  @{ Task="Embeddings / RAG";    Model="r3/embed";        Note="nomic-embed-text (APPSEN)"   }
  @{ Task="APPSEN Light";        Model="r3/appsen-chat";  Note="llama3.2:3B (APPSEN)"        }
)
foreach ($r in $tableData) {
  Write-Host ("  │  {0,-20} {1,-18} {2,-20}│" -f $r.Task, $r.Model, $r.Note) -ForegroundColor White
}
Write-Host "  └─────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host ""
Write-Host "  EMBEDDING (RAG): POST http://localhost:4000/v1/embeddings" -ForegroundColor Magenta
Write-Host '  body: { "model": "r3/embed", "input": "dein text" }' -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Registry JSON: R3_LLM_ENGINE_REGISTRY\config\ollama-registry.json" -ForegroundColor DarkGray
Write-Host ""
