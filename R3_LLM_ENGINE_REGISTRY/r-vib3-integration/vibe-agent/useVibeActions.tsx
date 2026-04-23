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
