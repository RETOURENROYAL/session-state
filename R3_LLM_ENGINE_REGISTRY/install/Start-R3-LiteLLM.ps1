#Requires -Version 5.1
<#
.SYNOPSIS
    R3 LiteLLM Gateway — Start / Status / Stop
.DESCRIPTION
    Startet den LiteLLM Gateway-Container mit allen 14 Ollama-Routen
    (RAZER + APPSEN) vorgeladen aus litellm-config.yaml.
    Kein Register-R3-Ollama.ps1 nötig — Routen sind ab Start verfügbar.

.PARAMETER Action
    start  (default) — starte den Container
    stop             — stoppe und entferne den Container
    status           — zeige Container-Status + /health
    restart          — stop + start

.EXAMPLE
    .\Start-R3-LiteLLM.ps1
    .\Start-R3-LiteLLM.ps1 -Action status
    .\Start-R3-LiteLLM.ps1 -Action restart

.NOTES
    One-liner remote install:
    iwr https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Start-R3-LiteLLM.ps1 | iex
#>
param(
    [ValidateSet("start","stop","status","restart")]
    [string]$Action = "start"
)

$ContainerName = "r3-litellm"
$Port          = 4000
$MasterKey     = "r3-local"
$Image         = "ghcr.io/berriai/litellm:main-latest"
$LiteLLMUrl    = "http://localhost:$Port"

# Config file — supports both remote (download) and local run
# Guard: $MyInvocation.MyCommand.Path is null when piped via iwr | iex
$ScriptDir     = if ($MyInvocation.MyCommand.Path) { Split-Path $MyInvocation.MyCommand.Path } else { $null }
$ConfigLocal   = if ($ScriptDir) { "$ScriptDir\..\config\litellm-config.yaml" } else { $null }
$ConfigRaw     = "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/config/litellm-config.yaml"

function Write-Banner {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   R3 LiteLLM Gateway — localhost:$Port                      ║" -ForegroundColor Cyan
    Write-Host "  ║   14 Ollama routes: RAZER (18 models) + APPSEN (2 models)   ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Get-ContainerStatus {
    $c = docker ps -a --filter "name=^$ContainerName$" --format "{{.Status}}" 2>$null
    return $c
}

function Test-Health([switch]$Silent) {
    try {
        $resp = Invoke-WebRequest "$LiteLLMUrl/health" -TimeoutSec 3 -UseBasicParsing -EA Stop
        if (-not $Silent) { Write-Host "  ✓ LiteLLM $LiteLLMUrl/v1 — online" -ForegroundColor Green }
        return $true
    } catch {
        # 401 = LiteLLM is running but requires auth — treat as online
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 401) {
            if (-not $Silent) { Write-Host "  ✓ LiteLLM $LiteLLMUrl/v1 — online (auth required)" -ForegroundColor Green }
            return $true
        }
        if (-not $Silent) { Write-Host "  ✗ LiteLLM $LiteLLMUrl — offline" -ForegroundColor Red }
        return $false
    }
}

function Resolve-Config {
    # Prefer local config file; fall back to temp download
    if ($ConfigLocal -and (Test-Path $ConfigLocal)) {
        return (Resolve-Path $ConfigLocal).Path
    }
    $tmp = "$env:TEMP\r3-litellm-config.yaml"
    Write-Host "  ▶ Config herunterladen → $tmp" -ForegroundColor DarkGray
    try {
        Invoke-WebRequest $ConfigRaw -OutFile $tmp -UseBasicParsing -EA Stop
        return $tmp
    } catch {
        Write-Host "  ✗ Config konnte nicht heruntergeladen werden: $_" -ForegroundColor Red
        return $null
    }
}

function Get-PortOwner {
    param([int]$P)
    # Check running Docker containers first
    $dockerOwner = docker ps --format "{{.Names}}\t{{.Ports}}" 2>$null |
                   Where-Object { $_ -match ":${P}->" } |
                   Select-Object -First 1
    if ($dockerOwner) {
        return @{ type = "docker"; name = ($dockerOwner -split "`t")[0] }
    }
    # Fallback: check any process via netstat
    $nsLine = (netstat -ano 2>$null) -match "0\.0\.0\.0:$P\s|127\.0\.0\.1:$P\s|::$P\s" |
              Select-Object -First 1
    if ($nsLine) {
        $pid = ($nsLine.Trim() -split '\s+') | Select-Object -Last 1
        return @{ type = "process"; pid = $pid }
    }
    return $null
}

function Start-LiteLLM {
    $status = Get-ContainerStatus
    if ($status -match "^Up") {
        Write-Host "  ✓ Container '$ContainerName' läuft bereits ($status)" -ForegroundColor Green
        Test-Health
        return
    }

    # Remove stopped container if present
    if ($status) {
        Write-Host "  ⟳ Entferne gestoppten Container..." -ForegroundColor DarkGray
        docker rm $ContainerName 2>$null | Out-Null
    }

    # Pre-check: is port $Port already in use? (check before docker run — more reliable)
    $owner = Get-PortOwner -P $Port
    if ($owner) {
        if ($owner.type -eq "docker") {
            if ($owner.name -eq $ContainerName) {
                Write-Host "  ⟳ Unser Container belegt Port $Port bereits — health-check..." -ForegroundColor DarkGray
                Test-Health
                return
            }
            Write-Host "  ℹ Port $Port belegt von Docker-Container: $($owner.name)" -ForegroundColor Yellow
            Write-Host "  ⟳ Stoppe '$($owner.name)'..." -ForegroundColor DarkGray
            docker stop $owner.name 2>$null | Out-Null
            docker rm   $owner.name 2>$null | Out-Null
            Start-Sleep -Seconds 2
        } else {
            $pid = $owner.pid
            Write-Host "  ✗ Port $Port belegt von Prozess PID $pid (kein Docker-Container)." -ForegroundColor Red
            try {
                $pName = (Get-Process -Id ([int]$pid) -ErrorAction SilentlyContinue).ProcessName
                if ($pName) { Write-Host "  Prozess: $pName (PID $pid)" -ForegroundColor Yellow }
            } catch {}
            Write-Host "  → Beenden mit: Stop-Process -Id $pid -Force" -ForegroundColor DarkGray
            return
        }
    }

    $configPath = Resolve-Config
    if (-not $configPath) { return }

    Write-Host "  ▶ Starte $ContainerName mit config: $configPath" -ForegroundColor White

    # --add-host host.docker.internal:host-gateway maps host localhost → container
    # Required for RAZER Ollama (localhost:11434) to be reachable from inside container
    $dockerArgs = @(
        "run", "-d",
        "--name", $ContainerName,
        "-p", "${Port}:${Port}",
        "--add-host", "host.docker.internal:host-gateway",
        "-v", "${configPath}:/app/config.yaml",
        "-e", "LITELLM_MASTER_KEY=$MasterKey",
        $Image,
        "--config", "/app/config.yaml",
        "--port", "$Port"
    )

    $result = docker @dockerArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        $errMsg = ($result | Out-String).Trim()
        Write-Host "  ✗ docker run fehlgeschlagen: $errMsg" -ForegroundColor Red
        Write-Host "  Manuell: docker run -d --name r3-litellm -p 4000:4000 --add-host host.docker.internal:host-gateway -v `"$configPath`":/app/config.yaml -e LITELLM_MASTER_KEY=r3-local $Image --config /app/config.yaml --port 4000" -ForegroundColor DarkGray
        return
    }

    Write-Host "  ⏳ Warte auf LiteLLM (max 40s)..." -ForegroundColor DarkGray
    $waited = 0
    do {
        Start-Sleep -Seconds 3
        $waited += 3
        $online = Test-Health -Silent
    } while (-not $online -and $waited -lt 40)

    if ($online) {
        Write-Host ""
        Write-Host "  ✓ LiteLLM online! Routen verfügbar:" -ForegroundColor Green
        try {
            $models = (Invoke-RestMethod "$LiteLLMUrl/v1/models" -Headers @{Authorization="Bearer $MasterKey"} -TimeoutSec 5).data
            $models | ForEach-Object {
                Write-Host "    $('{0,-25}' -f $_.id)" -ForegroundColor Cyan -NoNewline
            }
            Write-Host ""
        } catch { }
        Write-Host ""
        Write-Host "  ┌─────────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
        Write-Host "  │  POST http://localhost:4000/v1/chat/completions              │" -ForegroundColor DarkGray
        Write-Host "  │  Authorization: Bearer r3-local                             │" -ForegroundColor DarkGray
        Write-Host "  │  model: r3/code | r3/reasoning | r3/fast | r3/chat | ...    │" -ForegroundColor DarkGray
        Write-Host "  └─────────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
    } else {
        Write-Host "  ✗ LiteLLM hat sich nicht gemeldet — prüfe: docker logs $ContainerName" -ForegroundColor Red
    }
}

function Stop-LiteLLM {
    $status = Get-ContainerStatus
    if (-not $status) {
        Write-Host "  Container '$ContainerName' existiert nicht." -ForegroundColor DarkGray
        return
    }
    Write-Host "  ▶ Stoppe + entferne $ContainerName..." -ForegroundColor Yellow
    docker stop $ContainerName 2>$null | Out-Null
    docker rm   $ContainerName 2>$null | Out-Null
    Write-Host "  ✓ Gestoppt." -ForegroundColor Green
}

function Show-Status {
    $status = Get-ContainerStatus
    if ($status) {
        Write-Host "  Container: $ContainerName — $status" -ForegroundColor $(if ($status -match '^Up') {'Green'} else {'Yellow'})
    } else {
        Write-Host "  Container: $ContainerName — nicht vorhanden" -ForegroundColor Red
    }
    Test-Health
    if (Test-Health -Silent) {
        try {
            $models = (Invoke-RestMethod "$LiteLLMUrl/v1/models" -Headers @{Authorization="Bearer $MasterKey"} -TimeoutSec 5).data
            Write-Host "  Routen ($($models.Count)): $($models.id -join ', ')" -ForegroundColor Cyan
        } catch { }
    }
}

# ── MAIN ───────────────────────────────────────────────────────────────────────
Write-Banner

switch ($Action) {
    "start"   { Start-LiteLLM }
    "stop"    { Stop-LiteLLM }
    "status"  { Show-Status }
    "restart" { Stop-LiteLLM; Start-Sleep 2; Start-LiteLLM }
}
