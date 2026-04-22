# Start-LiteLLM.ps1 — R3 LiteLLM Gateway (Windows / RAZER)
# Run from C:\Users\mail\R3-DASHBOARD\_automation\ OR any directory
# Usage:
#   .\Start-LiteLLM.ps1          # foreground
#   .\Start-LiteLLM.ps1 -Bg      # background (Start-Process)
#   .\Start-LiteLLM.ps1 -Install # pip-install litellm first, then start

param(
  [switch]$Bg,
  [switch]$Install,
  [string]$ConfigPath = "",
  [int]$Port = 4000
)

$ErrorActionPreference = "Stop"

# ── Locate config ────────────────────────────────────────────────────────────
if ($ConfigPath -eq "") {
  # Look relative to script location, then R3-DASHBOARD root
  $candidates = @(
    (Join-Path $PSScriptRoot "..\litellm-config.yaml"),
    "C:\Users\mail\R3-DASHBOARD\litellm-config.yaml",
    "$HOME\R3-DASHBOARD\litellm-config.yaml"
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { $ConfigPath = (Resolve-Path $c).Path; break }
  }
}

if ($ConfigPath -eq "" -or -not (Test-Path $ConfigPath)) {
  Write-Host "❌ litellm-config.yaml not found. Provide -ConfigPath or place it in R3-DASHBOARD root." -ForegroundColor Red
  Write-Host "   Expected: C:\Users\mail\R3-DASHBOARD\litellm-config.yaml" -ForegroundColor Yellow
  exit 1
}

Write-Host "[Start-LiteLLM] Config: $ConfigPath" -ForegroundColor DarkCyan

# ── Install if requested ─────────────────────────────────────────────────────
if ($Install) {
  Write-Host "[Start-LiteLLM] Installing litellm[proxy]..." -ForegroundColor Cyan
  pip install "litellm[proxy]" --upgrade
}

# ── Locate litellm binary ─────────────────────────────────────────────────────
$litellmCmd = $null
foreach ($try in @("litellm", "python -m litellm")) {
  try {
    $ver = & litellm --version 2>&1
    if ($LASTEXITCODE -eq 0 -or $ver -match "\d") { $litellmCmd = "litellm"; break }
  } catch {}
}
if (-not $litellmCmd) {
  Write-Host "❌ litellm not found. Run: pip install 'litellm[proxy]'" -ForegroundColor Red
  Write-Host "   Or re-run with: .\Start-LiteLLM.ps1 -Install" -ForegroundColor Yellow
  exit 1
}

# ── Check if already running ─────────────────────────────────────────────────
$listening = netstat -ano 2>$null | Select-String ":$Port\s.*LISTENING"
if ($listening) {
  Write-Host "[Start-LiteLLM] ✅ Port $Port already in use — LiteLLM may already be running" -ForegroundColor Green
  exit 0
}

# ── Load .env ────────────────────────────────────────────────────────────────
$envFile = Join-Path (Split-Path $ConfigPath) ".env"
if (-not (Test-Path $envFile)) {
  $envFile = "C:\Users\mail\R3-DASHBOARD\.env"
}
if (Test-Path $envFile) {
  Write-Host "[Start-LiteLLM] Loading $envFile" -ForegroundColor DarkGray
  Get-Content $envFile | ForEach-Object {
    if ($_ -match "^\s*([^#][^=]+)=(.*)$") {
      [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
    }
  }
} else {
  Write-Host "[Start-LiteLLM] No .env found — placeholder keys (models will report unhealthy)" -ForegroundColor Yellow
}

# ── Set master key ────────────────────────────────────────────────────────────
if (-not $env:LITELLM_MASTER_KEY) { $env:LITELLM_MASTER_KEY = "r3-local" }
Write-Host "[Start-LiteLLM] Master key: $env:LITELLM_MASTER_KEY" -ForegroundColor DarkGray

# ── Start ─────────────────────────────────────────────────────────────────────
$args = @("--config", $ConfigPath, "--port", $Port, "--host", "0.0.0.0")

if ($Bg) {
  $logFile = "$env:TEMP\litellm-r3.log"
  Write-Host "[Start-LiteLLM] Starting in background → $logFile" -ForegroundColor Cyan
  Start-Process -FilePath "litellm" -ArgumentList $args `
    -RedirectStandardOutput $logFile -RedirectStandardError "$env:TEMP\litellm-r3.err" `
    -NoNewWindow -PassThru | ForEach-Object {
      Write-Host "[Start-LiteLLM] PID $($_.Id) — tail log: Get-Content $logFile -Wait" -ForegroundColor Green
    }
} else {
  Write-Host "[Start-LiteLLM] Starting on :$Port (foreground — Ctrl+C to stop)" -ForegroundColor Cyan
  & litellm @args
}
