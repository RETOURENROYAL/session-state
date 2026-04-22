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
    try { $tcp.Connect("127.0.0.1", $Port); $tcp.Close(); return $true } catch { return $false }
}

function Wait-Port {
    param([int]$Port, [int]$Seconds = 15)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if (Test-Port $Port) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

# Env-Keys laden
foreach ($ef in @("$CL\.env", "$CL\.env.local")) {
    if (Test-Path $ef) {
        Get-Content $ef | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*=.+' } | ForEach-Object {
            $parts = $_ -split '=', 2
            [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim().Trim('"').Trim("'"), "Process")
        }
        Write-Host "[OK] Keys: $ef" -ForegroundColor Green
    }
}

# Gate: LiteLLM pruefen
if (Test-Port 4000) { Write-Host "[OK] LiteLLM :4000 live" -ForegroundColor Green }
else { Write-Host "[WARN] LiteLLM :4000 nicht erreichbar!" -ForegroundColor Yellow }

# ChatLegs Primary :8420
if (Test-Port 8420) { Write-Host "[SKIP] :8420 laeuft" -ForegroundColor Yellow }
else {
    Start-Process powershell.exe -ArgumentList "-NoExit","-Command","cd '$CL'; `$env:PORT='8420'; `$env:NODE_ENV='production'; node server.js 2>&1 | Tee-Object '$LOG\chatlegs-8420.log' -Append" -WindowStyle Normal
    if (Wait-Port 8420) { Write-Host "[OK] ChatLegs Primary :8420 live" -ForegroundColor Green }
    else { Write-Host "[WARN] :8420 Timeout — $LOG\chatlegs-8420.log" -ForegroundColor Yellow }
}

# ChatLegs Shadow :8421
if (Test-Port 8421) { Write-Host "[SKIP] :8421 laeuft" -ForegroundColor Yellow }
else {
    Start-Process powershell.exe -ArgumentList "-NoExit","-Command","cd '$CL'; `$env:PORT='8421'; `$env:NODE_ENV='production'; `$env:INSTANCE='shadow'; node server.js 2>&1 | Tee-Object '$LOG\chatlegs-8421.log' -Append" -WindowStyle Normal
    if (Wait-Port 8421) { Write-Host "[OK] ChatLegs Shadow :8421 live" -ForegroundColor Green }
    else { Write-Host "[WARN] :8421 Timeout — $LOG\chatlegs-8421.log" -ForegroundColor Yellow }
}

# Matrix Control-Plane :8422
if (Test-Port 8422) { Write-Host "[SKIP] :8422 laeuft" -ForegroundColor Yellow }
else {
    $cpCandidates = @(
        @{ Dir = "$CL\_runtime\matrix-control-plane";        File = "server.js" },
        @{ Dir = "$CL\r3_control_plane_live_package";        File = "control-plane-dashboard-router.js" },
        @{ Dir = "$CL\r3_next_step_package_rebuilt";         File = "server.js" },
        @{ Dir = "$CL\r3_matrix_control_plane_pack\payload"; File = "server.js" },
        @{ Dir = $CL;                                        File = "matrix-control.js" }
    )
    $cp = $null
    foreach ($c in $cpCandidates) {
        if (Test-Path "$($c.Dir)\$($c.File)") { $cp = $c; break }
    }
    if ($cp) {
        Start-Process powershell.exe -ArgumentList "-NoExit","-Command","cd '$($cp.Dir)'; `$env:PORT='8422'; `$env:NODE_ENV='production'; node '$($cp.File)' 2>&1 | Tee-Object '$LOG\matrix-8422.log' -Append" -WindowStyle Normal
        if (Wait-Port 8422) { Write-Host "[OK] Matrix Control :8422 live" -ForegroundColor Green }
        else { Write-Host "[WARN] :8422 Timeout — $LOG\matrix-8422.log" -ForegroundColor Yellow }
    } else {
        Write-Host "[WARN] Kein Control-Plane-Einstiegspunkt gefunden!" -ForegroundColor Red
    }
}

# Status
Write-Host "`n══ R3 STATUS ══" -ForegroundColor White
foreach ($p in @(4000, 8420, 8421, 8422)) {
    $ok = Test-Port $p
    Write-Host "  $(if($ok){'[OK]'}else{'[--]'}) localhost:$p" -ForegroundColor $(if($ok){'Green'}else{'Red'})
}
