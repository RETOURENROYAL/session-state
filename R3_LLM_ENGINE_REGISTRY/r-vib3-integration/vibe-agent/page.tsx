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
