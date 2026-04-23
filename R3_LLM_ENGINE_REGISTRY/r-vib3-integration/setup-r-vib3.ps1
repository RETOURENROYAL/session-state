#!/usr/bin/env pwsh
<#
.SYNOPSIS
  R³ VIB.E — r-vib3 Setup & Integration
  Writes alle Dateien, installiert Deps, startet Stack.

  Ausführen:
    & ([scriptblock]::Create((iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/r-vib3-integration/setup-r-vib3.ps1?r=$(Get-Random)").Content))

  Oder lokal:
    & "C:\Users\mail\R3-DASHBOARD\R3_LLM_ENGINE_REGISTRY\r-vib3-integration\setup-r-vib3.ps1"
#>

$ErrorActionPreference = "Stop"
$ROOT     = "C:\Users\mail\R3-DASHBOARD\r-vib3"
$API_DIR  = "$ROOT\app\api\copilotkit"
$THREEJS  = "$ROOT\threejs-server"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   R³ VIB.E — r-vib3 Setup                     ║" -ForegroundColor Cyan
Write-Host "║   Next.js + CopilotKit + LiteLLM :4000         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Write corrected API route ──────────────────────────
Write-Host "[1/4] Writing app/api/copilotkit/route.ts ..." -ForegroundColor Yellow

if (-not (Test-Path $API_DIR)) { New-Item -ItemType Directory -Path $API_DIR -Force | Out-Null }

@'
import {
  CopilotRuntime,
  OpenAIAdapter,
  copilotRuntimeNextJSAppRouterEndpoint,
} from "@copilotkit/runtime";
import { BuiltInAgent } from "@copilotkit/runtime/v2";
import { NextRequest } from "next/server";
import { MCPAppsMiddleware } from "@ag-ui/mcp-apps-middleware";
import OpenAI from "openai";

// R3 LiteLLM Gateway :4000
const LITELLM_BASE = process.env.OPENAI_BASE_URL ?? "http://localhost:4000/v1";
const LITELLM_KEY  = process.env.OPENAI_API_KEY   ?? "r3-local";
const R3_MODEL     = process.env.DEFAULT_MODEL     ?? "r3/fast";

const middlewares = [
  new MCPAppsMiddleware({
    mcpServers: [
      {
        type: "http",
        url: process.env.THREEJS_MCP_URL ?? "http://localhost:3108/mcp",
        serverId: "threejs",
      },
    ],
  }),
];

const agent = new BuiltInAgent({
  model: R3_MODEL,
  prompt:
    "You are the R3 VIB.E assistant. You have access to 3D visualization tools " +
    "and all R3 platform capabilities. Be concise and helpful.",
});

for (const middleware of middlewares) {
  agent.use(middleware);
}

const serviceAdapter = new OpenAIAdapter({
  openai: new OpenAI({ baseURL: LITELLM_BASE, apiKey: LITELLM_KEY }),
  model: R3_MODEL,
});

const runtime = new CopilotRuntime({ agents: { default: agent } });

export const POST = async (req: NextRequest) => {
  const { handleRequest } = copilotRuntimeNextJSAppRouterEndpoint({
    runtime,
    serviceAdapter,
    endpoint: "/api/copilotkit",
  });
  return handleRequest(req);
};
'@ | Set-Content "$API_DIR\route.ts" -Encoding UTF8

Write-Host "  [OK] $API_DIR\route.ts" -ForegroundColor Green

# ── Step 2: Write .env.local ────────────────────────────────────
Write-Host "[2/4] Writing .env.local ..." -ForegroundColor Yellow

@'
# R3 LiteLLM Gateway
OPENAI_BASE_URL=http://localhost:4000/v1
OPENAI_API_KEY=r3-local
DEFAULT_MODEL=r3/fast
THREEJS_MCP_URL=http://localhost:3108/mcp
'@ | Set-Content "$ROOT\.env.local" -Encoding UTF8

Write-Host "  [OK] $ROOT\.env.local" -ForegroundColor Green

# ── Step 3: Install r-vib3 root deps ───────────────────────────
Write-Host "[3/4] Installing root deps (openai, @copilotkit/runtime) ..." -ForegroundColor Yellow
Push-Location $ROOT
try {
  # Check if openai package installed
  $pkgJson = Get-Content "$ROOT\package.json" | ConvertFrom-Json
  $deps = ($pkgJson.dependencies.PSObject.Properties.Name) + ($pkgJson.devDependencies.PSObject.Properties.Name)
  $toInstall = @()
  if ("openai" -notin $deps) { $toInstall += "openai" }
  if ("@copilotkit/runtime" -notin $deps) { $toInstall += "@copilotkit/runtime" }
  if ($toInstall.Count -gt 0) {
    Write-Host "  Installing: $($toInstall -join ', ')"
    npm install @($toInstall)
  } else {
    Write-Host "  [SKIP] Deps already in package.json"
  }
}
finally { Pop-Location }

# ── Step 4: Start threejs-server ────────────────────────────────
Write-Host "[4/4] Starting threejs-server on :3108 ..." -ForegroundColor Yellow

# Check if already running
$port3108 = netstat -ano 2>$null | Select-String ":3108 "
if ($port3108) {
  Write-Host "  [SKIP] :3108 already in use" -ForegroundColor DarkYellow
} else {
  Push-Location $THREEJS
  try {
    # Install threejs-server deps if needed
    if (-not (Test-Path "$THREEJS\node_modules")) {
      Write-Host "  Installing threejs-server deps..."
      npm install
    }
    # Start in background (bun or npx)
    $bunPath = (Get-Command bun -ErrorAction SilentlyContinue)?.Source
    if ($bunPath) {
      Start-Process -FilePath "bun" -ArgumentList "--watch server.ts" -WorkingDirectory $THREEJS -WindowStyle Minimized
    } else {
      Start-Process -FilePath "npx" -ArgumentList "tsx server.ts" -WorkingDirectory $THREEJS -WindowStyle Minimized
    }
    Start-Sleep 3
    Write-Host "  [OK] threejs-server started (bun/tsx)" -ForegroundColor Green
  }
  finally { Pop-Location }
}

# ── Status ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  R³ r-vib3 Setup Done" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "  1. cd C:\Users\mail\R3-DASHBOARD\r-vib3"
Write-Host "  2. npm run dev          (Next.js on :3000)"
Write-Host ""
Write-Host "  Routes:"
Write-Host "  → http://localhost:3000            Next.js App"
Write-Host "  → http://localhost:3000/api/copilotkit  CopilotKit"
Write-Host "  → http://localhost:3108/mcp        Three.js MCP"
Write-Host "  → http://localhost:4000/v1         LiteLLM (r3/fast)"
Write-Host ""
Write-Host "  VS Code mcp.json — run to update:"
Write-Host '  @''{"servers":{"r3-chatlegs-primary":{"type":"sse","url":"http://localhost:8420/mcp"},"r3-chatlegs-shadow":{"type":"sse","url":"http://localhost:8421/mcp"},"github":{"command":"docker","args":["run","-i","--rm","-e","GITHUB_PERSONAL_ACCESS_TOKEN","ghcr.io/github/github-mcp-server"],"env":{"GITHUB_PERSONAL_ACCESS_TOKEN":"${input:github_token}"}}}}''@ | Set-Content "$env:APPDATA\Code\User\mcp.json" -Encoding UTF8'
