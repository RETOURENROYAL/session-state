#Requires -Version 5.1
<#
.SYNOPSIS
  R³|VIB.E — Free Coding Multi-Boost Team Setup
  Fixes WSL2 access + installs aider + sets up multi-agent LiteLLM routing

.DESCRIPTION
  Löst drei Probleme auf einmal:
  1. r-vib3/.env.local PORT=8420 Konflikt → wird entfernt
  2. WSL2 → Windows Port-Zugriff → .wslconfig mirrored networking
  3. Free 24/7 Coding Agent (aider) → via LiteLLM Gateway :4000

.USAGE
  iex (iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Setup-R3-CodingTeam.ps1").Content

  Or locally:
  powershell -ExecutionPolicy Bypass -File "C:\Users\mail\R3-DASHBOARD\R3_LLM_ENGINE_REGISTRY\install\Setup-R3-CodingTeam.ps1"
#>

param(
  [string]$R3Root      = "C:\Users\mail\R3-DASHBOARD",
  [string]$LiteLLMUrl  = "http://localhost:4000/v1",
  [string]$LiteLLMKey  = "r3-local"
)

$ErrorActionPreference = "Stop"
$Width = 90

function Write-Banner {
  param([string]$Title, [string]$Color = "Cyan")
  $line = "#" * $Width
  Write-Host "`n$line" -ForegroundColor $Color
  Write-Host "##  $Title" -ForegroundColor $Color
  Write-Host $line -ForegroundColor $Color
}

function Write-Step {
  param([string]$Msg, [string]$Color = "Yellow")
  Write-Host "`n  ► $Msg" -ForegroundColor $Color
}

function Write-OK  { param([string]$Msg) Write-Host "  ✓ $Msg" -ForegroundColor Green }
function Write-ERR { param([string]$Msg) Write-Host "  ✗ $Msg" -ForegroundColor Red }
function Write-INF { param([string]$Msg) Write-Host "  • $Msg" -ForegroundColor Gray }

# ─────────────────────────────────────────────────────────────
Write-Banner "R³|VIB.E  FREE CODING MULTI-BOOST TEAM SETUP" "Magenta"
Write-Host ""
Write-INF "Root:        $R3Root"
Write-INF "LiteLLM:     $LiteLLMUrl"
Write-INF "Started:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# ═══════════════════════════════════════════════════════════════
# BLOCK 1 — FIX r-vib3 PORT CONFLICT
# ═══════════════════════════════════════════════════════════════
Write-Banner "BLOCK 1 — FIX r-vib3 PORT CONFLICT"

$envLocal = Join-Path $R3Root "r-vib3\.env.local"
if (Test-Path $envLocal) {
  $content = Get-Content $envLocal -Raw
  if ($content -match "PORT=") {
    Write-Step "Removing PORT= from r-vib3/.env.local (conflicts with ChatLegs :8420)"
    $fixed = ($content -split "`n" | Where-Object { $_ -notmatch "^PORT=" }) -join "`n"
    $fixed | Set-Content $envLocal -Encoding UTF8 -NoNewline
    Write-OK ".env.local cleaned — PORT= removed"
  } else {
    Write-OK ".env.local OK — no PORT conflict found"
  }
} else {
  Write-INF "r-vib3/.env.local not found — skipping"
}

# Fix package.json dev:ui port
$pkgJson = Join-Path $R3Root "r-vib3\package.json"
if (Test-Path $pkgJson) {
  Write-Step "Ensuring r-vib3/package.json dev:ui uses port 3333"
  $pkg = Get-Content $pkgJson -Raw | ConvertFrom-Json
  $devUi = $pkg.scripts."dev:ui"
  if ($devUi -and $devUi -notmatch "\-p \d+") {
    $pkg.scripts."dev:ui" = $devUi -replace "next dev", "next dev -p 3333"
    $pkg | ConvertTo-Json -Depth 20 | Set-Content $pkgJson -Encoding UTF8
    Write-OK "dev:ui → port 3333 added"
  } elseif ($devUi -match "\-p 8\d{3}") {
    $pkg.scripts."dev:ui" = $devUi -replace "\-p 8\d{3}", "-p 3333"
    $pkg | ConvertTo-Json -Depth 20 | Set-Content $pkgJson -Encoding UTF8
    Write-OK "dev:ui → port replaced with 3333"
  } else {
    Write-OK "dev:ui port already set: $devUi"
  }
}

# ═══════════════════════════════════════════════════════════════
# BLOCK 2 — FIX WSL2 NETWORKING (mirrored mode)
# ═══════════════════════════════════════════════════════════════
Write-Banner "BLOCK 2 — WSL2 MIRRORED NETWORKING FIX"
Write-INF "Problem: WSL2 hat eigenes Netz → localhost:8420 in WSL ≠ Windows :8420"
Write-INF "Fix: .wslconfig networkingMode=mirrored → WSL2 teilt Windows-Netz"

$wslConfig = "$env:USERPROFILE\.wslconfig"
$mirroredConfig = @"
# R3|VIB.E WSL2 Mirrored Networking
# Ermöglicht localhost-Zugriff auf Windows-Ports aus WSL2
[wsl2]
networkingMode=mirrored
dnsTunneling=true
firewall=true
autoProxy=true

[experimental]
autoMemoryReclaim=gradual
"@

$needsRestart = $false
if (Test-Path $wslConfig) {
  $existing = Get-Content $wslConfig -Raw
  if ($existing -match "networkingMode=mirrored") {
    Write-OK ".wslconfig already has mirrored networking"
  } else {
    # Backup
    Copy-Item $wslConfig "$wslConfig.bak" -Force
    Write-INF "Backup: $wslConfig.bak"

    if ($existing -match "\[wsl2\]") {
      # Patch existing
      $patched = $existing -replace "(\[wsl2\])", "`$1`nnetworkingMode=mirrored`ndnsTunneling=true"
      $patched | Set-Content $wslConfig -Encoding UTF8
    } else {
      # Append
      Add-Content $wslConfig -Value "`n$mirroredConfig"
    }
    Write-OK ".wslconfig patched → networkingMode=mirrored"
    $needsRestart = $true
  }
} else {
  $mirroredConfig | Set-Content $wslConfig -Encoding UTF8
  Write-OK ".wslconfig created with mirrored networking"
  $needsRestart = $true
}

if ($needsRestart) {
  Write-Host "`n  ⚠  WSL2 muss neu gestartet werden:" -ForegroundColor Yellow
  Write-Host "     wsl --shutdown" -ForegroundColor Cyan
  Write-Host "     Dann WSL neu öffnen → localhost:8420 funktioniert" -ForegroundColor Cyan

  $choice = Read-Host "`n  WSL jetzt herunterfahren? (y/n)"
  if ($choice -eq 'y') {
    wsl --shutdown
    Write-OK "WSL heruntergefahren. Beim nächsten WSL-Start ist localhost erreichbar."
  }
}

# Windows Host IP für WSL (Fallback wenn kein reboot)
Write-Step "Windows Host IP für WSL (Sofort-Fallback):"
try {
  $winIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.InterfaceAlias -match "WSL" -and $_.IPAddress -ne "127.0.0.1"
  } | Select-Object -First 1).IPAddress
  if (-not $winIp) {
    $winIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
      $_.InterfaceAlias -notmatch "Loopback|Hyper-V" -and
      $_.IPAddress -notmatch "^169\." -and
      $_.IPAddress -ne "127.0.0.1"
    } | Select-Object -First 1).IPAddress
  }
  if ($winIp) {
    Write-OK "Windows IP: $winIp"
    Write-INF "In WSL nutzen: curl http://${winIp}:8420/api/health"
  }
} catch {
  Write-INF "IP-Ermittlung nicht möglich"
}

# ═══════════════════════════════════════════════════════════════
# BLOCK 3 — CHECK LiteLLM GATEWAY
# ═══════════════════════════════════════════════════════════════
Write-Banner "BLOCK 3 — LiteLLM GATEWAY CHECK"

Write-Step "Prüfe LiteLLM auf :4000..."
# TCP-Check ist zuverlässiger als HTTP — kein Endpoint-Mismatch
$liteLLMRunning = $false
try {
  $tcpClient = New-Object System.Net.Sockets.TcpClient
  $tcpClient.Connect("127.0.0.1", 4000)
  $tcpClient.Close()
  $liteLLMRunning = $true
  Write-OK "LiteLLM läuft auf :4000 ✓ (TCP-Check)"
} catch {
  $liteLLMRunning = $false
}

if (-not $liteLLMRunning) {
  Write-ERR "LiteLLM nicht erreichbar auf :4000"
  Write-INF "Starte LiteLLM..."
  try {
    $startScript = Join-Path $R3Root "R3_LLM_ENGINE_REGISTRY\install\Start-R3-LiteLLM.ps1"
    if (Test-Path $startScript) {
      & $startScript
    } else {
      & ([scriptblock]::Create((iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Start-R3-LiteLLM.ps1?r=$(Get-Random)").Content))
    }
  } catch {
    Write-ERR "LiteLLM-Start fehlgeschlagen: $($_.Exception.Message)"
  }
}

# ═══════════════════════════════════════════════════════════════
# BLOCK 4 — INSTALL AIDER (Free Coding Agent)
# ═══════════════════════════════════════════════════════════════
Write-Banner "BLOCK 4 — AIDER FREE CODING AGENT INSTALL"
Write-INF "aider = open-source Claude/GPT coding agent → kostenlos via LiteLLM+Groq/Ollama"
Write-INF "Dokumentation: https://aider.chat"

# Check Python
$pythonCmd = $null
foreach ($cmd in @("python", "python3", "py")) {
  try {
    $v = & $cmd --version 2>&1
    if ($v -match "Python 3\.\d+") {
      $pythonCmd = $cmd
      Write-OK "Python gefunden: $v ($cmd)"
      break
    }
  } catch {}
}

if (-not $pythonCmd) {
  Write-ERR "Python nicht gefunden — aider benötigt Python 3.10+"
  Write-INF "Install: https://www.python.org/downloads/"
} else {
  # Install/upgrade aider
  Write-Step "Installiere/aktualisiere aider-chat..."
  try {
    $pip = & $pythonCmd -m pip install --upgrade aider-chat --quiet 2>&1
    Write-OK "aider-chat installiert/aktuell"
  } catch {
    Write-ERR "aider-Installation fehlgeschlagen: $($_.Exception.Message)"
  }
}

# Aider config — Default: Ollama lokal (kein API-Key nötig)
# Groq via openai/ Prefix möglich wenn GROQ_API_KEY gesetzt: --model openai/groq/llama-3.3-70b-versatile
$aiderConfig = @{
  "ollama-api-base"  = "http://localhost:11434"
  "model"            = "ollama/deepseek-coder:6.7b"
  "weak-model"       = "ollama/gemma2:2b"
  "editor-model"     = "ollama/qwen2.5-coder:latest"
  "no-auto-commits"  = $true
  "stream"           = $true
  "pretty"           = $true
  "vim"              = $false
  "watch-files"      = $false
}

$aiderYaml = Join-Path $R3Root ".aider.conf.yml"
$yamlLines = @("# R3|VIB.E aider config — Free Coding Team via LiteLLM", "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')", "")
foreach ($kv in $aiderConfig.GetEnumerator()) {
  $val = $kv.Value
  if ($val -is [bool]) { $val = if ($val) { "true" } else { "false" } }
  $yamlLines += "$($kv.Key): $val"
}
$yamlLines -join "`n" | Set-Content $aiderYaml -Encoding UTF8
Write-OK "Aider config: $aiderYaml"

# ═══════════════════════════════════════════════════════════════
# BLOCK 5 — MULTI-AGENT LiteLLM ROUTING CONFIG
# ═══════════════════════════════════════════════════════════════
Write-Banner "BLOCK 5 — CODING TEAM ROUTING CONFIG"

$teamConfig = @"
# ══════════════════════════════════════════════════════════════
# R³|VIB.E FREE CODING MULTI-BOOST TEAM
# Alle Routes über http://localhost:4000/v1  Key: r3-local
# ══════════════════════════════════════════════════════════════
#
#  ROLE              ROUTE                    ENGINE
#  ─────────────────────────────────────────────────────────────
#  Lead Coder        r3/code                  deepseek-coder:6.7b (Ollama, local)
#  Code Review       r3/code-alt              qwen2.5-coder (Ollama, local)
#  Fast Debug        r3/fast                  gemma2:2b (Ollama, 1.5GB, ultra-fast)
#  Heavy Reasoning   r3/reasoning             deepseek-r1 (Ollama, lokal)
#  Groq Fallback     groq/llama-3.3-70b       Groq Free Tier (14400 req/day)
#  Research          r3/large                 mixtral:46.7B (Ollama, lokal)
#  Embedding/RAG     r3/embed                 nomic-embed-text (APPSEN)
#
#  ► VERWENDUNG IN TERMINAL:
#     aider --model groq/llama-3.3-70b-versatile
#     aider --model ollama/deepseek-coder:6.7b
#     aider --model ollama/qwen2.5-coder:latest
#
#  ► VERWENDUNG IN PYTHON/NODE:
#     base_url = "http://localhost:4000/v1"
#     api_key  = "r3-local"
#     model    = "r3/code"          # routes to deepseek-coder
#     model    = "r3/reasoning"     # routes to deepseek-r1
#     model    = "r3/fast"          # routes to gemma2:2b
#
#  ► VERWENDUNG MIT CLAUDE CODE CLI (free via Groq backend):
#     set ANTHROPIC_BASE_URL=http://localhost:4000/v1
#     set ANTHROPIC_API_KEY=r3-local
#     claude                         # nutzt jetzt LiteLLM → Groq/Ollama
#
#  ► KOSTEN: $0 (alles Free-Tier oder Local)
# ══════════════════════════════════════════════════════════════
"@

$teamReadme = Join-Path $R3Root "R3_LLM_ENGINE_REGISTRY\CODING-TEAM.md"
$teamConfig | Set-Content $teamReadme -Encoding UTF8
Write-OK "Coding Team Readme: $teamReadme"

# Wrapper script für schnellen Einstieg
$aiderLaunch = @"
@echo off
:: R3|VIB.E Coding Team — Quick Launch
:: Default: qwen2.5-coder (Instruction-tuned, Chat + Code, kein API-Key)
:: MODELLE:
::   (default)  qwen2.5-coder:latest  — Chat + Code erklären + schreiben
::   chat       mistral:latest        — Allgemeine Fragen / Erklärungen
::   fast       gemma2:2b             — Ultra-schnell, einfache Tasks
::   heavy      deepseek-r1:latest    — Reasoning / Analyse
::   large      qwen2.5:14b           — Große Kontexte / komplexe Tasks
::   groq       groq/llama-3.3-70b    — Via LiteLLM Gateway (benötigt localhost:4000)

set PATH=%USERPROFILE%\.local\bin;%PATH%
set OLLAMA_API_BASE=http://localhost:11434

if "%1"==""        aider --model ollama/qwen2.5-coder:latest
if "%1"=="chat"    aider --model ollama/mistral:latest
if "%1"=="fast"    aider --model ollama/gemma2:2b
if "%1"=="heavy"   aider --model ollama/deepseek-r1:latest
if "%1"=="large"   aider --model ollama/qwen2.5:14b
if "%1"=="groq"    aider --model openai/groq/llama-3.3-70b-versatile --openai-api-base http://localhost:4000/v1 --openai-api-key r3-local
"@
$batPath = Join-Path $R3Root "r3-code.bat"
$aiderLaunch | Set-Content $batPath -Encoding ASCII
Write-OK "Quick-launch: $batPath"
Write-INF "  r3-code.bat          → qwen2.5-coder (Chat + Code, Standard)"
Write-INF "  r3-code.bat chat     → mistral (Erklaerungen / allg. Chat)"
Write-INF "  r3-code.bat fast     → gemma2:2b (ultra-schnell)"
Write-INF "  r3-code.bat heavy    → deepseek-r1 (Reasoning)"
Write-INF "  r3-code.bat coder    → qwen2.5-coder"

# ═══════════════════════════════════════════════════════════════
# BLOCK 6 — CLAUDE CODE CLI FREE SETUP
# ═══════════════════════════════════════════════════════════════
Write-Banner "BLOCK 6 — CLAUDE CODE CLI → FREE BACKEND"
Write-INF "Claude Code CLI = Anthropic-Tool (normalerweise kostenpflichtig)"
Write-INF "Trick: ANTHROPIC_BASE_URL → LiteLLM :4000 → Groq/Ollama (KOSTENLOS)"

$claudeEnv = @"
# R3|VIB.E — Claude Code CLI → Free LiteLLM Backend
# In PowerShell ausführen BEVOR claude gestartet wird:

`$env:ANTHROPIC_BASE_URL = "http://localhost:4000/v1"
`$env:ANTHROPIC_API_KEY  = "r3-local"

# Dann einfach:
# claude
# oder für specifisches Modell:
# CLAUDE_MODEL="groq/llama-3.3-70b-versatile" claude
"@

$claudeSetup = Join-Path $R3Root "R3_LLM_ENGINE_REGISTRY\claude-free-setup.ps1"
$claudeEnv | Set-Content $claudeSetup -Encoding UTF8
Write-OK "Claude free setup: $claudeSetup"
Write-INF "Ausführen: . $claudeSetup"
Write-INF "Dann:      claude"

# ═══════════════════════════════════════════════════════════════
# BLOCK 7 — ENGINE STATUS LIVE CHECK
# ═══════════════════════════════════════════════════════════════
Write-Banner "BLOCK 7 — LIVE ENGINE STATUS" "Cyan"

$engines = @(
  @{ Port=8420; Name="Primary Engine (ChatLegs)" },
  @{ Port=8421; Name="Shadow Engine (ChatLegs)" },
  @{ Port=8422; Name="Matrix Control Plane" },
  @{ Port=4000;  Name="LiteLLM Gateway (FREE AI)" },
  @{ Port=5678;  Name="n8n Automation" },
  @{ Port=11434; Name="Ollama (Local LLMs)" }
)

foreach ($e in $engines) {
  try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $ar  = $tcp.BeginConnect("127.0.0.1", $e.Port, $null, $null)
    $ok  = $ar.AsyncWaitHandle.WaitOne(1000, $false)
    $tcp.Close()
    if ($ok) {
      Write-Host ("  ✓  :{0,-5}  {1}" -f $e.Port, $e.Name) -ForegroundColor Green
    } else {
      Write-Host ("  ✗  :{0,-5}  {1}  [DOWN]" -f $e.Port, $e.Name) -ForegroundColor Red
    }
  } catch {
    Write-Host ("  ?  :{0,-5}  {1}  [ERROR]" -f $e.Port, $e.Name) -ForegroundColor Yellow
  }
}

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════
Write-Banner "SETUP COMPLETE" "Green"
Write-Host ""
Write-Host "  SOFORT NUTZBAR:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Free Coding Agent starten:" -ForegroundColor Cyan
Write-Host "     cd C:\Users\mail\R3-DASHBOARD" -ForegroundColor Gray
Write-Host "     .\r3-code.bat              (Groq, kostenlos)" -ForegroundColor Gray
Write-Host "     .\r3-code.bat local        (Ollama, offline)" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. r-vib3 starten ohne Port-Konflikt:" -ForegroundColor Cyan
Write-Host "     cd r-vib3 && npm run dev:ui   (Port 3333)" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Claude Code → Free Backend:" -ForegroundColor Cyan
Write-Host "     . .\R3_LLM_ENGINE_REGISTRY\claude-free-setup.ps1" -ForegroundColor Gray
Write-Host "     claude" -ForegroundColor Gray
Write-Host ""
if ($needsRestart) {
  Write-Host "  ⚠  WSL2 NEUSTART NÖTIG für localhost-Zugriff:" -ForegroundColor Yellow
  Write-Host "     wsl --shutdown    (dann WSL neu öffnen)" -ForegroundColor Yellow
}
Write-Host ""
