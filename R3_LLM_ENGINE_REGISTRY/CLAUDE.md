# R³|VIB.E — CLAUDE.md

# Self-Improving Engineering System

# Every mistake → new rule. Every session → smarter.

# Pattern: https://github.com/win4r/ClawTeam-OpenClaw

#

# ══════════════════════════════════════════════════════════════

# WENN DU EINEN FEHLER MACHST: Füge unten eine neue Regel ein.

# Format: ## RULE-<N>: <Titel> (added <YYYY-MM-DD>)

# ══════════════════════════════════════════════════════════════

## PLATFORM IDENTITY

- **System**: R³|VIB.E Central Dashboard
- **Root**: `C:\Users\mail\R3-DASHBOARD` (Windows) / `/workspaces/session-state` (Codespace)
- **Primary engines**: :8420 (primary), :8421 (shadow), :8422 (matrix-control)
- **AI Gateway**: LiteLLM `:4000` — Key `r3-local` — IMMER als erstes nutzen
- **Automation**: n8n `:5678`
- **Local LLMs**: Ollama `:11434` (RAZER, 18 Modelle)

## ARCHITECTURE RULES

- Engines laufen auf Windows — WSL2 kann sie nicht mit `localhost` erreichen (außer `networkingMode=mirrored` in `.wslconfig`)
- `r-vib3` Next.js läuft auf Port `:3333` — niemals `:8420` (conflicts with ChatLegs)
- `.env.local` darf NIEMALS `PORT=8420`, `PORT=8421` oder `PORT=8422` enthalten
- PostgreSQL = Durable Truth Layer — alle Provider/Connector/Mountpoint-Daten landen dort

## CODING AGENT RULES

- PowerShell: `.bat`-Dateien immer mit `.\` aufrufen: `.\r3-code.bat`
- `ANTHROPIC_API_KEY=r3-local` ist KEIN echter Anthropic Key — bei Claude Code Prompt immer **No** wählen
- Für Free-Coding via LiteLLM: `$env:ANTHROPIC_BASE_URL = "http://localhost:4000/v1"`
- aider nutzen statt direkt Claude Code wenn API-Key fehlt

## AGENT ORCHESTRATION (ClawTeam Pattern)

Dieses Projekt nutzt das ClawTeam-Pattern für Parallel-Agents:

```
Leader Agent
├── worker-research    → Recherche / Deep Dive
├── worker-code        → Implementation
├── worker-test        → Testing / Validation
└── worker-review      → Code Review / Audit
```

Befehle:

```bash
# Team starten
clawteam team spawn-team r3-team -d "R3-DASHBOARD task" -n leader

# Worker spawnen
clawteam spawn claude --team r3-team --agent-name coder --task "Implement X"
clawteam spawn claude --team r3-team --agent-name tester --task "Test X"

# Board überwachen
clawteam board serve --port 8080
```

## SELF-IMPROVEMENT LOOP

> Wenn du einen Fehler machst → füge eine Regel hier ein.
> "Update your CLAUDE.md so you don't make that mistake again."

**Nach JEDEM Fix ausführen:**

```
Update CLAUDE.md: Add rule for [was du gelernt hast]
```

---

## LEARNED RULES (Automatisch ergänzt)

### RULE-001: PowerShell .bat Execution (added 2026-04-23)

`.bat` Dateien in PowerShell benötigen `.\` Prefix:

```powershell
# FALSCH:
r3-code.bat local

# RICHTIG:
.\r3-code.bat local
# ODER:
cmd /c r3-code.bat local
```

### RULE-002: r3-local ist kein Anthropic Key (added 2026-04-23)

`ANTHROPIC_API_KEY=r3-local` ist ein LiteLLM-Routing-Key.
Claude Code erkennt ihn als API-Key und fragt nach.
**Immer "No (2)" wählen** und stattdessen:

```powershell
$env:ANTHROPIC_BASE_URL = "http://localhost:4000/v1"
$env:ANTHROPIC_API_KEY  = "sk-placeholder"   # beliebig, nicht "r3-local"
```

### RULE-003: WSL2 ↔ Windows Port Access (added 2026-04-23)

WSL2 hat ein eigenes Netzwerk.
`curl localhost:8420` aus WSL scheitert wenn `.wslconfig` kein `networkingMode=mirrored` hat.
Fix: `Setup-R3-CodingTeam.ps1` ausführen → `.wslconfig` patchen → `wsl --shutdown`.
Fallback: Windows IP verwenden: `curl http://172.x.x.x:8420/api/health`

### RULE-004: LiteLLM immer prüfen vor AI-Calls (added 2026-04-23)

Vor jedem aider/coding-session:

```powershell
Invoke-RestMethod http://localhost:4000/health
```

Wenn nicht erreichbar: `Start-R3-LiteLLM.ps1` ausführen.

### RULE-006: aider nicht im PATH — immer python -m aider nutzen (added 2026-04-23)

`aider` ist nach `pip install aider-chat` NICHT automatisch im PATH.
Python Scripts-Ordner (`AppData\Local\Programs\Python\Python313\Scripts\`) ist oft nicht in `$env:PATH`.

```powershell
# FALSCH — schlägt fehl:
aider --model groq/llama-3.3-70b-versatile

# RICHTIG — funktioniert immer:
python -m aider --model groq/llama-3.3-70b-versatile

# Oder PATH dauerhaft hinzufügen (einmalig):
$scripts = python -c "import sysconfig; print(sysconfig.get_path('scripts'))"
[Environment]::SetEnvironmentVariable("Path", "$env:Path;$scripts", "User")
# → Dann neues Terminal öffnen → aider funktioniert direkt
```

### RULE-007: ClawTeam läuft NICHT auf nativem Windows Python (added 2026-04-23)

`clawteam` importiert `fcntl` — ein Linux-only Modul. Crash auf Windows:
`ModuleNotFoundError: No module named 'fcntl'`

**Fix: ClawTeam in WSL ausführen** (nach `wsl --shutdown` + Neustart mit mirrored networking):

```bash
# In WSL:
pip install clawteam
clawteam team spawn-team r3-team -d "R3-DASHBOARD task" -n leader
```

Alternativ: aider direkt für single-agent Coding nutzen (kein ClawTeam nötig).

### RULE-005: ClawTeam Agents brauchen echten CLI-Agent (added 2026-04-23)

ClawTeam spawnt Sub-Agents via `claude`, `codex`, oder `openclaw` CLI.
Für kostenlosen Betrieb: aider als `subprocess`-Agent nutzen:

```bash
clawteam spawn subprocess aider --team r3-team --agent-name worker1 \
  --task "Implement auth module"
```

---

## PROVIDER ROUTING QUICK REFERENCE

```
Task           Route              Backend              Kosten
──────────────────────────────────────────────────────────────
Code           r3/code            deepseek-coder:6.7b  FREE (Ollama)
Code Alt       r3/code-alt        qwen2.5-coder        FREE (Ollama)
Fast Debug     r3/fast            gemma2:2b            FREE (Ollama)
Reasoning      r3/reasoning       deepseek-r1          FREE (Ollama)
Chat           r3/chat            mistral:7b           FREE (Ollama)
Groq Fallback  groq/llama-3.3-70b Groq API             FREE (14400/day)
Embeddings     r3/embed           nomic-embed-text     FREE (APPSEN)
```

All via: `http://localhost:4000/v1` — Key: `r3-local`

## FILE STRUCTURE (Key Paths)

```
C:\Users\mail\R3-DASHBOARD\
├── CLAUDE.md                          ← DIESE DATEI — self-improving rules
├── r3-code.bat                        ← Quick launch: .\r3-code.bat [local|fast|heavy]
├── R3_LLM_ENGINE_REGISTRY\
│   ├── install\Setup-R3-CodingTeam.ps1  ← Full setup (WSL2, aider, routing)
│   ├── install\Start-R3-LiteLLM.ps1     ← Gateway starten
│   ├── install\Install-R3-All.ps1       ← Ganzen Stack starten
│   └── claude-free-setup.ps1            ← Claude Code → Free backend
├── SOURCE\chat-legs\                    ← :8420/:8421 source
└── r-vib3\                             ← Next.js :3333
```
