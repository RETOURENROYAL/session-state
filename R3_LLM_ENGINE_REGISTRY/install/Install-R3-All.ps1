# ============================================================
# Install-R3-All.ps1 — R³ VIB.E Complete Stack Installer
# ============================================================
# Starts: LiteLLM :4000  +  ChatLegs :8420/:8421  +  n8n :5678
#
# Remote one-liner:
#   & ([scriptblock]::Create((iwr 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Install-R3-All.ps1?r=$(Get-Random)').Content))
#
# With action:
#   & ([scriptblock]::Create((iwr 'URL?r=$(Get-Random)').Content)) -Action status
# ============================================================

[CmdletBinding()]
param(
    [ValidateSet('start','stop','status','restart')]
    [string]$Action = 'start'
)

$R3  = "C:\Users\mail\R3-DASHBOARD"
$REG = "$R3\R3_LLM_ENGINE_REGISTRY"
$CL  = "$R3\SOURCE\chat-legs"
$LOG = "$REG\logs"

# ── Helpers ──────────────────────────────────────────────────

function Show-Header {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   R³ VIB.E — Complete Stack Installer                       ║" -ForegroundColor Cyan
    Write-Host "  ║   LiteLLM :4000  │  ChatLegs :8420/:8421  │  n8n :5678      ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Port {
    param([int]$Port)
    $tcp = New-Object System.Net.Sockets.TcpClient
    try { $tcp.Connect("127.0.0.1", $Port); $tcp.Close(); return $true }
    catch { return $false }
}

function Wait-Port {
    param([int]$Port, [int]$Seconds = 20)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if (Test-Port $Port) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Write-Ok   { param([string]$m) Write-Host "  [OK]   $m" -ForegroundColor Green }
function Write-Skip { param([string]$m) Write-Host "  [SKIP] $m" -ForegroundColor Yellow }
function Write-Warn { param([string]$m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "  [ERR]  $m" -ForegroundColor Red }
function Write-Info { param([string]$m) Write-Host "  [..]   $m" -ForegroundColor Cyan }

function Show-Status {
    Write-Host ""
    Write-Host "  ══════════════════════════════════════════" -ForegroundColor White
    Write-Host "    R³ VIB.E — Live Status" -ForegroundColor White
    Write-Host "  ══════════════════════════════════════════" -ForegroundColor White
    foreach ($e in @(
        @{ Name = "LiteLLM Gateway  "; Port = 4000; Url = "http://localhost:4000/v1" },
        @{ Name = "ChatLegs Primary "; Port = 8420; Url = "http://localhost:8420/mcp" },
        @{ Name = "ChatLegs Shadow  "; Port = 8421; Url = "http://localhost:8421/mcp" },
        @{ Name = "n8n Automation   "; Port = 5678; Url = "http://localhost:5678" }
    )) {
        $ok   = Test-Port $e.Port
        $icon = if ($ok) { "[OK]" } else { "[--]" }
        $col  = if ($ok) { "Green" } else { "DarkGray" }
        Write-Host "    $icon  $($e.Name) :$($e.Port)  →  $($e.Url)" -ForegroundColor $col
    }
    Write-Host ""
    Write-Host "    LiteLLM routes:  r3/code, r3/reasoning, r3/fast, r3/chat," -ForegroundColor Gray
    Write-Host "                     r3/large, r3/autocomplete, r3/embed (+7 more)" -ForegroundColor Gray
    Write-Host "  ══════════════════════════════════════════" -ForegroundColor White
    Write-Host ""
}

# ── Actions ──────────────────────────────────────────────────

Show-Header

if ($Action -eq 'status') {
    Show-Status
    return
}

if ($Action -eq 'stop') {
    Write-Info "Stopping r3-litellm container..."
    docker stop r3-litellm 2>$null | Out-Null
    Write-Ok "r3-litellm stopped (ChatLegs + n8n must be stopped manually)"
    return
}

if ($Action -eq 'restart') {
    Write-Info "Restarting..."
    docker restart r3-litellm 2>$null | Out-Null
}

# ── STEP 1: Ensure logs dir ───────────────────────────────────
if (-not (Test-Path $LOG)) { New-Item -ItemType Directory -Path $LOG -Force | Out-Null }

# ── STEP 2: LiteLLM :4000 ────────────────────────────────────
Write-Info "Step 1/4 — LiteLLM Gateway :4000"
if (Test-Port 4000) {
    Write-Skip "LiteLLM :4000 already running"
} else {
    Write-Info "Starting LiteLLM via Start-R3-LiteLLM.ps1..."
    try {
        $litellmScript = (Invoke-WebRequest "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Start-R3-LiteLLM.ps1?r=$(Get-Random)" -UseBasicParsing).Content
        & ([scriptblock]::Create($litellmScript))
    } catch {
        Write-Warn "Remote fetch failed, trying local: $REG\install\Start-R3-LiteLLM.ps1"
        if (Test-Path "$REG\install\Start-R3-LiteLLM.ps1") {
            & "$REG\install\Start-R3-LiteLLM.ps1"
        } else {
            Write-Err "Start-R3-LiteLLM.ps1 not found — start LiteLLM manually"
        }
    }
}

# ── STEP 3: Wire ChatLegs → LiteLLM env ──────────────────────
Write-Info "Step 2/4 — ChatLegs env → LiteLLM :4000"

$envPatch = @"
# R³ VIB.E — LiteLLM Backend (auto-written by Install-R3-All.ps1)
OPENAI_BASE_URL=http://localhost:4000/v1
OPENAI_API_BASE=http://localhost:4000/v1
OPENAI_API_KEY=r3-local
LITELLM_ENDPOINT=http://localhost:4000/v1
LITELLM_KEY=r3-local
DEFAULT_MODEL=r3/fast
CHAT_MODEL=r3/chat
CODE_MODEL=r3/code
EMBED_MODEL=r3/embed
"@

$envFile = "$CL\.env.litellm"
$envPatch | Set-Content $envFile -Encoding UTF8
Write-Ok "Env patch written: $envFile"

# Also set for current process
[System.Environment]::SetEnvironmentVariable("OPENAI_BASE_URL",   "http://localhost:4000/v1", "Process")
[System.Environment]::SetEnvironmentVariable("OPENAI_API_BASE",   "http://localhost:4000/v1", "Process")
[System.Environment]::SetEnvironmentVariable("OPENAI_API_KEY",    "r3-local",                  "Process")
[System.Environment]::SetEnvironmentVariable("LITELLM_ENDPOINT",  "http://localhost:4000/v1", "Process")
[System.Environment]::SetEnvironmentVariable("DEFAULT_MODEL",     "r3/fast",                   "Process")

Write-Ok "Process env vars set"

# ── STEP 4: ChatLegs :8420 + :8421 ───────────────────────────
Write-Info "Step 3/4 — ChatLegs servers"

$startChatLegs = {
    param([string]$Port, [string]$Label, [string]$Instance)
    if (Test-Port ([int]$Port)) {
        Write-Skip "ChatLegs $Label :$Port already running"
        return
    }
    Write-Info "Starting $Label → :$Port"
    $envArgs = "`$env:PORT='$Port'; `$env:NODE_ENV='production'; `$env:INSTANCE='$Instance'; "
    $envArgs += "`$env:OPENAI_BASE_URL='http://localhost:4000/v1'; "
    $envArgs += "`$env:OPENAI_API_BASE='http://localhost:4000/v1'; "
    $envArgs += "`$env:OPENAI_API_KEY='r3-local'; "
    $envArgs += "`$env:DEFAULT_MODEL='r3/fast'; "
    $cmd = "cd '$CL'; $envArgs node server.js 2>&1 | Tee-Object -FilePath '$LOG\chatlegs-$Port.log' -Append"
    Start-Process powershell.exe -ArgumentList @("-NoExit", "-Command", $cmd) -WindowStyle Normal
    if (Wait-Port ([int]$Port) 20) {
        Write-Ok "$Label :$Port live → MCP: http://localhost:$Port/mcp"
    } else {
        Write-Warn "$Label :$Port timeout — check log: $LOG\chatlegs-$Port.log"
    }
}

& $startChatLegs "8420" "Primary" "primary"
& $startChatLegs "8421" "Shadow"  "shadow"

# ── STEP 5: n8n :5678 ────────────────────────────────────────
Write-Info "Step 4/4 — n8n Automation :5678"
if (Test-Port 5678) {
    Write-Skip "n8n :5678 already running"
} else {
    Write-Info "Launching n8n via docker compose..."
    $n8nCompose = "$REG\n8n-workflows\docker-compose.yml"
    if (Test-Path $n8nCompose) {
        Push-Location "$REG\n8n-workflows"
        docker compose up -d 2>&1 | Out-Null
        Pop-Location
        if (Wait-Port 5678 30) {
            Write-Ok "n8n :5678 live → http://localhost:5678"
        } else {
            Write-Warn "n8n :5678 timeout — check: docker logs n8n"
        }
    } else {
        Write-Warn "n8n compose not found at $n8nCompose — skip"
    }
}

# ── Final Status ──────────────────────────────────────────────
Show-Status
