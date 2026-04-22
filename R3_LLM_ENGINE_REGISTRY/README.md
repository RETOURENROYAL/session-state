# R3_LLM_ENGINE_REGISTRY

> GitHub API n8n Integration Stack + R3-DASHBOARD Engine Registry

---

## 🚀 Quick-Install (one-liner)

**Windows (PowerShell):**
```powershell
iwr 'https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/Install-R3-n8n.ps1' -UseB | iex
```

**Linux / Mac / Codespace:**
```bash
curl -fsSL https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/install/install-r3-n8n.sh | bash
```

---

## 📁 File Map

| File | Purpose |
|---|---|
| `config/github-api-endpoints.json` | Complete GitHub REST API reference (130+ endpoints) |
| `config/github-api-n8n-node.json` | n8n node definition (all 12 API areas) |
| `config/acp-config.json` | ACP/MCP endpoint config for R3 servers |
| `n8n-workflows/n8n-github-universal.json` | **Master importable n8n workflow** |
| `n8n-workflows/workflows/wf-*.json` | 27 individual single-purpose workflows |
| `n8n-workflows/docker-compose.yml` | Docker stack for local n8n |
| `dashboard/index.html` | Self-hosted multi-panel dashboard |
| `install/Install-R3-n8n.ps1` | Windows PowerShell installer |
| `install/install-r3-n8n.sh` | Linux/Mac/Codespace installer |
| `scripts/Test-R3-ACP-MultiConnect.ps1` | Live connection test suite |
| `scripts/Start-R3-AllServers.ps1` | Start all R3 engines |

---

## 🔗 Import Workflows into n8n

### Universal Workflow (empfohlen)
```
http://localhost:5678
→ Workflows → Import from URL:
https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/R3_LLM_ENGINE_REGISTRY/n8n-workflows/n8n-github-universal.json
```

### Individual Workflows (27 Stück)

| Workflow | Resource | Operation |
|---|---|---|
| `wf-workflow-runs-list.json` | Workflow Runs | List for repo |
| `wf-workflow-runs-trigger.json` | Workflow Runs | Trigger dispatch |
| `wf-workflow-runs-cancel.json` | Workflow Runs | Cancel run |
| `wf-workflow-runs-rerun.json` | Workflow Runs | Re-run failed jobs |
| `wf-secrets-repo-list.json` | Secrets | List repo secrets |
| `wf-secrets-repo-pubkey.json` | Secrets | Get public key |
| `wf-secrets-org-list.json` | Secrets | List org secrets |
| `wf-runners-self-list-repo.json` | Self-hosted Runners | List for repo |
| `wf-runners-self-list-org.json` | Self-hosted Runners | List for org |
| `wf-runners-self-reg-token.json` | Self-hosted Runners | Registration token |
| `wf-runners-hosted-list.json` | Hosted Runners | List for org |
| `wf-runners-hosted-images.json` | Hosted Runners | Available images |
| `wf-runner-groups-list.json` | Runner Groups | List for org |
| `wf-runner-groups-create.json` | Runner Groups | Create group |
| `wf-codespaces-list.json` | Codespaces | List for user |
| `wf-codespaces-start.json` | Codespaces | Start codespace |
| `wf-codespaces-stop.json` | Codespaces | Stop codespace |
| `wf-codespaces-secrets-list.json` | Codespaces | List secrets |
| `wf-git-refs-list.json` | Git Database | List refs |
| `wf-git-blob-create.json` | Git Database | Create blob |
| `wf-git-commit-create.json` | Git Database | Create commit |
| `wf-orgs-members-list.json` | Organizations | List members |
| `wf-orgs-repos-list.json` | Organizations | List repos |
| `wf-orgs-audit-log.json` | Organizations | Audit log |
| `wf-auth-rate-limit.json` | Auth / Rate Limit | Get rate limit |
| `wf-auth-user.json` | Auth | Get current user |
| `wf-installations-list.json` | Installations | List for user |

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

| Engine | Port | Status |
|---|---|---|
| chatlegs-primary | :8420 | ✅ MCP SSE + OpenAI proxy |
| chatlegs-shadow | :8421 | ✅ MCP SSE + OpenAI proxy |
| matrix-control | :8422 | ⚠️ Control plane (no /mcp) |
| litellm-gateway | :4000 | ✅ /v1/models + /health |
| n8n | :5678 | ✅ nach `docker compose up` |
