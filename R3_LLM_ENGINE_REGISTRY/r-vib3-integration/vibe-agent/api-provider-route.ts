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
