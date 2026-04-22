# ============================================================
# R3 — Install VS Code User-Level MCP Config
# Places mcp.json in %APPDATA%\Code\User\
# so VS Code recognises r3-chatlegs-primary/:8420,
# r3-chatlegs-shadow/:8421, r3-matrix-control/:8422
# ============================================================

$raw  = 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/config/mcp.json'
$dest = "$env:APPDATA\Code\User\mcp.json"
$dir  = Split-Path $dest

if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

# Backup existing file
if (Test-Path $dest) {
    $bak = "$dest.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $dest $bak
    Write-Host "[BAK] Existing mcp.json backed up: $bak" -ForegroundColor Gray
}

try {
    Invoke-WebRequest $raw -OutFile $dest -UseBasicParsing
    Write-Host "[OK] mcp.json installed: $dest" -ForegroundColor Green
} catch {
    Write-Host "[ERR] Download failed: $_" -ForegroundColor Red
    exit 1
}

# Verify
$content = Get-Content $dest -Raw | ConvertFrom-Json
$count   = ($content.servers | Get-Member -MemberType NoteProperty).Count
Write-Host "[OK] $count MCP servers registered:" -ForegroundColor Green
$content.servers | Get-Member -MemberType NoteProperty | ForEach-Object {
    $url = $content.servers.$($_.Name).url
    Write-Host "  ·  $($_.Name)  -->  $url" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Next: Reload VS Code window (Ctrl+Shift+P → Reload Window)" -ForegroundColor Yellow
Write-Host "Then: Ctrl+Shift+P → MCP: List Servers  — should show 3 entries" -ForegroundColor Yellow
