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
| Ollama (RAZER) | 11434 | Local LLM (gemma2, llama3) | HTTP |

All local endpoints: `http://localhost:<port>/`

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
