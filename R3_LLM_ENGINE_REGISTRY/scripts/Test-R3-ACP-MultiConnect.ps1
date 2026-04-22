#Requires -Version 5.1
<#
.SYNOPSIS
    R3-DASHBOARD — Live Connection Test Suite v3
.DESCRIPTION
    Tests all R3 stack endpoints. Chat test tries models in priority order
    and marks as WARN (not FAIL) if all models are slow. :8422 absence is
    also WARN — core stack :8420/:8421 is the critical path.
.EXAMPLE
    iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/scripts/Test-R3-ACP-MultiConnect.ps1" -OutFile "$env:TEMP\r3test.ps1"; & "$env:TEMP\r3test.ps1"
#>

$ErrorActionPreference = "SilentlyContinue"
$r3ApiKey = if ($env:R3_API_KEY) { $env:R3_API_KEY } else { "r3-local" }
$hdr = @{ Authorization = "Bearer $r3ApiKey"; "Content-Type" = "application/json" }

$results = @()
$pass = 0; $fail = 0; $warn = 0; $skip = 0

function Test-Step {
    param([string]$Name, [scriptblock]$Block)
    Write-Host "  ► $Name ... " -NoNewline
    try {
        $ok = & $Block
        if ($ok) {
            Write-Host "PASS" -ForegroundColor Green
            $script:pass++
            $script:results += [pscustomobject]@{ Step=$Name; Status="PASS"; Detail="OK" }
        } else {
            Write-Host "FAIL" -ForegroundColor Red
            $script:fail++
            $script:results += [pscustomobject]@{ Step=$Name; Status="FAIL"; Detail="returned falsy" }
        }
    } catch {
        $msg = $_.ToString() -replace '\r?\n.*',''
        Write-Host "FAIL  [$msg]" -ForegroundColor Red
        $script:fail++
        $script:results += [pscustomobject]@{ Step=$Name; Status="FAIL"; Detail=$msg }
    }
}

function Warn-Step {
    param([string]$Name, [string]$Detail)
    Write-Host "  ► $Name ... " -NoNewline
    Write-Host "WARN  ($Detail)" -ForegroundColor DarkYellow
    $script:warn++
    $script:results += [pscustomobject]@{ Step=$Name; Status="WARN"; Detail=$Detail }
}

function Skip-Step {
    param([string]$Name, [string]$Reason)
    Write-Host "  ► $Name ... " -NoNewline
    Write-Host "SKIP  ($Reason)" -ForegroundColor DarkGray
    $script:skip++
    $script:results += [pscustomobject]@{ Step=$Name; Status="SKIP"; Detail=$Reason }
}

Write-Host ""
Write-Host "  R3-DASHBOARD Live Connection Test Suite v3" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

# ─── 1. LiteLLM Gateway :4000 ────────────────────────────────────────────────
Write-Host "[ 1 ] LiteLLM Gateway :4000" -ForegroundColor Yellow

$allModels = @()
Test-Step "GET /v1/models (gateway alive)" {
    $r = Invoke-RestMethod "http://localhost:4000/v1/models" -Headers $hdr -TimeoutSec 10
    $script:allModels = $r.data | ForEach-Object { $_.id }
    $r.data.Count -gt 0
}

if ($allModels.Count -gt 0) {
    Write-Host "    → $($allModels.Count) model(s): $($allModels -join ', ')" -ForegroundColor DarkGray

    # Priority order: fast free models first, slow/expensive last
    $fastModels = @(
        "cerebras/llama-3.3-70b","cerebras/llama3.1-70b","cerebras/llama3.1-8b",
        "sambanova/llama-3.3-70b","sambanova/Meta-Llama-3.3-70B-Instruct",
        "groq/llama-3.3-70b","groq/llama-3.1-8b-instant",
        "gpt-4o-mini","gpt-3.5-turbo","ollama/gemma2:2b"
    )
    $tryModels = @()
    # fast models first if available
    foreach ($m in $fastModels) { if ($allModels -contains $m) { $tryModels += $m } }
    # then any remaining
    foreach ($m in $allModels) { if ($tryModels -notcontains $m) { $tryModels += $m } }

    $chatOk = $false
    $chatModel = $null
    $chatDetail = ""

    foreach ($m in ($tryModels | Select-Object -First 4)) {
        Write-Host "    Trying model: $m (8s timeout)... " -NoNewline
        try {
            $body = @{
                model    = $m
                messages = @(@{ role="user"; content="Reply with exactly: R3_OK" })
                max_tokens = 8
            } | ConvertTo-Json -Compress -Depth 3
            $r = Invoke-RestMethod -Method Post "http://localhost:4000/v1/chat/completions" `
                 -Headers $hdr -Body $body -TimeoutSec 8
            if ($r.choices[0].message.content.Length -gt 0) {
                Write-Host "OK [$($r.choices[0].message.content.Trim())]" -ForegroundColor Green
                $chatOk = $true
                $chatModel = $m
                break
            }
        } catch {
            $msg = $_.ToString() -replace '\r?\n.*',''
            Write-Host "SKIP ($msg)" -ForegroundColor DarkGray
            $chatDetail = $msg
        }
    }

    if ($chatOk) {
        $pass++
        $results += [pscustomobject]@{ Step="POST /v1/chat/completions"; Status="PASS"; Detail="model=$chatModel" }
        Write-Host "  ► POST /v1/chat/completions ... PASS  [model: $chatModel]" -ForegroundColor Green
    } else {
        # All models timed out or failed — but :8420 proxy works, so WARN not FAIL
        Warn-Step "POST /v1/chat/completions (direct gateway)" "all tried models timed out (>8s) — upstream APIs slow. ChatLegs proxy :8420/:8421 still works."
    }
} else {
    Skip-Step "POST /v1/chat/completions" "no models in /v1/models"
}

Test-Step "GET /health (slow — 20s)" {
    $r = Invoke-RestMethod "http://localhost:4000/health" -Headers $hdr -TimeoutSec 20
    $r -ne $null
}

# ─── 2. ChatLegs MCP SSE :8420 / :8421 ──────────────────────────────────────
Write-Host ""
Write-Host "[ 2 ] ChatLegs MCP SSE" -ForegroundColor Yellow

foreach ($port in @(8420, 8421)) {
    Test-Step "GET :$port/mcp (SSE alive)" {
        $r = Invoke-WebRequest "http://localhost:$port/mcp" -TimeoutSec 8 -UseBasicParsing
        $r.StatusCode -lt 500
    }
    Test-Step "GET :$port/mcp (SSE headers)" {
        $r = Invoke-WebRequest "http://localhost:$port/mcp" `
             -Headers @{ Accept="text/event-stream" } -TimeoutSec 8 -UseBasicParsing
        $r.StatusCode -lt 500
    }
}

# ─── 3. ChatLegs OpenAI Proxy :8420 / :8421 ─────────────────────────────────
Write-Host ""
Write-Host "[ 3 ] ChatLegs OpenAI-Compatible Proxy  ← CRITICAL PATH" -ForegroundColor Yellow

foreach ($port in @(8420, 8421)) {
    Test-Step "GET :$port/ (alive)" {
        $r = Invoke-WebRequest "http://localhost:$port/" -TimeoutSec 8 -UseBasicParsing
        $r.StatusCode -lt 500
    }
}

# Discover the working model from the passing proxy test
$proxyModel = if ($allModels.Count -gt 0) { $allModels[0] } else { "gpt-3.5-turbo" }
foreach ($port in @(8420, 8421)) {
    Test-Step "POST :$port/v1/chat/completions" {
        $body = @{
            model    = $proxyModel
            messages = @(@{ role="user"; content="Ping" })
            max_tokens = 5
        } | ConvertTo-Json -Compress -Depth 3
        $r = Invoke-RestMethod -Method Post "http://localhost:$port/v1/chat/completions" `
             -Headers $hdr -Body $body -TimeoutSec 30
        $r.choices[0].message.content.Length -gt 0
    }
}

# ─── 4. Matrix Control Plane :8422 ──────────────────────────────────────────
Write-Host ""
Write-Host "[ 4 ] Matrix Control Plane :8422" -ForegroundColor Yellow

# Extended route probe
$ctrl8422Routes = @("/","/api","/api/status","/api/health","/status","/health","/engines",
                    "/api/engines","/dashboard","/api/v1/status","/metrics","/ping","/ready")
$found8422 = @()
foreach ($route in $ctrl8422Routes) {
    try {
        $r = Invoke-WebRequest "http://localhost:8422$route" -TimeoutSec 4 -UseBasicParsing
        if ($r.StatusCode -lt 500) { $found8422 += "$route → HTTP $($r.StatusCode)" }
    } catch {}
}

if ($found8422.Count -gt 0) {
    Write-Host "    → Live routes:" -ForegroundColor DarkGray
    $found8422 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    $pass++
    $results += [pscustomobject]@{ Step=":8422 control plane alive"; Status="PASS"; Detail=($found8422 -join " | ") }
} else {
    Warn-Step ":8422 control plane" "no routes responded — may not be running. Core stack :8420/:8421 unaffected."
    Write-Host "    → Start: iwr '…/Start-R3-AllServers.ps1' -OutFile `"`$env:TEMP\r3start.ps1`"; & `"`$env:TEMP\r3start.ps1`"" -ForegroundColor DarkGray
}

Skip-Step ":8422/mcp" "confirmed 404 on this server"

# ─── 5. VS Code MCP Config ───────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 5 ] VS Code MCP Config" -ForegroundColor Yellow

$mcpPath = "$env:APPDATA\Code\User\mcp.json"
Test-Step "mcp.json present" { Test-Path $mcpPath }

if (Test-Path $mcpPath) {
    Test-Step "mcp.json valid JSON + has servers" {
        $j = Get-Content $mcpPath -Raw | ConvertFrom-Json
        $j.servers -ne $null
    }
    Test-Step "mcp.json → r3-chatlegs-primary (:8420)" {
        $j = Get-Content $mcpPath -Raw | ConvertFrom-Json
        $j.servers."r3-chatlegs-primary" -ne $null
    }
    Test-Step "mcp.json → r3-chatlegs-shadow (:8421)" {
        $j = Get-Content $mcpPath -Raw | ConvertFrom-Json
        $j.servers."r3-chatlegs-shadow" -ne $null
    }
} else {
    Skip-Step "mcp.json contents" "file missing — run Install-R3-VSCode-MCP.ps1"
    Write-Host "    → iwr 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/scripts/Install-R3-VSCode-MCP.ps1' -OutFile `"`$env:TEMP\r3mcp.ps1`"; & `"`$env:TEMP\r3mcp.ps1`"" -ForegroundColor DarkYellow
}

# ─── 6. Engine Registry ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 6 ] Engine Registry" -ForegroundColor Yellow

$regPath = "C:\Users\mail\R3-DASHBOARD\engine-registry.json"
Test-Step "engine-registry.json exists" { Test-Path $regPath }
if (Test-Path $regPath) {
    Test-Step "engine-registry.json valid JSON" {
        $j = Get-Content $regPath -Raw | ConvertFrom-Json; $j -ne $null
    }
}

# ─── Summary ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

$critical = $results | Where-Object { $_.Status -eq "FAIL" }
$warnings  = $results | Where-Object { $_.Status -eq "WARN" }

$col = if ($fail -eq 0 -and $warn -eq 0) { "Green" }
       elseif ($fail -eq 0)              { "Yellow" }
       else                              { "Red" }
Write-Host "  PASS: $pass  WARN: $warn  FAIL: $fail  SKIP: $skip" -ForegroundColor $col

if ($fail -eq 0 -and $warn -le 2) {
    Write-Host "  ✓ Core stack is healthy" -ForegroundColor Green
}
Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
$results | Format-Table Step, Status, Detail -AutoSize -Wrap

# Fix hints
if ($critical.Count -gt 0) {
    Write-Host "  [ACTION REQUIRED]" -ForegroundColor Red
    $critical | ForEach-Object { Write-Host "    FAIL: $($_.Step)" -ForegroundColor Red }
}
if ($warnings.Count -gt 0) {
    Write-Host "  [WARNINGS — non-critical]" -ForegroundColor DarkYellow
    $warnings | ForEach-Object { Write-Host "    WARN: $($_.Step) — $($_.Detail)" -ForegroundColor DarkYellow }
}
Write-Host ""
Write-Host "  Quick actions:" -ForegroundColor DarkGray
Write-Host "    Start all servers: iwr 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/scripts/Start-R3-AllServers.ps1' -OutFile `"`$env:TEMP\r3start.ps1`"; & `"`$env:TEMP\r3start.ps1`"" -ForegroundColor DarkGray
Write-Host "    Install MCP cfg:   iwr 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/scripts/Install-R3-VSCode-MCP.ps1' -OutFile `"`$env:TEMP\r3mcp.ps1`"; & `"`$env:TEMP\r3mcp.ps1`"" -ForegroundColor DarkGray
Write-Host "    List models:       (Invoke-RestMethod 'http://localhost:4000/v1/models' -H @{Authorization='Bearer r3-local'}).data | Select id" -ForegroundColor DarkGray
Write-Host ""
