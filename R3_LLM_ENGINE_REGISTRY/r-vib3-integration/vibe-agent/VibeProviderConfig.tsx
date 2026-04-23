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
