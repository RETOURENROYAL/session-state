# ============================================================
# R3-DASHBOARD -- M1 Setup: MCP-Server + Zero-Cost-Gateway
# Speichern als .ps1 und ausfuehren -- NICHT direkt ins Terminal kopieren!
# Keys werden aus bestehenden .env-Dateien gelesen, nie angezeigt.
# ============================================================

$R3Root    = "C:\Users\mail\R3-DASHBOARD"
$EnvSource = "$R3Root\SOURCE\chat-legs\.env"
$EnvLocal  = "$R3Root\SOURCE\chat-legs\.env.local"
$RegDir    = "$R3Root\R3_LLM_ENGINE_REGISTRY"

# Hilfsfunktion: .env-Datei einlesen
function Read-EnvFile($path) {
    $ht = @{}
    if (-not (Test-Path $path)) { return $ht }
    Get-Content $path | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#') -and $line -match '^([^=]+)=(.*)$') {
            $ht[$Matches[1].Trim()] = $Matches[2].Trim().Trim('"').Trim("'")
        }
    }
    return $ht
}

# .env.local ueberschreibt .env
$env1 = Read-EnvFile $EnvSource
$env2 = Read-EnvFile $EnvLocal
$keys = @{}
$env1.GetEnumerator() | ForEach-Object { $keys[$_.Key] = $_.Value }
$env2.GetEnumerator() | ForEach-Object { $keys[$_.Key] = $_.Value }
Write-Host "[OK] Env-Keys geladen"

# Prozess-Environment setzen (nur dieser Prozess, nie in Logs)
$keyNames = @(
    'GROQ_API_KEY','CEREBRAS_API_KEY','SAMBANOVA_API_KEY',
    'OPENROUTER_API_KEY','HUGGINGFACE_API_KEY','CHUTES_API_KEY',
    'GLAMA_API_KEY','LITELLM_MASTER_KEY'
)
foreach ($k in $keyNames) {
    if ($keys.ContainsKey($k) -and $keys[$k]) {
        [System.Environment]::SetEnvironmentVariable($k, $keys[$k], 'Process')
    }
}
if (-not $env:LITELLM_MASTER_KEY) {
    [System.Environment]::SetEnvironmentVariable('LITELLM_MASTER_KEY', 'r3-local', 'Process')
}
Write-Host "[OK] Environment-Variablen gesetzt (nur dieser Prozess)"

# ── 1. VS Code mcp.json schreiben ───────────────────────────
$mcpPath = "$env:APPDATA\Code\User\mcp.json"

$newServers = [pscustomobject]@{
    "r3-chatlegs-primary" = [pscustomobject]@{ type = "sse"; url = "http://localhost:8420/mcp" }
    "r3-chatlegs-shadow"  = [pscustomobject]@{ type = "sse"; url = "http://localhost:8421/mcp" }
    "r3-matrix-control"   = [pscustomobject]@{ type = "sse"; url = "http://localhost:8422/mcp" }
}

if (Test-Path $mcpPath) {
    $existing = Get-Content $mcpPath -Raw | ConvertFrom-Json
    if (-not $existing.servers) {
        $existing | Add-Member -MemberType NoteProperty -Name "servers" -Value $newServers
        $existing | ConvertTo-Json -Depth 5 | Set-Content $mcpPath -Encoding UTF8
        Write-Host "[OK] mcp.json -- Server-Eintraege ergaenzt"
    } else {
        $changed = $false
        $portMap = @{
            "r3-chatlegs-primary" = 8420
            "r3-chatlegs-shadow"  = 8421
            "r3-matrix-control"   = 8422
        }
        foreach ($srv in $portMap.Keys) {
            if (-not $existing.servers.$srv) {
                $entry = [pscustomobject]@{ type = "sse"; url = "http://localhost:$($portMap[$srv])/mcp" }
                $existing.servers | Add-Member -MemberType NoteProperty -Name $srv -Value $entry
                $changed = $true
            }
        }
        if ($changed) {
            $existing | ConvertTo-Json -Depth 5 | Set-Content $mcpPath -Encoding UTF8
            Write-Host "[OK] mcp.json -- fehlende Server nachgetragen"
        } else {
            Write-Host "[SKIP] mcp.json -- alle Server bereits eingetragen"
        }
    }
} else {
    New-Item -ItemType File -Path $mcpPath -Force | Out-Null
    [pscustomobject]@{ servers = $newServers } | ConvertTo-Json -Depth 5 | Set-Content $mcpPath -Encoding UTF8
    Write-Host "[OK] mcp.json erstellt: $mcpPath"
}

# ── 2. config\mcp-servers.json im Registry-Verzeichnis ──────
if (-not (Test-Path "$RegDir\config")) { New-Item -ItemType Directory "$RegDir\config" | Out-Null }
[pscustomobject]@{ servers = $newServers } | ConvertTo-Json -Depth 5 |
    Set-Content "$RegDir\config\mcp-servers.json" -Encoding UTF8
Write-Host "[OK] Registry-Config: $RegDir\config\mcp-servers.json"

# ── 3. Start-Skript fuer LiteLLM-Gateway ────────────────────
$startGateway = @'
# R3 Zero-Cost Gateway Starter
# Liest API-Keys aus SOURCE\chat-legs\.env -- nicht anzeigen!

$R3Root = "C:\Users\mail\R3-DASHBOARD"

function Load-Env($p) {
    if (-not (Test-Path $p)) { return }
    Get-Content $p | ForEach-Object {
        $l = $_.Trim()
        if ($l -and -not $l.StartsWith('#') -and $l -match '^([^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable(
                $Matches[1].Trim(),
                $Matches[2].Trim().Trim('"').Trim("'"),
                'Process'
            )
        }
    }
}

Load-Env "$R3Root\SOURCE\chat-legs\.env"
Load-Env "$R3Root\SOURCE\chat-legs\.env.local"

if (-not $env:LITELLM_MASTER_KEY) { $env:LITELLM_MASTER_KEY = "r3-local" }

Write-Host "[R3] Zero-Cost Gateway startet auf Port 4000 ..."
Write-Host "[R3] Default: groq/llama-3.3-70b  |  Fallback: cerebras -> sambanova -> ollama"
Set-Location $R3Root
litellm --config "$R3Root\litellm-config.yaml" --port 4000
'@

$startOut = "$R3Root\Start-R3-ZeroCost-Gateway.ps1"
$startGateway | Set-Content $startOut -Encoding UTF8
Write-Host "[OK] Gateway-Starter: $startOut"

# ── Zusammenfassung ──────────────────────────────────────────
Write-Host ""
Write-Host "============================================="
Write-Host " R3 M1 Setup abgeschlossen"
Write-Host "============================================="
Write-Host " VS Code MCP  : $mcpPath"
Write-Host " Gateway-Start: $startOut"
Write-Host " Key-Quelle   : $EnvSource"
Write-Host ""
Write-Host " Naechste Schritte:"
Write-Host "  1. .\Start-R3-ZeroCost-Gateway.ps1 ausfuehren"
Write-Host "  2. ChatLegs (8420/8421) + Control-Plane (8422) starten"
Write-Host "  3. VS Code: Ctrl+Shift+P -> Reload Window"
Write-Host "============================================="
