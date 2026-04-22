#Requires -Version 5.1
<#
.SYNOPSIS
    R3-DASHBOARD — Live Connection Test Suite (realistic endpoint coverage)
.DESCRIPTION
    Tests every actual endpoint the R3 stack exposes.
    Fixed issues from v1:
      - LiteLLM /health has slow first-response → longer timeout
      - LiteLLM chat: auto-discovers first available model instead of hardcoding
      - :8422/mcp doesn't exist → probes real control-plane routes
      - /acp doesn't exist on ChatLegs → replaced with OpenAI-compat + proxy tests
.EXAMPLE
    iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/scripts/Test-R3-ACP-MultiConnect.ps1" -OutFile "$env:TEMP\r3test.ps1"; & "$env:TEMP\r3test.ps1"
#>

$ErrorActionPreference = "SilentlyContinue"
$r3ApiKey = if ($env:R3_API_KEY) { $env:R3_API_KEY } else { "r3-local" }
$hdr = @{ Authorization = "Bearer $r3ApiKey"; "Content-Type" = "application/json" }

$results = @()
$pass = 0; $fail = 0; $skip = 0

function Test-Step {
    param(
        [string]$Name,
        [scriptblock]$Block,
        [string]$Section = ""
    )
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

function Skip-Step {
    param([string]$Name, [string]$Reason)
    Write-Host "  ► $Name ... " -NoNewline
    Write-Host "SKIP  ($Reason)" -ForegroundColor DarkGray
    $script:skip++
    $script:results += [pscustomobject]@{ Step=$Name; Status="SKIP"; Detail=$Reason }
}

Write-Host ""
Write-Host "  R3-DASHBOARD Live Connection Test Suite" -ForegroundColor Cyan
Write-Host "  ========================================" -ForegroundColor Cyan
Write-Host ""

# ─── 1. LiteLLM Gateway :4000 ───────────────────────────────────────────────
Write-Host "[ 1 ] LiteLLM Gateway :4000" -ForegroundColor Yellow

Test-Step "GET /v1/models (gateway alive)" {
    $r = Invoke-RestMethod "http://localhost:4000/v1/models" -Headers $hdr -TimeoutSec 10
    $r.data.Count -gt 0
}

# Discover first available model dynamically
$availableModel = $null
try {
    $models = Invoke-RestMethod "http://localhost:4000/v1/models" -Headers $hdr -TimeoutSec 10
    $availableModel = $models.data[0].id
} catch {}

if ($availableModel) {
    Write-Host "    → Auto-detected model: $availableModel" -ForegroundColor DarkGray

    Test-Step "POST /v1/chat/completions ($availableModel)" {
        $body = @{
            model    = $availableModel
            messages = @(@{ role="user"; content="Reply with exactly: R3_OK" })
            max_tokens = 10
        } | ConvertTo-Json -Compress
        $r = Invoke-RestMethod -Method Post "http://localhost:4000/v1/chat/completions" `
             -Headers $hdr -Body $body -TimeoutSec 30
        $r.choices[0].message.content.Length -gt 0
    }
} else {
    Skip-Step "POST /v1/chat/completions" "no model detected from /v1/models"
}

Test-Step "GET /health (slow endpoint — 15s)" {
    $r = Invoke-RestMethod "http://localhost:4000/health" -Headers $hdr -TimeoutSec 15
    $r -ne $null
}

# ─── 2. ChatLegs MCP SSE :8420 / :8421 ─────────────────────────────────────
Write-Host ""
Write-Host "[ 2 ] ChatLegs MCP SSE Endpoints" -ForegroundColor Yellow

foreach ($port in @(8420, 8421)) {
    Test-Step "GET :$port/mcp (SSE endpoint alive)" {
        $r = Invoke-WebRequest "http://localhost:$port/mcp" -Method Get `
             -TimeoutSec 8 -UseBasicParsing
        $r.StatusCode -lt 500
    }
}

# MCP SSE — correct usage: GET with Accept: text/event-stream
foreach ($port in @(8420, 8421)) {
    Test-Step "GET :$port/mcp with SSE headers" {
        $r = Invoke-WebRequest "http://localhost:$port/mcp" -Method Get `
             -Headers @{ Accept="text/event-stream" } -TimeoutSec 8 -UseBasicParsing
        $r.StatusCode -lt 500
    }
}

# ─── 3. ChatLegs OpenAI-compatible API :8420 / :8421 ────────────────────────
Write-Host ""
Write-Host "[ 3 ] ChatLegs OpenAI-Compatible Proxy" -ForegroundColor Yellow

foreach ($port in @(8420, 8421)) {
    Test-Step "GET :$port/ (root alive)" {
        $r = Invoke-WebRequest "http://localhost:$port/" -Method Get `
             -TimeoutSec 8 -UseBasicParsing
        $r.StatusCode -lt 500
    }
}

if ($availableModel) {
    foreach ($port in @(8420, 8421)) {
        Test-Step "POST :$port/v1/chat/completions (direct proxy)" {
            $body = @{
                model    = $availableModel
                messages = @(@{ role="user"; content="Ping" })
                max_tokens = 5
            } | ConvertTo-Json -Compress
            $r = Invoke-RestMethod -Method Post "http://localhost:$port/v1/chat/completions" `
                 -Headers $hdr -Body $body -TimeoutSec 20
            $r.choices[0].message.content.Length -gt 0
        }
    }
} else {
    foreach ($port in @(8420, 8421)) {
        Skip-Step ":$port/v1/chat/completions" "no model available"
    }
}

# ─── 4. Matrix Control Plane :8422 ──────────────────────────────────────────
Write-Host ""
Write-Host "[ 4 ] Matrix Control Plane :8422" -ForegroundColor Yellow

# Probe common control-plane routes
$ctrl8422Routes = @("/", "/api", "/api/status", "/status", "/health", "/engines", "/api/engines")
$found8422 = @()
foreach ($route in $ctrl8422Routes) {
    try {
        $r = Invoke-WebRequest "http://localhost:8422$route" -Method Get `
             -TimeoutSec 5 -UseBasicParsing
        if ($r.StatusCode -lt 500) {
            $found8422 += "$route → HTTP $($r.StatusCode)"
        }
    } catch {}
}

if ($found8422.Count -gt 0) {
    Write-Host "    → :8422 live routes found:" -ForegroundColor DarkGray
    $found8422 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    $pass++
    $results += [pscustomobject]@{ Step=":8422 route probe"; Status="PASS"; Detail=($found8422 -join ", ") }
} else {
    Write-Host "  ► :8422 route probe ... " -NoNewline
    Write-Host "FAIL  (no routes responded <500)" -ForegroundColor Red
    $fail++
    $results += [pscustomobject]@{ Step=":8422 route probe"; Status="FAIL"; Detail="all probed routes returned 4xx/5xx or timed out" }
}

# :8422 — Note: /mcp NOT available on this server (confirmed 404)
Skip-Step ":8422/mcp" "control plane does not expose /mcp (confirmed 404)"

# ─── 5. VS Code MCP Config ────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 5 ] VS Code MCP Config" -ForegroundColor Yellow

$mcpPath = "$env:APPDATA\Code\User\mcp.json"
Test-Step "mcp.json exists at $mcpPath" {
    Test-Path $mcpPath
}

if (Test-Path $mcpPath) {
    Test-Step "mcp.json is valid JSON" {
        $j = Get-Content $mcpPath -Raw | ConvertFrom-Json
        $j.servers -ne $null
    }
    Test-Step "mcp.json has r3-chatlegs-primary entry" {
        $j = Get-Content $mcpPath -Raw | ConvertFrom-Json
        $j.servers."r3-chatlegs-primary" -ne $null
    }
} else {
    Skip-Step "mcp.json valid JSON" "file not found"
    Skip-Step "mcp.json r3-chatlegs-primary entry" "file not found"
    Write-Host "    → Install: iwr 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/scripts/Install-R3-VSCode-MCP.ps1' -OutFile `"`$env:TEMP\r3mcp.ps1`"; & `"`$env:TEMP\r3mcp.ps1`"" -ForegroundColor DarkYellow
}

# ─── 6. Engine Registry ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 6 ] Engine Registry" -ForegroundColor Yellow

$regPath = "C:\Users\mail\R3-DASHBOARD\engine-registry.json"
Test-Step "engine-registry.json exists" {
    Test-Path $regPath
}

if (Test-Path $regPath) {
    Test-Step "engine-registry.json valid JSON" {
        $j = Get-Content $regPath -Raw | ConvertFrom-Json
        $j -ne $null
    }
}

# ─── Summary ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
$col = if ($fail -eq 0) { "Green" } elseif ($pass -ge $fail) { "Yellow" } else { "Red" }
Write-Host "  PASS: $pass  FAIL: $fail  SKIP: $skip" -ForegroundColor $col
Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
$results | Format-Table Step, Status, Detail -AutoSize -Wrap

# Quick-fix hints
Write-Host ""
if (($results | Where-Object { $_.Step -like "*mcp.json*" -and $_.Status -eq "FAIL" })) {
    Write-Host "  [FIX] Install VS Code MCP config:" -ForegroundColor DarkYellow
    Write-Host "    iwr 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/scripts/Install-R3-VSCode-MCP.ps1' -OutFile `"`$env:TEMP\r3mcp.ps1`"; & `"`$env:TEMP\r3mcp.ps1`"" -ForegroundColor DarkGray
}
if (($results | Where-Object { $_.Step -like "*:8422*" -and $_.Status -eq "FAIL" })) {
    Write-Host "  [FIX] Start all servers:" -ForegroundColor DarkYellow
    Write-Host "    iwr 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/scripts/Start-R3-AllServers.ps1' -OutFile `"`$env:TEMP\r3start.ps1`"; & `"`$env:TEMP\r3start.ps1`"" -ForegroundColor DarkGray
}
if (($results | Where-Object { $_.Step -like "*chat/completions*" -and $_.Status -eq "FAIL" })) {
    Write-Host "  [FIX] LiteLLM chat fail — check model availability:" -ForegroundColor DarkYellow
    Write-Host "    Invoke-RestMethod 'http://localhost:4000/v1/models' -Headers @{Authorization='Bearer r3-local'} | Select -Exp data | Select id" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "  Docs: https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/config/acp-config.json" -ForegroundColor DarkGray
Write-Host ""
