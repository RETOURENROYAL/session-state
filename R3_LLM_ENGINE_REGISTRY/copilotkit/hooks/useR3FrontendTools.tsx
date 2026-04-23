/**
 * R³ VIB.E — useFrontendTool hooks
 *
 * Register these tools so the CopilotKit agent can call them
 * client-side (no backend round-trip needed).
 *
 * Usage: call useR3FrontendTools() once inside any component
 * that is a child of <R3CopilotProvider>.
 *
 * Install: npm install @copilotkit/react-core
 */

import { useCopilotAction } from "@copilotkit/react-core";

export function useR3FrontendTools() {
  // ── Tool 1: List available LiteLLM routes ─────────────────
  useCopilotAction({
    name: "listR3Routes",
    description:
      "List all available R3 LiteLLM model routes (r3/code, r3/reasoning, etc.)",
    parameters: [],
    handler: async () => {
      const res = await fetch("http://localhost:4000/v1/models", {
        headers: { Authorization: "Bearer r3-local" },
      });
      const data = await res.json();
      const routes = data.data?.map((m: { id: string }) => m.id) ?? [];
      return { routes, count: routes.length };
    },
  });

  // ── Tool 2: Query a specific r3/* route ───────────────────
  useCopilotAction({
    name: "queryR3Model",
    description: "Send a prompt to a specific R3 model route via LiteLLM :4000",
    parameters: [
      {
        name: "route",
        type: "string",
        description:
          "Route name, e.g. r3/code, r3/fast, r3/reasoning, r3/chat, r3/large",
      },
      {
        name: "prompt",
        type: "string",
        description: "The user prompt to send",
      },
      {
        name: "maxTokens",
        type: "number",
        description: "Max tokens (default 500)",
        required: false,
      },
    ],
    handler: async ({ route, prompt, maxTokens = 500 }) => {
      const res = await fetch("http://localhost:4000/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer r3-local",
        },
        body: JSON.stringify({
          model: route,
          messages: [{ role: "user", content: prompt }],
          max_tokens: maxTokens,
        }),
      });
      const data = await res.json();
      return {
        model: route,
        response: data.choices?.[0]?.message?.content ?? "No response",
        usage: data.usage,
      };
    },
  });

  // ── Tool 3: Get R3 stack status ───────────────────────────
  useCopilotAction({
    name: "getR3StackStatus",
    description: "Check live status of all R3 platform services",
    parameters: [],
    handler: async () => {
      const checks = await Promise.allSettled([
        fetch("http://localhost:4000/health").then((r) => ({
          service: "LiteLLM :4000",
          ok: r.status === 200 || r.status === 401,
        })),
        fetch("http://localhost:8420/").then((r) => ({
          service: "ChatLegs Primary :8420",
          ok: r.ok,
        })),
        fetch("http://localhost:8421/").then((r) => ({
          service: "ChatLegs Shadow :8421",
          ok: r.ok,
        })),
        fetch("http://localhost:5678/healthz").then((r) => ({
          service: "n8n :5678",
          ok: r.ok,
        })),
      ]);

      return checks.map((c) =>
        c.status === "fulfilled" ? c.value : { service: "unknown", ok: false }
      );
    },
  });

  // ── Tool 4: Semantic embed via r3/embed ───────────────────
  useCopilotAction({
    name: "embedText",
    description:
      "Generate a text embedding vector via r3/embed (nomic-embed-text on APPSEN)",
    parameters: [
      { name: "text", type: "string", description: "Text to embed" },
    ],
    handler: async ({ text }) => {
      const res = await fetch("http://localhost:4000/v1/embeddings", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: "Bearer r3-local",
        },
        body: JSON.stringify({ model: "r3/embed", input: text }),
      });
      const data = await res.json();
      const vec = data.data?.[0]?.embedding ?? [];
      return { dims: vec.length, preview: vec.slice(0, 6) };
    },
  });
}
