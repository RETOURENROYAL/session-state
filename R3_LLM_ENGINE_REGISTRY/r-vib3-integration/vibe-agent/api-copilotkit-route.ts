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
