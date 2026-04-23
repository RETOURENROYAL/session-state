#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Fixes r-vib3 Windows compatibility:
  1. threejs-server/package.json  — single quotes → double quotes in scripts
  2. scripts/run-mcp-server.bat   — rewrite to work on Windows
  3. package.json dev:mcp         — use .bat directly (skip .sh)

  Run:
    & ([scriptblock]::Create((iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/r-vib3-integration/fix-windows-dev.ps1?r=$(Get-Random)").Content))
#>

$ROOT    = "C:\Users\mail\R3-DASHBOARD\r-vib3"
$THREEJS = "$ROOT\threejs-server"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   r-vib3 Windows Fix                           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan

# ── Fix 1: threejs-server/package.json — single → double quotes ─
Write-Host "`n[1/3] Fixing threejs-server/package.json scripts ..."

$pkgPath = "$THREEJS\package.json"
$pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json

# Fix: concurrently 'cmd' → concurrently "cmd"  (Windows needs double quotes)
$pkg.scripts.dev        = "cross-env NODE_ENV=development concurrently `"npm run watch`" `"npm run serve:http`""
$pkg.scripts.watch      = "cross-env INPUT=mcp-app.html vite build --watch"
# start:http: build first, then serve (node direct — no bun dependency)
$pkg.scripts."start:http"  = "npm run build && npm run serve:http"
$pkg.scripts."start:stdio" = "npm run build && npm run serve:stdio"

$pkg | ConvertTo-Json -Depth 10 | Set-Content $pkgPath -Encoding UTF8
Write-Host "  [OK] scripts.dev fixed (double quotes)" -ForegroundColor Green

# ── Fix 2: scripts/run-mcp-server.bat — simple, no bun check ────
Write-Host "[2/3] Rewriting scripts/run-mcp-server.bat ..."

@'
@echo off
REM R3 VIB.E — Start threejs-server on Windows
cd /d "%~dp0..\threejs-server"
echo [mcp] Building + starting threejs-server on :3108...
call npm run start:http
'@ | Set-Content "$ROOT\scripts\run-mcp-server.bat" -Encoding ASCII
Write-Host "  [OK] run-mcp-server.bat rewritten (npm only)" -ForegroundColor Green

# ── Fix 3: r-vib3/package.json dev:mcp — npm --prefix (no bat) ──
Write-Host "[3/3] Fixing root package.json dev:mcp script ..."

$rootPkg = Get-Content "$ROOT\package.json" -Raw | ConvertFrom-Json

# Use npm --prefix to run in threejs-server subdirectory directly
# This avoids BAT/SH entirely and works on all platforms
$rootPkg.scripts."dev:mcp" = "npm --prefix threejs-server run start:http"

$rootPkg | ConvertTo-Json -Depth 10 | Set-Content "$ROOT\package.json" -Encoding UTF8
Write-Host "  [OK] dev:mcp → npm --prefix threejs-server run start:http" -ForegroundColor Green

# ── Done — start ─────────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Fix applied. Now run:" -ForegroundColor Green
Write-Host ""
Write-Host "    cd C:\Users\mail\R3-DASHBOARD\r-vib3"
Write-Host "    npm run dev         (ui :3000 + mcp :3108 together)"
Write-Host "    npm run dev:ui      (Next.js :3000 only)"
Write-Host ""
Write-Host "  Or start mcp server separately:"
Write-Host "    cd threejs-server && npm run start:http"
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
