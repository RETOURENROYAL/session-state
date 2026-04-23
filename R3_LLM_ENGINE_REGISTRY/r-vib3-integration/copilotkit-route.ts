import { MCPAppsMiddleware } from "@ag-ui/mcp-apps-middleware";
import {
    CopilotRuntime,
    OpenAIAdapter,
    copilotRuntimeNextJSAppRouterEndpoint,
} from "@copilotkit/runtime";
import { BuiltInAgent } from "@copilotkit/runtime/v2";
import { NextRequest } from "next/server";
import OpenAI from "openai";

// ── R³ VIB.E — LiteLLM Gateway ────────────────────────────────
// Routes: r3/fast, r3/code, r3/reasoning, r3/chat, r3/large, ...
// Gateway: http://localhost:4000/v1  key: r3-local
const LITELLM_BASE = process.env.OPENAI_BASE_URL ?? "http://localhost:4000/v1";
const LITELLM_KEY = process.env.OPENAI_API_KEY ?? "r3-local";
const R3_MODEL = process.env.DEFAULT_MODEL ?? "r3/fast";

// 1. MCP Apps Middleware (threejs-server on :3108)
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

// 2. Agent — model points to LiteLLM r3/* route
const agent = new BuiltInAgent({
  model: R3_MODEL,
  prompt:
    "You are the R³ VIB.E assistant. You have access to 3D visualization tools " +
    "and all R3 platform capabilities. Be concise and helpful.",
});

for (const middleware of middlewares) {
  agent.use(middleware);
}

// 3. OpenAI-compatible adapter → LiteLLM :4000
const serviceAdapter = new OpenAIAdapter({
  openai: new OpenAI({
    baseURL: LITELLM_BASE,
    apiKey: LITELLM_KEY,
  }),
  model: R3_MODEL,
});

// 4. Runtime
const runtime = new CopilotRuntime({
  agents: {
    default: agent,
  },
});

// 5. Route
export const POST = async (req: NextRequest) => {
  const { handleRequest } = copilotRuntimeNextJSAppRouterEndpoint({
    runtime,
    serviceAdapter,
    endpoint: "/api/copilotkit",
  });
  return handleRequest(req);
};
