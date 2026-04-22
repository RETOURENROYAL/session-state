<#
.SYNOPSIS
  R3 n8n GitHub API Stack — PowerShell Installer (Windows / R3-DASHBOARD)
.USAGE
  # Remote (one-liner):
  iwr 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Install-R3-n8n.ps1' -UseB | iex

  # Local:
  .\Install-R3-n8n.ps1
#>

$RepoRaw   = "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY"
$TargetDir = "C:\Users\mail\R3-DASHBOARD\n8n-local"
$WfDir     = "$TargetDir\workflows"
$DashDir   = "$TargetDir\dashboard"

Write-Host ""
Write-Host "  ██████╗ ██████╗     ███╗   ██╗ █████╗ ███╗   ██╗" -ForegroundColor Cyan
Write-Host "  GitHub API n8n Stack Installer" -ForegroundColor White
Write-Host "  Target: $TargetDir" -ForegroundColor Gray
Write-Host ""

New-Item -ItemType Directory -Force -Path $WfDir, $DashDir | Out-Null

function Download($url, $dest) {
    try { Invoke-WebRequest $url -OutFile $dest -UseBasicParsing; Write-Host "    ✓ $([IO.Path]::GetFileName($dest))" -ForegroundColor Green }
    catch { Write-Host "    ✗ FAILED: $([IO.Path]::GetFileName($dest)) — $_" -ForegroundColor Red }
}

# 1. Dashboard
Write-Host "[1/4] Downloading dashboard..."
Download "$RepoRaw/dashboard/index.html" "$DashDir\index.html"

# 2. Universal workflow
Write-Host "[2/4] Downloading universal workflow..."
Download "$RepoRaw/n8n-workflows/n8n-github-universal.json" "$WfDir\n8n-github-universal.json"

# 3. Individual workflows
Write-Host "[3/4] Downloading individual workflows..."
$Workflows = @(
  "wf-workflow-runs-list","wf-workflow-runs-trigger","wf-workflow-runs-cancel","wf-workflow-runs-rerun",
  "wf-secrets-repo-list","wf-secrets-repo-pubkey","wf-secrets-org-list",
  "wf-runners-self-list-repo","wf-runners-self-list-org","wf-runners-self-reg-token",
  "wf-runners-hosted-list","wf-runners-hosted-images",
  "wf-runner-groups-list","wf-runner-groups-create",
  "wf-codespaces-list","wf-codespaces-start","wf-codespaces-stop","wf-codespaces-secrets-list",
  "wf-git-refs-list","wf-git-blob-create","wf-git-commit-create",
  "wf-orgs-members-list","wf-orgs-repos-list","wf-orgs-audit-log",
  "wf-auth-rate-limit","wf-auth-user","wf-installations-list"
)
foreach ($wf in $Workflows) { Download "$RepoRaw/n8n-workflows/workflows/$wf.json" "$WfDir\$wf.json" }

# 4. Endpoint reference
Write-Host "[4/4] Downloading endpoint reference..."
Download "$RepoRaw/config/github-api-endpoints.json" "$TargetDir\github-api-endpoints.json"

# Find a free port starting at 5678
function Get-FreePort([int]$start=5678) {
    $used = (netstat -ano | Select-String "TCP.*:(\d+)\s" | ForEach-Object { $_.Matches.Groups[1].Value }) -as [int[]]
    $p = $start
    while ($used -contains $p) { $p++ }
    return $p
}
$N8N_PORT = Get-FreePort 5678
if ($N8N_PORT -ne 5678) {
    Write-Host "  ⚠  Port 5678 belegt → verwende Port $N8N_PORT" -ForegroundColor Yellow
}

# Write docker-compose (no 'version' — obsolete in Compose v2)
@"
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: r3-n8n
    restart: unless-stopped
    ports:
      - "${N8N_PORT}:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=false
      - WEBHOOK_URL=http://localhost:${N8N_PORT}
      - GENERIC_TIMEZONE=Europe/Berlin
      - N8N_DEFAULT_LOCALE=de
      - N8N_LOG_LEVEL=warn
    volumes:
      - n8n_data:/home/node/.n8n
      - ./workflows:/workflows:ro
volumes:
  n8n_data:
"@ | Set-Content "$TargetDir\docker-compose.yml" -Encoding UTF8

# Check GITHUB_TOKEN
if (-not $env:GITHUB_TOKEN) {
    Write-Host ""
    Write-Host "  ⚠  GITHUB_TOKEN nicht gesetzt." -ForegroundColor Yellow
    Write-Host "     Setze ihn mit: `$env:GITHUB_TOKEN = 'ghp_...'" -ForegroundColor Gray
    Write-Host ""
}

# Start n8n?
$start = Read-Host "  ▶ n8n jetzt starten? (Docker required) [y/N]"
if ($start -match '^[yY]') {
    Set-Location $TargetDir
    # Remove existing container to avoid name conflict
    docker rm -f r3-n8n 2>$null | Out-Null
    docker compose up -d
    if ($LASTEXITCODE -eq 0) {
        Start-Sleep 6
        Write-Host "  ✓ n8n laeuft auf http://localhost:$N8N_PORT" -ForegroundColor Green
        Start-Process "http://localhost:$N8N_PORT"
        Start-Process "$DashDir\index.html"
    } else {
        Write-Host "  ✗ docker compose up fehlgeschlagen" -ForegroundColor Red
        Write-Host "  Manuell: cd $TargetDir; docker compose up -d" -ForegroundColor Gray
    }
} else {
    Write-Host ""
    Write-Host "  Manuelle Schritte:" -ForegroundColor Cyan
    Write-Host "    cd $TargetDir"
    Write-Host "    `$env:GITHUB_TOKEN = 'ghp_...'"
    Write-Host "    docker compose up -d"
    Write-Host "    start $DashDir\index.html"
}

Write-Host ""
Write-Host "  ═══════════════════════════════════════════════════" -ForegroundColor DarkCyan
Write-Host "  ✓ Installation abgeschlossen" -ForegroundColor Green
Write-Host "  📁 Dateien:  $TargetDir" -ForegroundColor White
Write-Host "  🌐 Dashboard: $DashDir\index.html" -ForegroundColor White
Write-Host "  🔗 n8n:      http://localhost:$N8N_PORT" -ForegroundColor White
Write-Host "  ═══════════════════════════════════════════════════" -ForegroundColor DarkCyan
