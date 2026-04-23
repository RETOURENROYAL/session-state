# R3_LLM_ENGINE_REGISTRY

> R³ VIB.E Central Dashboard — Engine Registry, LiteLLM Gateway, MCP Servers, n8n GitHub Workflows

---

## ⚡ Quick-Start — Kompletter Stack (1 Befehl)

**Windows (PowerShell) — empfohlen:**

```powershell
& ([scriptblock]::Create((iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Install-R3-All.ps1?r=$(Get-Random)").Content))
```

**Linux / Mac / Codespace (Bash):**

```bash
curl -fsSL 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/install-r3-all.sh' | bash
```

Startet: **LiteLLM :4000** + **ChatLegs :8420/:8421** + **n8n :5678**

---

## 🗺️ Stack-Übersicht

| Dienst           | Port  | Rolle                                        | Start                |
| ---------------- | ----- | -------------------------------------------- | -------------------- |
| LiteLLM Gateway  | 4000  | OpenAI-kompatibler Proxy für 14 r3/\* Routen | `Install-R3-All.ps1` |
| ChatLegs Primary | 8420  | AI-Chat-Proxy + MCP SSE `/mcp`               | `Install-R3-All.ps1` |
| ChatLegs Shadow  | 8421  | Fallback-Proxy + MCP SSE `/mcp`              | `Install-R3-All.ps1` |
| n8n Automation   | 5678  | GitHub API Workflows (27 Stück)              | `Install-R3-All.ps1` |
| Ollama RAZER     | 11434 | 18 lokale LLMs (localhost)                   | manuell              |
| Ollama APPSEN    | 11434 | 2 Modelle (192.168.1.226)                    | manuell              |

---

## 🔀 LiteLLM Gateway — 14 r3/\* Routen

Alle Routen via `http://localhost:4000/v1`, Key `r3-local`:

| Route              | Modell              | Node   | Task             |
| ------------------ | ------------------- | ------ | ---------------- |
| `r3/code`          | deepseek-coder:6.7b | RAZER  | Code / Debug     |
| `r3/code-alt`      | qwen2.5-coder       | RAZER  | Code alt         |
| `r3/code-fallback` | groq/llama-3.3-70b  | Cloud  | Code fallback    |
| `r3/reasoning`     | deepseek-r1         | RAZER  | Reasoning        |
| `r3/reasoning-alt` | qwen3:latest        | RAZER  | Reasoning alt    |
| `r3/fast`          | gemma2:2b           | RAZER  | Schnell/Quick    |
| `r3/fast-alt`      | groq/llama-3.1-8b   | Cloud  | Fast fallback    |
| `r3/chat`          | mistral:latest      | RAZER  | General Chat     |
| `r3/chat-heavy`    | qwen2.5:14b         | RAZER  | 14B heavy        |
| `r3/large`         | mixtral 46.7B       | RAZER  | Large context    |
| `r3/large-alt`     | openrouter/auto     | Cloud  | Large fallback   |
| `r3/autocomplete`  | phi3:mini           | RAZER  | Tab-Autocomplete |
| `r3/embed`         | nomic-embed-text    | APPSEN | Embeddings / RAG |
| `r3/appsen-chat`   | llama3.2:latest     | APPSEN | APPSEN fallback  |

**Test:**

```powershell
# Chat-Test:
$b = @{ model="r3/fast"; messages=@(@{role="user";content="OK?"}); max_tokens=5 } | ConvertTo-Json
Invoke-RestMethod 'http://localhost:4000/v1/chat/completions' -Method POST `
  -Headers @{Authorization='Bearer r3-local';'Content-Type'='application/json'} -Body $b `
  | % { $_.choices[0].message.content }

# Embed-Test:
$b = @{ model="r3/embed"; input="test" } | ConvertTo-Json
Invoke-RestMethod 'http://localhost:4000/v1/embeddings' -Method POST `
  -Headers @{Authorization='Bearer r3-local';'Content-Type'='application/json'} -Body $b `
  | % { "Dims: $($_.data[0].embedding.Count)" }
```

---

## 🔌 MCP Server (VS Code)

Datei: `C:\Users\mail\AppData\Roaming\Code\User\mcp.json`

```json
{
  "servers": {
    "r3-chatlegs-primary": {
      "type": "sse",
      "url": "http://localhost:8420/mcp"
    },
    "r3-chatlegs-shadow": { "type": "sse", "url": "http://localhost:8421/mcp" }
  }
}
```

> `:8422` hat keinen `/mcp`-Endpoint — nicht eintragen.

**Workspace settings:** `.vscode/settings.json` — Continue.dev mit allen 14 r3/\* Routen.

---

## 🤖 n8n GitHub Workflows

**Dashboard:** `http://localhost:5678`

**Universal Workflow importieren:**

```
n8n → Workflows → Import from URL:
https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/n8n-workflows/n8n-github-universal.json
```

**27 Einzelworkflows** in `n8n-workflows/workflows/wf-*.json`

Alle Kategorien:

| Kategorie             | Workflows                             |
| --------------------- | ------------------------------------- |
| Workflow Runs         | list, trigger, cancel, rerun          |
| Secrets               | list (repo/org), pubkey               |
| Self-hosted Runners   | list (repo/org), reg-token            |
| GitHub-hosted Runners | list, images                          |
| Runner Groups         | list, create                          |
| Codespaces            | list, start, stop, secrets            |
| Git Database          | blob-create, commit-create, refs-list |
| Organizations         | members, repos, audit-log             |
| Installations         | list-app                              |
| Auth                  | rate-limit, user                      |

---

## 📂 Datei-Map

| Pfad                                      | Zweck                                                       |
| ----------------------------------------- | ----------------------------------------------------------- |
| `install/Install-R3-All.ps1`              | **Windows All-in-One Installer** (LiteLLM + ChatLegs + n8n) |
| `install/install-r3-all.sh`               | **Bash All-in-One** (LiteLLM + n8n, Codespace)              |
| `install/Start-R3-LiteLLM.ps1`            | LiteLLM start/stop/status/restart                           |
| `install/Register-R3-Ollama.ps1`          | Ollama RAZER+APPSEN in LiteLLM registrieren                 |
| `install/Install-R3-n8n.ps1`              | n8n standalone installer                                    |
| `config/litellm-config.yaml`              | LiteLLM Konfiguration (14 r3/\* Routen)                     |
| `config/mcp-servers.json`                 | MCP Server-Definitionen                                     |
| `config/acp-config.json`                  | ACP Multi-Connection Config                                 |
| `config/ollama-registry.json`             | Ollama Node Registry (RAZER + APPSEN)                       |
| `engines/local/litellm-gateway.json`      | LiteLLM Engine Profile                                      |
| `engines/local/ollama-razer.json`         | RAZER Node Profile                                          |
| `engines/local/ollama-appsen.json`        | APPSEN Node Profile                                         |
| `engines/free/groq.json`                  | Groq Cloud Profile                                          |
| `scripts/Start-R3-AllServers.ps1`         | ChatLegs :8420/:8421 + :8422 starten                        |
| `scripts/test-all-engines.ps1`            | Alle Engines testen (Windows)                               |
| `scripts/test-all-engines.sh`             | Alle Engines testen (Bash)                                  |
| `n8n-workflows/docker-compose.yml`        | n8n Docker Stack                                            |
| `n8n-workflows/n8n-github-universal.json` | Universal n8n Workflow                                      |
| `dashboard/index.html`                    | Self-hosted Multi-Panel Dashboard                           |
| `.vscode/settings.json`                   | VS Code: Continue.dev + MCP + Copilot                       |
| `.github/copilot-instructions.md`         | Copilot Chat Platform-Kontext                               |
| `r3-engine-cluster.json`                  | Master-Cluster (Single Source of Truth)                     |

---

## 🎛️ Einzelne Dienste

### LiteLLM nur starten/stoppen:

```powershell
# Start:
& ([scriptblock]::Create((iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Start-R3-LiteLLM.ps1?r=$(Get-Random)").Content))

# Status:
& ([scriptblock]::Create((iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Start-R3-LiteLLM.ps1?r=$(Get-Random)").Content)) -Action status

# Stop:
& ([scriptblock]::Create((iwr "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Start-R3-LiteLLM.ps1?r=$(Get-Random)").Content)) -Action stop
```

### ChatLegs :8420/:8421 starten:

```powershell
& "C:\Users\mail\R3-DASHBOARD\R3_LLM_ENGINE_REGISTRY\scripts\Start-R3-AllServers.ps1"
```

### n8n nur starten:

```powershell
iwr 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Install-R3-n8n.ps1' -UseB | iex
```

---

## 🔑 Umgebungsvariablen

| Variable             | Wert                       | Verwendung         |
| -------------------- | -------------------------- | ------------------ |
| `LITELLM_MASTER_KEY` | `r3-local`                 | LiteLLM Auth       |
| `OPENAI_API_KEY`     | `r3-local`                 | ChatLegs → LiteLLM |
| `OPENAI_BASE_URL`    | `http://localhost:4000/v1` | ChatLegs Backend   |
| `DEFAULT_MODEL`      | `r3/fast`                  | Default LLM Route  |
| `GITHUB_TOKEN`       | `ghp_...`                  | n8n GitHub API     |

`.env.template`: `config/.env.template`

---

## 📍 Wichtige Hinweise

- **`iex $s -Action param`** funktioniert **NICHT** in PowerShell — immer `& ([scriptblock]::Create($s)) -Action param`
- **`:8422/mcp`** existiert nicht — nur REST Control-Plane
- **Embeddings** (`r3/embed`) → ausschließlich APPSEN (`nomic-embed-text`) — kein Fallback
- **LiteLLM `/health` → 401** wenn `LITELLM_MASTER_KEY` gesetzt — das bedeutet **online**, kein Fehler

---

_Codespace root: `/workspaces/session-state` | Windows root: `C:\Users\mail\R3-DASHBOARD`_

---

## 📁 File Map

| File                                      | Purpose                                             |
| ----------------------------------------- | --------------------------------------------------- |
| `config/github-api-endpoints.json`        | Complete GitHub REST API reference (130+ endpoints) |
| `config/github-api-n8n-node.json`         | n8n node definition (all 12 API areas)              |
| `config/acp-config.json`                  | ACP/MCP endpoint config for R3 servers              |
| `n8n-workflows/n8n-github-universal.json` | **Master importable n8n workflow**                  |
| `n8n-workflows/workflows/wf-*.json`       | 27 individual single-purpose workflows              |
| `n8n-workflows/docker-compose.yml`        | Docker stack for local n8n                          |
| `dashboard/index.html`                    | Self-hosted multi-panel dashboard                   |
| `install/Install-R3-n8n.ps1`              | Windows PowerShell installer                        |
| `install/install-r3-n8n.sh`               | Linux/Mac/Codespace installer                       |
| `scripts/Test-R3-ACP-MultiConnect.ps1`    | Live connection test suite                          |
| `scripts/Start-R3-AllServers.ps1`         | Start all R3 engines                                |

---

## 🔗 Import Workflows into n8n

### Universal Workflow (empfohlen)

```
http://localhost:5678
→ Workflows → Import from URL:
https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/n8n-workflows/n8n-github-universal.json
```

### Individual Workflows (27 Stück)

| Workflow                          | Resource            | Operation          |
| --------------------------------- | ------------------- | ------------------ |
| `wf-workflow-runs-list.json`      | Workflow Runs       | List for repo      |
| `wf-workflow-runs-trigger.json`   | Workflow Runs       | Trigger dispatch   |
| `wf-workflow-runs-cancel.json`    | Workflow Runs       | Cancel run         |
| `wf-workflow-runs-rerun.json`     | Workflow Runs       | Re-run failed jobs |
| `wf-secrets-repo-list.json`       | Secrets             | List repo secrets  |
| `wf-secrets-repo-pubkey.json`     | Secrets             | Get public key     |
| `wf-secrets-org-list.json`        | Secrets             | List org secrets   |
| `wf-runners-self-list-repo.json`  | Self-hosted Runners | List for repo      |
| `wf-runners-self-list-org.json`   | Self-hosted Runners | List for org       |
| `wf-runners-self-reg-token.json`  | Self-hosted Runners | Registration token |
| `wf-runners-hosted-list.json`     | Hosted Runners      | List for org       |
| `wf-runners-hosted-images.json`   | Hosted Runners      | Available images   |
| `wf-runner-groups-list.json`      | Runner Groups       | List for org       |
| `wf-runner-groups-create.json`    | Runner Groups       | Create group       |
| `wf-codespaces-list.json`         | Codespaces          | List for user      |
| `wf-codespaces-start.json`        | Codespaces          | Start codespace    |
| `wf-codespaces-stop.json`         | Codespaces          | Stop codespace     |
| `wf-codespaces-secrets-list.json` | Codespaces          | List secrets       |
| `wf-git-refs-list.json`           | Git Database        | List refs          |
| `wf-git-blob-create.json`         | Git Database        | Create blob        |
| `wf-git-commit-create.json`       | Git Database        | Create commit      |
| `wf-orgs-members-list.json`       | Organizations       | List members       |
| `wf-orgs-repos-list.json`         | Organizations       | List repos         |
| `wf-orgs-audit-log.json`          | Organizations       | Audit log          |
| `wf-auth-rate-limit.json`         | Auth / Rate Limit   | Get rate limit     |
| `wf-auth-user.json`               | Auth                | Get current user   |
| `wf-installations-list.json`      | Installations       | List for user      |

---

## 🔧 Local n8n Stack

```bash
cd R3_LLM_ENGINE_REGISTRY/n8n-workflows
export GITHUB_TOKEN=ghp_...
docker compose up -d
# → n8n läuft auf http://localhost:5678
```

---

## 🏥 Connection Test

```powershell
# Windows — testet alle R3 Engines
.\scripts\Test-R3-ACP-MultiConnect.ps1
```

Erwartet: 15/18 PASS (LiteLLM chat timeout + :8422 SKIP sind bekannte Limits)

---

## 🔑 Required GitHub PAT Scopes

Für vollen Zugriff (fine-grained PAT):

- `repo` — alle Repository-Operationen
- `workflow` — Workflow Runs triggern/canceln
- `admin:org` — Runner Groups, Org Secrets
- `codespace` — Codespaces starten/stoppen
- `read:user` — Installations, User info

---

## 📡 R3 Engine Ports

| Engine           | Port  | Status                      |
| ---------------- | ----- | --------------------------- |
| chatlegs-primary | :8420 | ✅ MCP SSE + OpenAI proxy   |
| chatlegs-shadow  | :8421 | ✅ MCP SSE + OpenAI proxy   |
| matrix-control   | :8422 | ⚠️ Control plane (no /mcp)  |
| litellm-gateway  | :4000 | ✅ /v1/models + /health     |
| n8n              | :5678 | ✅ nach `docker compose up` |
