# ============================================================
# R3 — Start All Servers
# ChatLegs :8420/:8421 + Matrix Control :8422
# Requires: LiteLLM already on :4000
# ============================================================

$R3  = "C:\Users\mail\R3-DASHBOARD"
$CL  = "$R3\SOURCE\chat-legs"
$LOG = "$R3\R3_LLM_ENGINE_REGISTRY\logs"

if (-not (Test-Path $LOG)) { New-Item -ItemType Directory -Path $LOG -Force | Out-Null }

function Test-Port {
    param([int]$Port)
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $tcp.Connect("127.0.0.1", $Port)
        $tcp.Close()
        return $true
    } catch {
        return $false
    }
}

function Wait-Port {
    param([int]$Port, [int]$Seconds = 12)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if (Test-Port $Port) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Write-Status {
    param([string]$Msg, [string]$Color = "Cyan")
    Write-Host $Msg -ForegroundColor $Color
}

# Env-Keys laden
foreach ($ef in @("$CL\.env", "$CL\.env.local")) {
    if (Test-Path $ef) {
        Get-Content $ef | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*=.+' } | ForEach-Object {
            $parts = $_ -split '=', 2
            $key   = $parts[0].Trim()
            $val   = $parts[1].Trim().Trim('"').Trim("'")
            [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
        }
        Write-Status "[OK] Keys loaded: $ef" "Green"
    }
}

# LiteLLM :4000
if (-not (Test-Port 4000)) {
    Write-Status "[WARN] LiteLLM :4000 antwortet nicht!" "Yellow"
} else {
    Write-Status "[OK] LiteLLM Gateway :4000 live" "Green"
}

# ChatLegs Primary :8420
if (Test-Port 8420) {
    Write-Status "[SKIP] :8420 already running" "Yellow"
} else {
    Write-Status "[START] ChatLegs Primary -> :8420" "Cyan"
    Start-Process powershell.exe -ArgumentList @(
        "-NoExit", "-Command",
        "cd '$CL'; `$env:PORT='8420'; `$env:NODE_ENV='production'; node server.js 2>&1 | Tee-Object -FilePath '$LOG\chatlegs-8420.log' -Append"
    ) -WindowStyle Normal
    if (Wait-Port 8420 15) {
        Write-Status "[OK] ChatLegs Primary :8420 live" "Green"
    } else {
        Write-Status "[WARN] :8420 Timeout - Log: $LOG\chatlegs-8420.log" "Yellow"
    }
}

# ChatLegs Shadow :8421
if (Test-Port 8421) {
    Write-Status "[SKIP] :8421 already running" "Yellow"
} else {
    Write-Status "[START] ChatLegs Shadow -> :8421" "Cyan"
    Start-Process powershell.exe -ArgumentList @(
        "-NoExit", "-Command",
        "cd '$CL'; `$env:PORT='8421'; `$env:NODE_ENV='production'; `$env:INSTANCE='shadow'; node server.js 2>&1 | Tee-Object -FilePath '$LOG\chatlegs-8421.log' -Append"
    ) -WindowStyle Normal
    if (Wait-Port 8421 15) {
        Write-Status "[OK] ChatLegs Shadow :8421 live" "Green"
    } else {
        Write-Status "[WARN] :8421 Timeout - Log: $LOG\chatlegs-8421.log" "Yellow"
    }
}

# Matrix Control :8422
if (Test-Port 8422) {
    Write-Status "[SKIP] :8422 already running" "Yellow"
} else {
    $cpList = @(
        @{ Dir = "$CL\_runtime\matrix-control-plane";        File = "server.js" },
        @{ Dir = "$CL\r3_control_plane_live_package";         File = "control-plane-dashboard-router.js" },
        @{ Dir = "$CL\r3_next_step_package_rebuilt";          File = "server.js" },
        @{ Dir = "$CL\r3_matrix_control_plane_pack\payload";  File = "server.js" },
        @{ Dir = $CL;                                          File = "matrix-control.js" }
    )
    $cpEntry = $null
    foreach ($c in $cpList) {
        if (Test-Path "$($c.Dir)\$($c.File)") { $cpEntry = $c; break }
    }
    if ($cpEntry) {
        Write-Status "[START] Matrix Control -> :8422 ($($cpEntry.File))" "Cyan"
        Start-Process powershell.exe -ArgumentList @(
            "-NoExit", "-Command",
            "cd '$($cpEntry.Dir)'; `$env:PORT='8422'; `$env:NODE_ENV='production'; node '$($cpEntry.File)' 2>&1 | Tee-Object -FilePath '$LOG\matrix-8422.log' -Append"
        ) -WindowStyle Normal
        if (Wait-Port 8422 15) {
            Write-Status "[OK] Matrix Control :8422 live" "Green"
        } else {
            Write-Status "[WARN] :8422 Timeout - Log: $LOG\matrix-8422.log" "Yellow"
        }
    } else {
        Write-Status "[WARN] Kein Control-Plane Entry-Point gefunden!" "Red"
        foreach ($c in $cpList) { Write-Status "  - $($c.Dir)\$($c.File)" "DarkGray" }
    }
}

# Status-Tabelle
Write-Host ""
Write-Host "══════════════════════════════════════" -ForegroundColor White
Write-Host "  R3 SERVER STATUS" -ForegroundColor White
Write-Host "══════════════════════════════════════" -ForegroundColor White
foreach ($entry in @(
    @{ Name = "LiteLLM Gateway  "; Port = 4000 },
    @{ Name = "ChatLegs Primary "; Port = 8420 },
    @{ Name = "ChatLegs Shadow  "; Port = 8421 },
    @{ Name = "Matrix Control   "; Port = 8422 }
)) {
    $alive = Test-Port $entry.Port
    $icon  = if ($alive) { "[OK]" } else { "[--]" }
    $col   = if ($alive) { "Green" } else { "Red" }
    Write-Host "  $icon  $($entry.Name) :$($entry.Port)" -ForegroundColor $col
}
Write-Host ""
Write-Host "  MCP Endpoints:" -ForegroundColor Cyan
Write-Host "  http://localhost:8420/mcp" -ForegroundColor Gray
Write-Host "  http://localhost:8421/mcp" -ForegroundColor Gray
Write-Host "  http://localhost:8422/mcp" -ForegroundColor Gray
Write-Host "  http://localhost:4000/v1  (LiteLLM)" -ForegroundColor Gray
Write-Host "══════════════════════════════════════" -ForegroundColor White
