#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Installs the R³ VIB.E Vibe Agent into r-vib3.
  - Writes all 5 source files
  - Installs @copilotkit/react-core @copilotkit/react-ui
  - Patches package.json dev:mcp (Windows fix)

  One-liner:
  & ([scriptblock]::Create((iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/r-vib3-integration/vibe-agent/install.ps1?r=$(Get-Random)").Content))
#>

$ROOT    = "C:\Users\mail\R3-DASHBOARD\r-vib3"
$BASE    = "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/r-vib3-integration/vibe-agent"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   R³ VIB.E — Vibe Agent Install               ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan

function Fetch-File($src, $dest) {
  $dir = Split-Path $dest
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $content = (iwr "$BASE/$src?r=$(Get-Random)").Content
  [System.IO.File]::WriteAllText($dest, $content, [System.Text.Encoding]::UTF8)
  Write-Host "  [OK] $dest" -ForegroundColor Green
}

# ── 1. Write source files ─────────────────────────────────────────
Write-Host "`n[1/4] Writing source files ..."

Fetch-File "api-copilotkit-route.ts"  "$ROOT\app\api\copilotkit\route.ts"
Fetch-File "api-provider-route.ts"    "$ROOT\app\api\provider\route.ts"
Fetch-File "VibeProviderConfig.tsx"   "$ROOT\app\components\VibeProviderConfig.tsx"
Fetch-File "useVibeActions.tsx"       "$ROOT\app\hooks\useVibeActions.tsx"
Fetch-File "page.tsx"                 "$ROOT\app\page.tsx"

# ── 2. Install CopilotKit packages ───────────────────────────────
Write-Host "`n[2/4] Installing @copilotkit/react-core @copilotkit/react-ui ..."
Push-Location $ROOT
npm install @copilotkit/react-core @copilotkit/react-ui --save 2>&1 | Where-Object { $_ -match "added|error" }
Pop-Location
Write-Host "  [OK] CopilotKit packages installed" -ForegroundColor Green

# ── 3. Fix dev:mcp (Windows) ─────────────────────────────────────
Write-Host "`n[3/4] Fixing dev:mcp for Windows ..."
$pkgPath = "$ROOT\package.json"
$pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
$pkg.scripts."dev:mcp" = "npm --prefix threejs-server run start:http"
$pkg | ConvertTo-Json -Depth 10 | Set-Content $pkgPath -Encoding UTF8
Write-Host "  [OK] dev:mcp → npm --prefix threejs-server run start:http" -ForegroundColor Green

# Fix threejs-server single quotes
$tsPkg = "$ROOT\threejs-server\package.json"
$tp = Get-Content $tsPkg -Raw | ConvertFrom-Json
$tp.scripts.dev = 'cross-env NODE_ENV=development concurrently "npm run watch" "npm run serve:http"'
$tp.scripts."start:http" = "npm run build && npm run serve:http"
$tp | ConvertTo-Json -Depth 10 | Set-Content $tsPkg -Encoding UTF8
Write-Host "  [OK] threejs-server scripts fixed" -ForegroundColor Green

# ── 4. Write .env.local (if missing) ─────────────────────────────
Write-Host "`n[4/4] Checking .env.local ..."
$envPath = "$ROOT\.env.local"
if (!(Test-Path $envPath)) {
  @'
AI_PROVIDER_URL=http://localhost:4000/v1
AI_PROVIDER_KEY=r3-local
DEFAULT_MODEL=r3/fast
NEXT_PUBLIC_AI_PROVIDER_URL=http://localhost:4000/v1
THREEJS_MCP_URL=http://localhost:3108/mcp
'@ | Set-Content $envPath -Encoding UTF8
  Write-Host "  [OK] .env.local created" -ForegroundColor Green
} else {
  Write-Host "  [OK] .env.local already exists" -ForegroundColor Yellow
}

# ── Done ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Vibe Agent ready!" -ForegroundColor Green
Write-Host ""
Write-Host "  cd C:\Users\mail\R3-DASHBOARD\r-vib3"
Write-Host "  npm run dev:ui"
Write-Host ""
Write-Host "  → http://localhost:3000"
Write-Host "  → Click ⚡ to switch providers live"
Write-Host "  → Works with: LiteLLM, Ollama, Groq, OpenAI, Anthropic ..."
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
