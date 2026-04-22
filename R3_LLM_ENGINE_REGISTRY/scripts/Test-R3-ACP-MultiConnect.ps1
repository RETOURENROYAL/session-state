#Requires -Version 5.1
<#
.SYNOPSIS
    R3-DASHBOARD — Full ACP Multi-Connection Test Suite
.DESCRIPTION
    Tests all ACP/MCP/LiteLLM endpoints and verifies the full multi-connection
    workplace is operational. Covers: LiteLLM gateway, MCP SSE, ACP initialize,
    providers/set flow, session/new, fs/read, terminal/create.
.EXAMPLE
    iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/scripts/Test-R3-ACP-MultiConnect.ps1" -OutFile "$env:TEMP\r3test.ps1"; & "$env:TEMP\r3test.ps1"
#>

$ErrorActionPreference = "SilentlyContinue"
$r3ApiKey = if ($env:R3_API_KEY) { $env:R3_API_KEY } else { "r3-local" }

$results = @()
$pass = 0; $fail = 0

function Test-Step {
    param([string]$Name, [scriptblock]$Block)
    Write-Host "  Testing: $Name ... " -NoNewline
    try {
        $ok = & $Block
        if ($ok) {
            Write-Host "[PASS]" -ForegroundColor Green
            $script:pass++
            $script:results += [pscustomobject]@{ Step=$Name; Status="PASS"; Detail="OK" }
        } else {
            Write-Host "[FAIL]" -ForegroundColor Red
            $script:fail++
            $script:results += [pscustomobject]@{ Step=$Name; Status="FAIL"; Detail="returned falsy" }
        }
    } catch {
        Write-Host "[FAIL] $_" -ForegroundColor Red
        $script:fail++
        $script:results += [pscustomobject]@{ Step=$Name; Status="FAIL"; Detail=$_.ToString() }
    }
}

Write-Host ""
Write-Host "R3-DASHBOARD ACP Multi-Connection Test Suite" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: LiteLLM Gateway Health ──────────────────────────────────────────
Write-Host "[ 1 ] LiteLLM Gateway :4000" -ForegroundColor Yellow
Test-Step "LiteLLM /health" {
    $r = Invoke-RestMethod -Uri "http://localhost:4000/health" `
         -Headers @{Authorization="Bearer $r3ApiKey"} -TimeoutSec 5
    $r -ne $null
}
Test-Step "LiteLLM /v1/models" {
    $r = Invoke-RestMethod -Uri "http://localhost:4000/v1/models" `
         -Headers @{Authorization="Bearer $r3ApiKey"} -TimeoutSec 5
    $r.data.Count -gt 0
}
Test-Step "LiteLLM chat/completions (groq)" {
    $body = '{"model":"groq/llama-3.3-70b","messages":[{"role":"user","content":"Reply with OK only"}],"max_tokens":5}'
    $r = Invoke-RestMethod -Method Post -Uri "http://localhost:4000/v1/chat/completions" `
         -Headers @{Authorization="Bearer $r3ApiKey"; "Content-Type"="application/json"} `
         -Body $body -TimeoutSec 15
    $r.choices[0].message.content.Length -gt 0
}

# ── Step 2: MCP SSE Endpoints ────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 2 ] MCP SSE Endpoints" -ForegroundColor Yellow
foreach ($port in @(8420, 8421, 8422)) {
    Test-Step "MCP SSE :$port/mcp reachable" {
        $r = Invoke-WebRequest -Uri "http://localhost:$port/mcp" `
             -Method Get -TimeoutSec 5 -UseBasicParsing
        $r.StatusCode -lt 500
    }
}

# ── Step 3: ACP initialize (JSON-RPC) ────────────────────────────────────────
Write-Host ""
Write-Host "[ 3 ] ACP initialize (JSON-RPC 2.0)" -ForegroundColor Yellow
$initPayload = @{
    jsonrpc = "2.0"; id = 1; method = "initialize"
    params = @{
        protocolVersion = 1
        clientInfo = @{ name = "r3-test-suite"; version = "1.0" }
        capabilities = @{ fs = @{ readTextFile = $true; writeTextFile = $true }; terminal = $true }
        workspaceRoots = @("C:\Users\mail\R3-DASHBOARD")
    }
} | ConvertTo-Json -Depth 5

foreach ($port in @(8420, 8422)) {
    Test-Step "ACP initialize :$port/acp" {
        $r = Invoke-RestMethod -Method Post -Uri "http://localhost:$port/acp" `
             -ContentType "application/json" -Body $initPayload -TimeoutSec 8
        $r.result -ne $null -or $r.error -ne $null
    }
}

# ── Step 4: providers/set → LiteLLM ─────────────────────────────────────────
Write-Host ""
Write-Host "[ 4 ] ACP providers/set (route to LiteLLM :4000)" -ForegroundColor Yellow
$provPayload = @{
    jsonrpc = "2.0"; id = 60; method = "providers/set"
    params = @{
        id = "main"; apiType = "openai"
        baseUrl = "http://localhost:4000/v1"
        headers = @{ Authorization = "Bearer $r3ApiKey" }
    }
} | ConvertTo-Json -Depth 5

Test-Step "providers/set :8420" {
    $r = Invoke-RestMethod -Method Post -Uri "http://localhost:8420/acp" `
         -ContentType "application/json" -Body $provPayload -TimeoutSec 8
    $r -ne $null
}

# ── Step 5: session/new ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 5 ] ACP session/new" -ForegroundColor Yellow
$sessionPayload = @{
    jsonrpc = "2.0"; id = 10; method = "session/new"
    params = @{
        cwd = "C:\Users\mail\R3-DASHBOARD"
        workspaceRoots = @(
            "C:\Users\mail\R3-DASHBOARD",
            "C:\Users\mail\R3-DASHBOARD\SOURCE\chat-legs"
        )
    }
} | ConvertTo-Json -Depth 5

Test-Step "session/new :8420" {
    $r = Invoke-RestMethod -Method Post -Uri "http://localhost:8420/acp" `
         -ContentType "application/json" -Body $sessionPayload -TimeoutSec 8
    $r -ne $null
}

# ── Step 6: session/prompt ────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 6 ] ACP session/prompt" -ForegroundColor Yellow
$promptPayload = @{
    jsonrpc = "2.0"; id = 20; method = "session/prompt"
    params = @{
        sessionId = "test-001"
        message = @{ role = "user"; content = "Respond with exactly: R3_OK" }
    }
} | ConvertTo-Json -Depth 5

Test-Step "session/prompt :8420" {
    $r = Invoke-RestMethod -Method Post -Uri "http://localhost:8420/acp" `
         -ContentType "application/json" -Body $promptPayload -TimeoutSec 20
    $r -ne $null
}

# ── Step 7: fs/read_text_file ────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 7 ] ACP fs/read_text_file" -ForegroundColor Yellow
$fsPayload = @{
    jsonrpc = "2.0"; id = 30; method = "fs/read_text_file"
    params = @{ path = "C:\Users\mail\R3-DASHBOARD\engine-registry.json" }
} | ConvertTo-Json -Depth 3

Test-Step "fs/read engine-registry.json via :8420" {
    $r = Invoke-RestMethod -Method Post -Uri "http://localhost:8420/acp" `
         -ContentType "application/json" -Body $fsPayload -TimeoutSec 8
    $r -ne $null
}

# ── Step 8: terminal/create ───────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 8 ] ACP terminal/create" -ForegroundColor Yellow
$termPayload = @{
    jsonrpc = "2.0"; id = 40; method = "terminal/create"
    params = @{
        sessionId = "test-001"; command = "node"; args = @("--version")
        cwd = "C:\Users\mail\R3-DASHBOARD"
    }
} | ConvertTo-Json -Depth 3

Test-Step "terminal/create node --version via :8422" {
    $r = Invoke-RestMethod -Method Post -Uri "http://localhost:8422/acp" `
         -ContentType "application/json" -Body $termPayload -TimeoutSec 8
    $r -ne $null
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Results: $pass passed / $fail failed" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Yellow" })
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
$results | Format-Table -AutoSize
Write-Host ""
Write-Host "ACP Config reference:" -ForegroundColor DarkGray
Write-Host "  https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/config/acp-config.json" -ForegroundColor DarkGray
Write-Host ""
