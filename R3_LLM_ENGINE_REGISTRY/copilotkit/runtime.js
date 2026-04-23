/**
 * R³ VIB.E — CopilotKit Runtime
 * Add to ChatLegs server.js (PORT 8420 primary, 8421 shadow)
 *
 * Install: npm install @copilotkit/runtime
 *
 * Usage in server.js:
 *   const { registerCopilotKit } = require('./copilotkit-runtime');
 *   registerCopilotKit(app);  // app = Express instance
 */

const {
  CopilotRuntime,
  OpenAIAdapter,
  copilotRuntimeNodeHttpEndpoint,
} = require("@copilotkit/runtime");

/**
 * Register CopilotKit endpoint on an Express app.
 * Connects to:
 *   - LiteLLM :4000 as LLM backend (14 r3/* routes)
 *   - R3 MCP SSE servers :8420/:8421
 *
 * @param {import('express').Application} app
 * @param {object} [opts]
 * @param {string} [opts.endpoint='/copilotkit'] - URL path
 * @param {string} [opts.model='r3/fast']        - Default LLM route
 */
function registerCopilotKit(app, opts = {}) {
  const endpoint = opts.endpoint ?? "/copilotkit";
  const model = opts.model ?? process.env.DEFAULT_MODEL ?? "r3/fast";

  const runtime = new CopilotRuntime({
    // Wire R3 MCP SSE servers as tool sources
    mcpServers: [
      { name: "r3-primary", endpoint: "http://localhost:8420/mcp" },
      { name: "r3-shadow", endpoint: "http://localhost:8421/mcp" },
    ],
  });

  const serviceAdapter = new OpenAIAdapter({
    openai: {
      baseURL: process.env.OPENAI_BASE_URL ?? "http://localhost:4000/v1",
      apiKey: process.env.OPENAI_API_KEY ?? "r3-local",
      defaultModel: model,
    },
  });

  const handler = copilotRuntimeNodeHttpEndpoint({
    endpoint,
    runtime,
    serviceAdapter,
  });

  app.use(endpoint, handler);
  console.log(`[CopilotKit] Runtime registered at ${endpoint} (model: ${model})`);
}

module.exports = { registerCopilotKit };
