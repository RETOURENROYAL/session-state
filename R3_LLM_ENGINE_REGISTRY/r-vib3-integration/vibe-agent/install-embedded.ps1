#!/usr/bin/env pwsh
<#
.SYNOPSIS
  R3 VIB.E Vibe Agent — self-contained installer.
  No GitHub fetch. All files embedded inline.

  One-liner:
  & ([scriptblock]::Create((iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/r-vib3-integration/vibe-agent/install-embedded.ps1?r=$(Get-Random)").Content))
#>

$ROOT = "C:\Users\mail\R3-DASHBOARD\r-vib3"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   R³ VIB.E — Vibe Agent Install (embedded)    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan

function Write-R3File($path, $content) {
  $dir = Split-Path $path
  if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
  Write-Host "  [OK] $(Split-Path $path -Leaf)" -ForegroundColor Green
}

Write-Host "`n[1/4] Writing source files ..."


Write-R3File "$ROOT\app\api\copilotkit\route.ts" @'
/**
 * R³ VIB.E — Dynamic CopilotKit Route
 * Works with ANY OpenAI-compatible provider URL.
 * Provider config is read from request headers (set by frontend ProviderConfig).
 * Falls back to .env.local values.
 *
 * Copy to: app/api/copilotkit/route.ts
 */

import {
    CopilotRuntime,
    OpenAIAdapter,
    copilotRuntimeNextJSAppRouterEndpoint,
} from "@copilotkit/runtime";
import { NextRequest } from "next/server";
import OpenAI from "openai";

export const POST = async (req: NextRequest) => {
  // ── Dynamic provider config from request headers ──────────────────
  // Frontend sends these via CopilotKit's runtimeUrl fetch headers
  const providerUrl =
    req.headers.get("x-provider-url") ??
    process.env.AI_PROVIDER_URL ??
    "http://localhost:4000/v1";

  const providerKey =
    req.headers.get("x-provider-key") ??
    process.env.AI_PROVIDER_KEY ??
    "r3-local";

  const model =
    req.headers.get("x-provider-model") ??
    process.env.DEFAULT_MODEL ??
    "r3/fast";

  const openai = new OpenAI({ baseURL: providerUrl, apiKey: providerKey });
  const adapter = new OpenAIAdapter({ openai, model });

  const runtime = new CopilotRuntime({
    actions: [
      {
        name: "listModels",
        description: "List all available models at the current provider URL",
        parameters: [],
        handler: async () => {
          try {
            const models = await openai.models.list();
            return {
              provider: providerUrl,
              models: models.data.map((m) => m.id),
            };
          } catch (e) {
            return { error: String(e), provider: providerUrl };
          }
        },
      },
      {
        name: "testConnection",
        description: "Test connection to provider with a quick ping",
        parameters: [
          {
            name: "testPrompt",
            type: "string",
            description: "Short test message",
            required: false,
          },
        ],
        handler: async ({ testPrompt }: { testPrompt?: string }) => {
          try {
            const result = await openai.chat.completions.create({
              model,
              messages: [
                { role: "user", content: testPrompt ?? "Reply with OK" },
              ],
              max_tokens: 10,
            });
            return {
              ok: true,
              provider: providerUrl,
              model,
              response: result.choices[0]?.message?.content,
            };
          } catch (e) {
            return {
              ok: false,
              error: String(e),
              provider: providerUrl,
              model,
            };
          }
        },
      },
      {
        name: "getActiveConfig",
        description: "Returns the currently active provider configuration",
        parameters: [],
        handler: async () => ({
          providerUrl,
          model,
          keySet: providerKey !== "none",
        }),
      },
    ],
  });

  const { handleRequest } = copilotRuntimeNextJSAppRouterEndpoint({
    runtime,
    serviceAdapter: adapter,
    endpoint: "/api/copilotkit",
  });

  return handleRequest(req);
};

'@


Write-R3File "$ROOT\app\api\provider\route.ts" @'
/**
 * R³ VIB.E — Provider API Route
 * GET  /api/provider → list known providers + current active
 * POST /api/provider → save new provider config
 * GET  /api/provider/models?url=...&key=... → fetch models from any URL
 *
 * Copy to: app/api/provider/route.ts
 */

import { NextRequest, NextResponse } from "next/server";
import OpenAI from "openai";

// ── Built-in presets (edit to match your stack) ───────────────────
const PRESETS = [
  {
    id: "r3-local",
    label: "R³ LiteLLM (local)",
    url: "http://localhost:4000/v1",
    key: "r3-local",
    model: "r3/fast",
  },
  {
    id: "r3-reasoning",
    label: "R³ Reasoning",
    url: "http://localhost:4000/v1",
    key: "r3-local",
    model: "r3/reasoning",
  },
  {
    id: "r3-code",
    label: "R³ Code",
    url: "http://localhost:4000/v1",
    key: "r3-local",
    model: "r3/code",
  },
  {
    id: "r3-large",
    label: "R³ Large Context",
    url: "http://localhost:4000/v1",
    key: "r3-local",
    model: "r3/large",
  },
  {
    id: "ollama",
    label: "Ollama (local)",
    url: "http://localhost:11434/v1",
    key: "ollama",
    model: "mistral:latest",
  },
  {
    id: "groq",
    label: "Groq (cloud, free)",
    url: "https://api.groq.com/openai/v1",
    key: "${GROQ_API_KEY}",
    model: "llama-3.3-70b-versatile",
  },
  {
    id: "openai",
    label: "OpenAI",
    url: "https://api.openai.com/v1",
    key: "${OPENAI_API_KEY}",
    model: "gpt-4o-mini",
  },
  {
    id: "anthropic",
    label: "Anthropic (via LiteLLM)",
    url: "http://localhost:4000/v1",
    key: "r3-local",
    model: "anthropic/claude-3-haiku-20240307",
  },
  { id: "custom", label: "Custom Provider", url: "", key: "", model: "" },
];

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);

  // GET /api/provider/models?url=...&key=...
  if (searchParams.get("action") === "models") {
    const url =
      searchParams.get("url") ??
      process.env.AI_PROVIDER_URL ??
      "http://localhost:4000/v1";
    const key =
      searchParams.get("key") ?? process.env.AI_PROVIDER_KEY ?? "r3-local";

    try {
      const client = new OpenAI({ baseURL: url, apiKey: key });
      const models = await client.models.list();
      return NextResponse.json({
        ok: true,
        provider: url,
        models: models.data.map((m) => m.id),
      });
    } catch (e) {
      return NextResponse.json(
        { ok: false, error: String(e), provider: url },
        { status: 502 },
      );
    }
  }

  // GET /api/provider → list presets + active config
  const active = {
    url: process.env.AI_PROVIDER_URL ?? "http://localhost:4000/v1",
    key: process.env.AI_PROVIDER_KEY ?? "r3-local",
    model: process.env.DEFAULT_MODEL ?? "r3/fast",
  };

  return NextResponse.json({ presets: PRESETS, active });
}

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { url, key, model } = body;

  if (!url)
    return NextResponse.json({ error: "url required" }, { status: 400 });

  // Test connection before confirming
  try {
    const client = new OpenAI({ baseURL: url, apiKey: key ?? "none" });
    await client.models.list();
  } catch (e) {
    return NextResponse.json({
      ok: false,
      warning: "Provider unreachable — config saved anyway",
      error: String(e),
    });
  }

  return NextResponse.json({ ok: true, saved: { url, model, keySet: !!key } });
}

'@


Write-R3File "$ROOT\app\components\VibeProviderConfig.tsx" @'
"use client";
/**
 * R³ VIB.E — VibeProviderConfig
 * Provider switcher component — paste any OpenAI-compatible URL, pick a model, go.
 *
 * Copy to: app/components/VibeProviderConfig.tsx
 */

import { useEffect, useState } from "react";

interface Preset {
  id: string;
  label: string;
  url: string;
  key: string;
  model: string;
}

interface ProviderConfig {
  url: string;
  key: string;
  model: string;
}

interface Props {
  onConfigChange: (config: ProviderConfig) => void;
  currentConfig: ProviderConfig;
}

export function VibeProviderConfig({ onConfigChange, currentConfig }: Props) {
  const [presets, setPresets] = useState<Preset[]>([]);
  const [models, setModels] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState<"idle" | "ok" | "error">("idle");
  const [statusMsg, setStatusMsg] = useState("");
  const [open, setOpen] = useState(false);

  const [url, setUrl] = useState(currentConfig.url);
  const [key, setKey] = useState(currentConfig.key);
  const [model, setModel] = useState(currentConfig.model);

  // Load presets on mount
  useEffect(() => {
    fetch("/api/provider")
      .then((r) => r.json())
      .then((d) => {
        setPresets(d.presets ?? []);
        setUrl(d.active?.url ?? currentConfig.url);
        setKey(d.active?.key ?? currentConfig.key);
        setModel(d.active?.model ?? currentConfig.model);
      })
      .catch(() => {});
  }, []);

  const fetchModels = async (providerUrl = url, providerKey = key) => {
    if (!providerUrl) return;
    setLoading(true);
    setStatus("idle");
    try {
      const r = await fetch(
        `/api/provider?action=models&url=${encodeURIComponent(providerUrl)}&key=${encodeURIComponent(providerKey)}`,
      );
      const d = await r.json();
      if (d.ok) {
        setModels(d.models ?? []);
        setStatus("ok");
        setStatusMsg(`${d.models.length} models found`);
      } else {
        setModels([]);
        setStatus("error");
        setStatusMsg(d.error ?? "Failed");
      }
    } catch (e) {
      setStatus("error");
      setStatusMsg(String(e));
    }
    setLoading(false);
  };

  const applyPreset = (preset: Preset) => {
    setUrl(preset.url);
    setKey(preset.key.startsWith("${") ? "" : preset.key);
    setModel(preset.model);
    setModels([]);
    setStatus("idle");
  };

  const apply = () => {
    const config = { url, key, model };
    onConfigChange(config);
    setStatus("ok");
    setStatusMsg("Provider applied ✓");
    setOpen(false);
  };

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="fixed bottom-4 right-4 z-50 flex items-center gap-2 rounded-full bg-black px-4 py-2 text-sm font-medium text-white shadow-lg hover:bg-gray-800"
      >
        <span className="h-2 w-2 rounded-full bg-green-400" />
        {model || "Configure Provider"}
      </button>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-lg rounded-2xl bg-white p-6 shadow-2xl dark:bg-gray-900">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-bold">⚡ Provider Config</h2>
          <button
            onClick={() => setOpen(false)}
            className="text-gray-400 hover:text-gray-600"
          >
            ✕
          </button>
        </div>

        {/* Presets */}
        <div className="mb-4 flex flex-wrap gap-2">
          {presets.map((p) => (
            <button
              key={p.id}
              onClick={() => applyPreset(p)}
              className="rounded-full border border-gray-200 px-3 py-1 text-xs hover:bg-gray-100 dark:border-gray-700 dark:hover:bg-gray-800"
            >
              {p.label}
            </button>
          ))}
        </div>

        {/* URL */}
        <label className="mb-1 block text-xs font-semibold text-gray-500">
          Provider URL
        </label>
        <div className="mb-3 flex gap-2">
          <input
            className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-800"
            placeholder="http://localhost:4000/v1"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
          />
          <button
            onClick={() => fetchModels()}
            disabled={loading || !url}
            className="rounded-lg bg-blue-600 px-3 py-2 text-xs font-medium text-white hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? "..." : "Ping"}
          </button>
        </div>

        {/* API Key */}
        <label className="mb-1 block text-xs font-semibold text-gray-500">
          API Key
        </label>
        <input
          className="mb-3 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-800"
          placeholder="r3-local / sk-... / none"
          type="password"
          value={key}
          onChange={(e) => setKey(e.target.value)}
        />

        {/* Model */}
        <label className="mb-1 block text-xs font-semibold text-gray-500">
          Model
        </label>
        {models.length > 0 ? (
          <select
            className="mb-4 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-800"
            value={model}
            onChange={(e) => setModel(e.target.value)}
          >
            {models.map((m) => (
              <option key={m} value={m}>
                {m}
              </option>
            ))}
          </select>
        ) : (
          <input
            className="mb-4 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm dark:border-gray-700 dark:bg-gray-800"
            placeholder="r3/fast / gpt-4o-mini / mistral:latest"
            value={model}
            onChange={(e) => setModel(e.target.value)}
          />
        )}

        {/* Status */}
        {status !== "idle" && (
          <p
            className={`mb-3 text-xs ${status === "ok" ? "text-green-600" : "text-red-500"}`}
          >
            {status === "ok" ? "✓" : "✗"} {statusMsg}
          </p>
        )}

        <div className="flex gap-2">
          <button
            onClick={apply}
            className="flex-1 rounded-lg bg-black py-2 text-sm font-medium text-white hover:bg-gray-800 dark:bg-white dark:text-black"
          >
            Apply Provider
          </button>
        </div>
      </div>
    </div>
  );
}

'@


Write-R3File "$ROOT\app\hooks\useVibeActions.tsx" @'
"use client";
/**
 * R³ VIB.E — Frontend CopilotKit Actions
 * These run in the browser and give the agent UI capabilities.
 *
 * Copy to: app/hooks/useVibeActions.tsx
 */

import { useCopilotAction, useCopilotReadable } from "@copilotkit/react-core";

export function useVibeActions() {
  // Make R3 stack context readable by the agent
  useCopilotReadable({
    description: "R³ VIB.E stack endpoints and available routes",
    value: {
      litellm: "http://localhost:4000/v1",
      chatlegsPrimary: "http://localhost:8420",
      chatlegsShadow: "http://localhost:8421",
      matrixControl: "http://localhost:8422",
      n8n: "http://localhost:5678",
      routes: [
        "r3/fast",
        "r3/reasoning",
        "r3/code",
        "r3/large",
        "r3/chat",
        "r3/embed",
      ],
    },
  });

  // Action: open/navigate to a URL
  useCopilotAction({
    name: "openUrl",
    description: "Open a URL in a new browser tab",
    parameters: [
      {
        name: "url",
        type: "string",
        description: "URL to open",
        required: true,
      },
      {
        name: "label",
        type: "string",
        description: "Human-readable label",
        required: false,
      },
    ],
    handler: async ({ url, label }: { url: string; label?: string }) => {
      window.open(url, "_blank");
      return `Opened ${label ?? url}`;
    },
    render: ({ args, status }) =>
      status === "executing"
        ? `Opening ${args.label ?? args.url}...`
        : `Opened ${args.label ?? args.url} ✓`,
  });

  // Action: copy text to clipboard
  useCopilotAction({
    name: "copyToClipboard",
    description: "Copy a value to the clipboard",
    parameters: [
      {
        name: "text",
        type: "string",
        description: "Text to copy",
        required: true,
      },
    ],
    handler: async ({ text }: { text: string }) => {
      await navigator.clipboard.writeText(text);
      return `Copied to clipboard`;
    },
  });

  // Action: show a notification/toast in the UI
  useCopilotAction({
    name: "showNotification",
    description: "Show a notification to the user",
    parameters: [
      {
        name: "message",
        type: "string",
        description: "Message to show",
        required: true,
      },
      {
        name: "type",
        type: "string",
        description: "info | success | error",
        required: false,
      },
    ],
    render: ({ args }) => (
      <div
        className={`rounded-lg p-3 text-sm font-medium ${
          args.type === "error"
            ? "bg-red-100 text-red-700"
            : args.type === "success"
              ? "bg-green-100 text-green-700"
              : "bg-blue-100 text-blue-700"
        }`}
      >
        {args.message}
      </div>
    ),
    handler: async ({ message }: { message: string }) => message,
  });

  // Action: fetch any URL and return content (useful for testing APIs)
  useCopilotAction({
    name: "fetchEndpoint",
    description: "Fetch a URL and return the response (GET request)",
    parameters: [
      {
        name: "url",
        type: "string",
        description: "URL to fetch",
        required: true,
      },
    ],
    handler: async ({ url }: { url: string }) => {
      try {
        const r = await fetch(url);
        const text = await r.text();
        return { ok: r.ok, status: r.status, body: text.slice(0, 500) };
      } catch (e) {
        return { ok: false, error: String(e) };
      }
    },
  });
}

'@


Write-R3File "$ROOT\app\page.tsx" @'
"use client";
/**
 * R³ VIB.E — Main Page
 * CopilotKit Agent with dynamic provider switching.
 * Provider config is passed as headers to the CopilotKit runtime.
 *
 * Copy to: app/page.tsx (replaces existing)
 */

import { CopilotKit } from "@copilotkit/react-core";
import { CopilotChat } from "@copilotkit/react-ui";
import "@copilotkit/react-ui/styles.css";
import { useState } from "react";
import { VibeProviderConfig } from "./components/VibeProviderConfig";
import { useVibeActions } from "./hooks/useVibeActions";

interface ProviderConfig {
  url: string;
  key: string;
  model: string;
}

const DEFAULT_CONFIG: ProviderConfig = {
  url: process.env.NEXT_PUBLIC_AI_PROVIDER_URL ?? "http://localhost:4000/v1",
  key: "r3-local",
  model: "r3/fast",
};

function VibeAgent({ config }: { config: ProviderConfig }) {
  useVibeActions();
  return (
    <CopilotChat
      className="h-full"
      instructions={`You are the R³ VIB.E AI Agent.
You are connected to: ${config.url} using model: ${config.model}.
You can help configure AI providers, list models, test connections, and assist with any task.
Use your backend tools: listModels, testConnection, getActiveConfig.`}
      labels={{
        title: `R³ VIB.E — ${config.model}`,
        initial: `Connected to ${config.url}\nModel: ${config.model}\n\nTry: "list available models" or "test the connection"`,
      }}
    />
  );
}

export default function Page() {
  const [config, setConfig] = useState<ProviderConfig>(DEFAULT_CONFIG);

  return (
    <main className="flex h-screen flex-col bg-gray-50 dark:bg-gray-950">
      <CopilotKit
        runtimeUrl="/api/copilotkit"
        headers={{
          "x-provider-url": config.url,
          "x-provider-key": config.key,
          "x-provider-model": config.model,
        }}
      >
        <div className="flex flex-1 overflow-hidden">
          <VibeAgent config={config} />
        </div>

        <VibeProviderConfig
          currentConfig={config}
          onConfigChange={(newConfig) => setConfig(newConfig)}
        />
      </CopilotKit>
    </main>
  );
}

'@


Write-Host "`n[2/4] Installing CopilotKit packages ..."
Push-Location $ROOT
npm install @copilotkit/react-core @copilotkit/react-ui --save --loglevel error 2>&1 | Select-String "added|error|warn" | ForEach-Object { Write-Host "  $_" }
Pop-Location
Write-Host "  [OK] CopilotKit packages installed" -ForegroundColor Green

Write-Host "`n[3/4] Fixing dev:mcp for Windows ..."
$p = Get-Content "$ROOT\package.json" -Raw | ConvertFrom-Json
$p.scripts."dev:mcp" = "npm --prefix threejs-server run start:http"
$p | ConvertTo-Json -Depth 10 | Set-Content "$ROOT\package.json" -Encoding UTF8
Write-Host "  [OK] dev:mcp → npm --prefix threejs-server run start:http" -ForegroundColor Green

$tp = Get-Content "$ROOT\threejs-server\package.json" -Raw | ConvertFrom-Json
$tp.scripts.dev = 'cross-env NODE_ENV=development concurrently "npm run watch" "npm run serve:http"'
$tp.scripts."start:http" = "npm run build && npm run serve:http"
$tp | ConvertTo-Json -Depth 10 | Set-Content "$ROOT\threejs-server\package.json" -Encoding UTF8
Write-Host "  [OK] threejs-server scripts fixed" -ForegroundColor Green

Write-Host "`n[4/4] Checking .env.local ..."
$envPath = "$ROOT\.env.local"
if (!(Test-Path $envPath) -or (Get-Content $envPath -Raw) -notmatch "AI_PROVIDER_URL") {
  @"
AI_PROVIDER_URL=http://localhost:4000/v1
AI_PROVIDER_KEY=r3-local
DEFAULT_MODEL=r3/fast
NEXT_PUBLIC_AI_PROVIDER_URL=http://localhost:4000/v1
THREEJS_MCP_URL=http://localhost:3108/mcp
"@ | Set-Content $envPath -Encoding UTF8
  Write-Host "  [OK] .env.local written" -ForegroundColor Green
} else {
  Write-Host "  [OK] .env.local already exists" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Done! Start with:" -ForegroundColor Green
Write-Host ""
Write-Host "    cd C:\Users\mail\R3-DASHBOARD\r-vib3"
Write-Host "    npm run dev:ui"
Write-Host ""
Write-Host "  → http://localhost:3000"
Write-Host "  → Click ⚡ (bottom right) to switch providers live"
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
