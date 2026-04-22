# R³ VIB.E Platform — Copilot System Instructions

You are operating inside the **R³ VIB.E Central Dashboard** — a fully autonomous,
multi-engine AI orchestration platform. This file defines the platform context for
every Copilot Chat session, CLI interaction, and agentic workload in this workspace.

---

## Platform Identity

| Property | Value |
|----------|-------|
| Platform | R³ VIB.E Central Dashboard |
| Root (Windows) | `C:\Users\mail\R3-DASHBOARD` |
| Root (Codespace) | `/workspaces/session-state` |
| Engine Registry | `R3_LLM_ENGINE_REGISTRY/` |
| Node Map | `r3-node-map.json` |
| Cluster Config | `R3_LLM_ENGINE_REGISTRY/r3-engine-cluster.json` |

---

## Active Engine Ports

| Engine | Port | Role | Protocol |
|--------|------|------|----------|
| chatlegs-primary | 8420 | Primary AI chat proxy | HTTP / MCP SSE |
| chatlegs-shadow | 8421 | Shadow / fallback proxy | HTTP / MCP SSE |
| matrix-control | 8422 | Control plane (no /mcp) | HTTP |
| LiteLLM Gateway | 4000 | Zero-cost AI gateway (OpenAI-compat) | HTTP |
| n8n Automation | 5678 | GitHub API workflows + webhooks | HTTP |
| openai-bridge | 8512 | OpenAI connector | HTTP |
| perplexity-bridge | 8511 | Perplexity connector | HTTP |
| Ollama RAZER | 11434 | 18 local LLMs (localhost) | HTTP |
| Ollama APPSEN | 11434 | 2 models (192.168.1.226) | HTTP |

All local endpoints: `http://localhost:<port>/`

---

## Ollama Node Inventory (2026-04-22)

### RAZER — localhost:11434 — 18 Modelle

| Modell | Größe | Familie | Capability |
|--------|-------|---------|-----------|
| `deepseek-coder:6.7b` | 3.56 GB | llama | **code**, completion |
| `deepseek-r1:latest` | 4.87 GB | qwen3 8.2B | **reasoning**, analysis, code |
| `qwen2.5-coder:latest` | 4.36 GB | qwen2 7.6B | **code**, completion |
| `codellama:7b` | 3.56 GB | llama | code, completion |
| `qwen3:latest` | 4.87 GB | qwen3 8.2B | reasoning, chat, code |
| `qwen2.5:14b` | 8.37 GB | qwen2 14.8B | **reasoning**, long-context |
| `mixtral:latest` | 24.63 GB | llama 46.7B | **large-context**, complex |
| `nemotron-cascade-2:latest` | 22.61 GB | nemotron 31.6B | reasoning, large-context |
| `gemma4:latest` | 8.95 GB | gemma4 8B | chat, multimodal |
| `llama3:8b` | 4.34 GB | llama | chat, instruction |
| `mistral:latest` | 4.07 GB | llama 7.2B | **chat**, instruction |
| `qwen2.5:7b` | 4.36 GB | qwen2 | chat, general |
| `nemotron-mini:latest` | 2.51 GB | nemotron 4.2B | fast, instruction |
| `phi3:mini` | 2.03 GB | phi3 3.8B | **autocomplete**, fast |
| `gemma2:2b` | 1.52 GB | gemma2 | **fast**, autocomplete |
| `gemma:2b` | 1.56 GB | gemma | fast, chat |
| `qwen2.5:3b` | 1.80 GB | qwen2 | fast, chat |
| `gemma:7b` | 4.67 GB | gemma | chat, general |

### APPSEN — 192.168.1.226:11434 — 2 Modelle

| Modell | Größe | Familie | Capability |
|--------|-------|---------|-----------|
| `llama3.2:latest` | 1.88 GB | llama 3.2B | chat, fast |
| `nomic-embed-text:latest` | 262 MB | nomic-bert | **embedding**, RAG, semantic search |

> **nomic-embed-text ist das EINZIGE Embedding-Modell im Cluster** — für RAG/Vektorsuche immer APPSEN nutzen.

---

## Intelligentes Routing — Task → Modell

Alle Routen erreichbar via LiteLLM Gateway `http://localhost:4000/v1`, Key `r3-local`:

| Task-Typ | Route | Modell (Primary) | Fallback |
|----------|-------|-------------------|---------|
| Code / Debug | `r3/code` | `deepseek-coder:6.7b` (RAZER) | `r3/code-alt` → groq |
| Code (alt) | `r3/code-alt` | `qwen2.5-coder:latest` (RAZER) | `r3/code-fallback` |
| Reasoning | `r3/reasoning` | `deepseek-r1:latest` (RAZER) | `r3/reasoning-alt` → groq |
| Reasoning (alt) | `r3/reasoning-alt` | `qwen3:latest` (RAZER) | groq/llama-3.3-70b |
| Fast / Quick | `r3/fast` | `gemma2:2b` (RAZER) | `r3/fast-alt` → groq/8b |
| General Chat | `r3/chat` | `mistral:latest` (RAZER) | `r3/chat-heavy` |
| Heavy (14B) | `r3/chat-heavy` | `qwen2.5:14b` (RAZER) | groq |
| Large Context | `r3/large` | `mixtral:latest` 46.7B (RAZER) | `r3/large-alt` |
| Autocomplete | `r3/autocomplete` | `phi3:mini` (RAZER) | `r3/fast` |
| **Embeddings** | `r3/embed` | `nomic-embed-text` (APPSEN) | — |
| APPSEN fallback | `r3/appsen-chat` | `llama3.2:latest` (APPSEN) | — |

### Routing-Catches (Abhängigkeiten)

```
Code-Task         → r3/code → r3/code-alt → r3/code-fallback → groq/llama-3.3-70b
Reasoning-Task    → r3/reasoning → r3/reasoning-alt → groq/llama-3.3-70b
Fast/Autocomplete → r3/fast → r3/fast-alt → groq/llama-3.1-8b
Embedding/RAG     → r3/embed (APPSEN ONLY — kein Fallback auf anderen Ollama)
Large Context     → r3/large → r3/large-alt → openrouter/auto
Offline (kein Net)→ r3/reasoning → r3/chat → r3/fast (alles lokal RAZER)
```

### Registrierung in LiteLLM (einmalig ausführen)

```powershell
iwr https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Register-R3-Ollama.ps1 | iex
```

Oder lokal: `C:\Users\mail\R3-DASHBOARD\R3_LLM_ENGINE_REGISTRY\install\Register-R3-Ollama.ps1`

Registry JSON: `R3_LLM_ENGINE_REGISTRY/config/ollama-registry.json`

---

## Zero-Cost Engine Policy

**Always route through zero-cost engines first:**

1. `groq/llama-3.3-70b` via `http://localhost:4000/v1` (fastest)
2. `cerebras/llama-3.3-70b` via `http://localhost:4000/v1`
3. `openrouter/auto` via `http://localhost:4000/v1`
4. Ollama: `http://localhost:11434` (offline)
5. Paid APIs (GPT-4o, Claude) — only on explicit user request

Gateway key: `r3-local` — use as `apiKey` for all localhost:4000 calls.

---

## MCP Servers (VS Code / Copilot Chat)

```json
{
  "r3-chatlegs-primary": { "type": "sse", "url": "http://localhost:8420/mcp" },
  "r3-chatlegs-shadow":  { "type": "sse", "url": "http://localhost:8421/mcp" }
}
```

Managed via: `R3_LLM_ENGINE_REGISTRY/.vscode/settings.json` → `mcp.servers`

---

## GitHub Integration (Central Engine)

### Mountpoint (machine-readable, all 27 workflows)
```
https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/n8n-workflows/workflows-index.json
```

### n8n Workflow Categories (all live on :5678)
| Category | Workflows |
|----------|-----------|
| Authentication | rate-limit, token-status |
| Workflow Runs | trigger, list, status, logs, artifacts, cancel |
| Secrets | list, get, create, update, delete |
| Self-Hosted Runners | list, register, delete, status |
| GitHub-Hosted Runners | list, usage |
| Runner Groups | list, create, update, delete |
| Codespaces | list, create, stop, delete, usage |
| Git Operations | commits, branches, tags, compare |
| Organizations | list, members, teams |
| Installations | list-app |

### Universal Workflow (single entry point for all categories)
```
https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/n8n-workflows/n8n-github-universal.json
```

### GitHub API Auth
- Token env: `$env:GITHUB_TOKEN` (Windows) / `$GITHUB_TOKEN` (bash)
- All n8n workflows use `{{ $env.GITHUB_TOKEN }}`
- n8n health: `http://localhost:5678/healthz`

---

## Key Source Paths

```
R3_LLM_ENGINE_REGISTRY/
├── .github/copilot-instructions.md  ← THIS FILE
├── .vscode/settings.json            ← MCP + Continue + Copilot config
├── r3-engine-cluster.json           ← Master cluster / single source of truth
├── config/
│   ├── acp-config.json              ← Agent Client Protocol config
│   ├── mcp-servers.json             ← MCP server definitions
│   └── github-api-endpoints.json    ← GitHub API endpoint reference
├── n8n-workflows/
│   ├── workflows-index.json         ← Central mountpoint (27 workflows)
│   ├── n8n-github-universal.json    ← Universal single-entry workflow
│   └── workflows/wf-*.json          ← Individual workflow files
├── engines/                         ← Engine profile configs
├── profiles/                        ← RAZER-FREE-ONLY, LOCAL-ONLY, R3-PRODUCTION
└── install/Install-R3-n8n.ps1       ← One-liner n8n installer
```

Windows source tree: `C:\Users\mail\R3-DASHBOARD\` (full map in r3-engine-cluster.json)

---

## Agent / Automation Interaction Rules

1. **GitHub operations** → use n8n workflows on :5678 OR direct GitHub API with `$GITHUB_TOKEN`
2. **LLM calls** → always `http://localhost:4000/v1` (LiteLLM gateway), key `r3-local`
3. **MCP tool calls** → route through r3-chatlegs-primary (:8420) first, shadow (:8421) as fallback
4. **Connectors** → registered in `MODULES/re-provider-registry/provider-account-registry.yaml`
5. **Agentic runs** → use `MODULES/agent-skills/skills/` SKILL.md files as capability definitions
6. **Never kill** a running Docker container on :5678 — active n8n workflows live there
7. **Codespace ↔ Windows sync** → `session-state` GitHub repo is the bridge

---

## Agentic Workload Entry Points

| Entry | Purpose |
|-------|---------|
| `MODULES/agent-skills/CLAUDE.md` | Claude Code agent instructions |
| `MODULES/re-gre-generator/` | Core output generator |
| `MODULES/re-agent-dispatcher/dispatcher.py` | Agent task dispatcher |
| `MODULES/re-prompt-router/prompt_router.py` | Prompt routing |
| `GH_MD/#AGENT.MD/` | All agent setup docs (65 files) |
| `n8n-workflows/` | Webhook-triggered automations |

---

## VS Code as Orchestrator

VS Code in this workspace IS the orchestration layer:
- **Copilot Chat** (this context) → agentic tasks via MCP + slash commands
- **Continue extension** → zero-cost LLM via localhost:4000
- **MCP servers** (:8420/:8421) → tool calls routed to R3 engine cluster
- **Terminal** → PowerShell scripts in `_automation/`, `install/`, `scripts/`
- **Tasks** → all automation runs start from VS Code terminal or CI

When asked to do something, always check if an existing workflow, script, or agent module handles it before writing new code.
