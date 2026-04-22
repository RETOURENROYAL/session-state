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

$N8N_PORT = 5678

# Write docker-compose (no 'version' — obsolete in Compose v2)
@"
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: r3-n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=false
      - WEBHOOK_URL=http://localhost:5678
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

    # Check if port 5678 is already in use (n8n already running)
    $running = docker ps -q --filter "publish=5678" 2>$null
    if ($running) {
        $name = docker inspect --format '{{.Name}}' $running 2>$null
        Write-Host "  ✓ n8n laeuft bereits ($name) auf http://localhost:5678" -ForegroundColor Green
        Write-Host "    Bestehende Workflows und Daten bleiben unangetastet." -ForegroundColor Gray
        Start-Process "http://localhost:5678"
        Start-Process "$DashDir\index.html"
    } else {
        # Remove stopped r3-n8n container if it exists (won't affect running containers)
        docker rm -f r3-n8n 2>$null | Out-Null

        docker compose up -d
        if ($LASTEXITCODE -eq 0) {
            Start-Sleep 6
            Write-Host "  ✓ n8n laeuft auf http://localhost:5678" -ForegroundColor Green
            Start-Process "http://localhost:5678"
            Start-Process "$DashDir\index.html"
        } else {
            Write-Host "  ✗ docker compose up fehlgeschlagen" -ForegroundColor Red
            Write-Host "  Diagnose: docker ps -a --filter publish=5678" -ForegroundColor Gray
            Write-Host "  Manuell:  cd $TargetDir; docker compose up -d" -ForegroundColor Gray
        }
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
Write-Host "  🔗 n8n:      http://localhost:5678" -ForegroundColor White
Write-Host "  ═══════════════════════════════════════════════════" -ForegroundColor DarkCyan
