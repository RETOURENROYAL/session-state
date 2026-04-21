# typeui.sh

TypeScript CLI that generates, updates, and pulls design-system `SKILL.md` files for AI coding agents (Claude Code, Cursor, Codex, etc.). Source: [github.com/bergside/typeui](https://github.com/bergside/typeui)

## Build and Test

```sh
npm install
npm run build        # tsc → dist/
npm test             # vitest run
npm run typecheck    # tsc --noEmit
npm run release:check  # typecheck + test + pack dry-run
```

Local dev invocation (after build):

```sh
node dist/cli.js --help
node dist/cli.js generate   # interactive prompts → writes SKILL.md files
node dist/cli.js list       # browse registry, then pull
node dist/cli.js pull <slug>
```

## Architecture

```
src/
  cli.ts                    # Entry point (commander)
  types.ts                  # Core types: Provider, DesignSystemInput, SkillMetadata
  config.ts                 # Constants: managed-block markers, registry URLs
  domain/designSystemSchema.ts  # Zod schemas for all user inputs
  prompts/                  # inquirer interactive prompts (designSystem, registry)
  generation/               # runGeneration.ts, runPull.ts, existingDesignSystem.ts
  renderers/                # Per-provider SKILL.md renderers + shared body builder
  registry/registryClient.ts  # Fetches index.json + skill markdown from GitHub
  io/updateSkillFile.ts     # Reads/writes managed blocks in existing files
  skillMetadata.ts          # Skill frontmatter helpers
test/                       # Vitest tests mirroring src/ modules
skills/typeui-cli/SKILL.md  # Self-describing skill for CLI usage
```

Registry source: [bergside/awesome-design-skills](https://github.com/bergside/awesome-design-skills) — `skills/index.json` + per-slug `SKILL.md` files.

## Conventions

- **Zod for all input validation** — schemas live in `src/domain/designSystemSchema.ts`; never validate inline.
- **Adding a provider** — add entry to `PROVIDER_DETAILS` in `src/types.ts`, then add a renderer in `src/renderers/` and register it in `src/renderers/index.ts`. The `universal` provider (`.agents/skills/`) is always included.
- **Managed blocks** — generated content is wrapped in `<!-- TYPEUI_SH_MANAGED_START -->` / `<!-- TYPEUI_SH_MANAGED_END -->` markers (see `src/config.ts`). The `update` command rewrites only between these markers.
- **Output**: CommonJS (`"type": "commonjs"`), compiled to `dist/`. `dist/` is not committed.
- **Tests**: use `vitest` with `describe`/`it`/`expect`. Test files live in `test/` and import directly from `src/`.
- **Node 18+** required.

## Key Docs

- [DESIGN.md](https://github.com/bergside/typeui/blob/main/DESIGN.md) — canonical blueprint for skill file structure
- [REGISTRY.md](https://github.com/bergside/typeui/blob/main/REGISTRY.md) — registry protocol (index shape, pull URL resolution, error codes)
- [skills/typeui-cli/SKILL.md](https://github.com/bergside/typeui/blob/main/skills/typeui-cli/SKILL.md) — operator skill for using the CLI

---

## Main Stack Source — R3-DASHBOARD

**Path (Windows host):** `C:\Users\mail\R3-DASHBOARD`
**Deep-read index:** `r3-node-map.json` (workspace root) — maps all export files to logical domains with goal-based read-order.

This is the primary monorepo that typeui.sh serves. All SKILL.md generation targets components within this stack.

### Tech Stack

| Layer              | Technology                                                     |
| ------------------ | -------------------------------------------------------------- |
| Runtime            | Node.js 18+ (TypeScript via ts-node)                           |
| AI API Gateway     | Python Flask — `services/ki-api/app.py` + `routing_engine.py`  |
| Frontend Dashboard | `SOURCE/chat-legs/src/` (React/TSX) + `dashboard.html`         |
| AI Proxy Servers   | `SOURCE/chat-legs/` — ports 8420/8421 (chat), 8422 (control)   |
| Automation         | PowerShell (`.ps1` scripts throughout)                         |
| Containers         | Docker / Docker Compose (`docker/docker-compose.yml`)          |
| Database           | PostgreSQL + Hasura GraphQL                                    |
| Workflow Engine    | n8n (`n8n-workflows/`)                                         |
| Agent Modules      | Python virtualenvs in `MODULES/re-*/` + `MODULES/obliteratus/` |
| Agent Skills       | `MODULES/agent-skills/skills/` — 21 SKILL.md files             |

### Key Engine Ports

| Engine            | Port | Role                  |
| ----------------- | ---- | --------------------- |
| chatlegs-primary  | 8420 | Primary AI chat proxy |
| chatlegs-shadow   | 8421 | Shadow / fallback     |
| matrix-control    | 8422 | Control plane         |
| openai-bridge     | 8512 | OpenAI connector      |
| perplexity-bridge | 8511 | Perplexity connector  |

### Directory Map — Verified (2026-04-21, 3-level deep scan)

```
R3-DASHBOARD/
├── 01.] R³ I VIB.E - INSTRUCTIONS/   # AI setup & mountpoint matrices
│   ├── DASHBOARD_AI_SETUP.yaml
│   ├── mempalace.md
│   ├── Mountpoint-Matrix_network-basics.json
│   ├── Mountpoint-Matrix_PostgreSQL-SETTINGS.json
│   └── Mountpoint-Matrix_workplace-live*.json (×3)
│
├── _automation/                       # PowerShell guardrail & audit scripts
│   ├── Run-R3-Activate-And-Verify-Canonical-JS-Masters.ps1
│   ├── Run-R3-Canonical-JS-Guardrail-Daily.ps1
│   ├── Run-R3-Canonical-JS-PostDeployment-Integrity-Audit.ps1
│   ├── R3-Connector-Audit-PostRun.ps1
│   └── R3-OneShot-Rebuild.ps1
│
├── _backup/                           # Canonical-JS activation backups
│
├── _reference-js-master/              # Canonical Node.js server reference
│   ├── server.js
│   ├── R3-AUTO-MOUNT-HOOK.js
│   ├── r3-mount-api.js
│   ├── lib/
│   │   └── (avatar-engine, providers, registry, router, runtime-env, skills).js
│   └── src/lib/
│       └── (avatar-engine, config, db, ...).js
│
├── _upgrade/R3_upgrade_bundle/        # Upgrade automation
│   ├── Run-All-R3-Upgrades.ps1
│   └── Upgrade-*.ps1 (×10+)
│
├── archiv/                            # Legacy HTML, Python scripts, tar.gz snapshots
│
├── COLLECTED-OUTPUTS/                 # Generated agent output bundles
│   ├── collection-index.json
│   └── <module>/                      # One folder per agent module (each with SKILL.md)
│       └── (re-agent-dispatcher, re-gre-generator, re-output-collector,
│            re-preflight-agent, re-prompt-router, re-provider-registry,
│            re-social-connectors, agent-reach-hq/)
│
├── DASHBOARD-HUB-desktop/             # Desktop dashboard (Python entry point)
│   ├── main.py
│   ├── docker-compose.yml
│   ├── docker/
│   │   ├── Dockerfile.backend
│   │   └── Dockerfile.frontend
│   ├── nginx-web/html/index.html
│   ├── AZURE-VOICE-SETUP.md
│   ├── MODULE_MAPPING.md
│   └── N8N_WORKFLOW_ANALYSIS.md
│
├── docker/                            # Container stack
│   ├── docker-compose.yml
│   ├── init.sql
│   ├── nginx.conf
│   ├── nginx-vault.conf
│   ├── .env.example
│   └── R3-AUTOSETUP.ps1
│
├── GH_MD/                             # Agent knowledge base — all merged/tracked files
│   ├── [root audit files]
│   │   ├── _canonical-js-activation.log
│   │   ├── _canonical-js-deployment-plan.json
│   │   ├── _canonical-js-integrity-audit.json
│   │   ├── _connector-run.audit.jsonl
│   │   ├── _connector-run.events.json
│   │   ├── _mount-registry.json
│   │   ├── _js-file-master-registry.json
│   │   ├── _js-logical-master-registry.json
│   │   └── _env-finder-report.txt
│   ├── #AGENT.MD/  (65 files, ALL VERIFIED)  # Agent setup docs, SDK references
│   │   ├── _INDEX_AGENT.MD.md
│   │   ├── _INDEX_AGENT.MD.smartmerge.md
│   │   ├── AGENT.md, AGENTS.md, CLAUDE.md
│   │   ├── accessibility-checklist.md
│   │   ├── Agent Reach - Full HQ Setup Pack Prompt.md
│   │   ├── Agent Reach — Multi-Connector Zielkonfiguration.md
│   │   ├── agent-mission.merged.md
│   │   ├── agent-reach-config.merged.yaml, agent-reach-router.yaml
│   │   ├── avatar-engine.merged.js
│   │   ├── build.md
│   │   ├── claude-code.md
│   │   ├── CLAUDE.md, code-reviewer.md, code-simplify.md
│   │   ├── CONTRIBUTING.merged.md
│   │   ├── copilot-setup.md, opencode-setup.md
│   │   ├── "Code-Agent Ready" -Version im Dateiformatein Coding-Tool.md (×2)
│   │   ├── "Copy I Paste-Version mit Platzhaltern für Coding-Agenten.md"
│   │   ├── cursor-setup.md, windsurf-setup.md, vscode-gadget.md
│   │   ├── decoder-conceptor.merged.md
│   │   ├── deep-research-prompt.md
│   │   ├── examples.md, frameworks.md, refinement-criteria.md
│   │   ├── Mountpoint-Matrix_workplace-live-3.json
│   │   ├── obliteratus.md
│   │   ├── OpenMultiAgent core.md
│   │   ├── performance-checklist.md
│   │   ├── "Phase-by-Phase-Prompt-Serie für ein Code-Agent-Tool.md"
│   │   ├── preflight_agent.py
│   │   ├── R³ VOLT-AGENT_DESIGN.MD
│   │   ├── R³_AGENTENFÄHIGKEITEN.MD, R³_AGENTENFÄHIGKEITEN_BASIC-Prompt.md
│   │   ├── review.md
│   │   ├── test-engineer.md, test.md, testing-patterns.md
│   │   └── [+ 24 more incl. Anthropics SDK refs, prompt series, role-spec variants]
│   ├── #KNOWLEDGE.MD/  (18 files)     # LLM config, Ollama, preset knowledge
│   │   ├── KNOWLEDGE.md
│   │   ├── preset_knowledge.yaml
│   │   ├── OLLAMA_OLLAMA.MD
│   │   ├── ollama.merged.py
│   │   ├── R3OllamaClient.js
│   │   ├── R3-OLLAMA-CONFIG.ps1
│   │   ├── n8n Blueprint LLM Integration.md
│   │   ├── Mountpoint-Matrix_PostgreSQL-SETTINGS.json
│   │   ├── FullAccess-Dashscope-ModelStudio.json
│   │   └── THREAT_MODEL.md
│   ├── #MEMORY.MD/  (14 files)        # Mountpoint matrices, session state
│   │   ├── MEMORY.md, mempalace.md
│   │   ├── Mountpoint-Matrix_*.merged.json (×5)
│   │   ├── mountpoint-schema.merged.json
│   │   └── mountpoints.merged.js
│   ├── #SKILLS.MD/  (9 files)         # SKILL.md merged, marketing skills
│   │   ├── SKILL.merged.md
│   │   ├── AI Marketing Skills.md
│   │   ├── CLAUDE CODE CLONING-SKILL.yaml
│   │   └── R³ MARKETINGSKILLS.MD
│   ├── #STRATEGY.MD/  (29 files)      # Strategy specs, generator specs
│   │   ├── R³ CORE STRATEGY.md
│   │   ├── R3-DASHBOARD-SPEC.merged.md
│   │   ├── generator-spec.merged.yaml
│   │   ├── generator-output-spec.merged.yaml
│   │   ├── preflight-spec.merged.yaml
│   │   ├── MOD-07-STAMMDATEN-GENERATOR-SPEC.md (×2)
│   │   ├── incident-log.merged.md
│   │   ├── Mountpoint-Matrix_workplace-live-2.json
│   │   ├── plan.md
│   │   └── r3-mod07-v3-handoff-spec.json/.md
│   ├── #SYSTEM.MD/  (804 files)       # Flat merged dump of all system files
│   │   # Contains: Python (.py), TS/JS, config, env, merged/smartmerge variants
│   │   # Notable: .env files per provider (SHOPIFY, REDDIT, YOUTUBE, POSTGRESQL,
│   │   #   HUGGINGFACE, EMERGENT, MERCHANT, SEVDESK, TIKTOK, INDEED, REPLIT, etc.)
│   │   # Notable: obliteratus Python pkg merged, engine-registry merged,
│   │   #   matrix-control-8422 live snapshots, shopify sync workflows
│   │   # Index: GH_MD/#SYSTEM.MD/_INDEX_SYSTEM.MD.md
│   ├── CANONICAL_JS_MASTER/           # Canonical JS server
│   │   ├── server.js, R3-AUTO-MOUNT-HOOK.js, r3-mount-api.js
│   │   ├── lib/
│   │   │   └── avatar-engine, providers, registry, router, runtime-env, skills.js
│   │   └── src/                       # mirrors _reference-js-master/src/lib/
│   ├── LOGICAL_MASTER_JS/             # Logical JS master
│   │   ├── server.js, R3-AUTO-MOUNT-HOOK.js, r3-mount-api.js
│   │   ├── lib/
│   │   │   └── avatar-engine, providers, registry, router, runtime-env, skills.js
│   │   └── src/                       # mirrors _reference-js-master/src/lib/
│   └── Dashboard_START/               # Launcher scripts, registry.js
│       ├── server.js, registry.js
│       ├── R3-AUTO-MOUNT-HOOK.js, r3-mount-api.js
│       ├── ConnectorsModal.tsx
│       ├── r3-hidden-launcher.vbs
│       ├── R3-RUN.ps1, R3-START-SILENT.ps1, R3-STOP-SERVERS.ps1
│       └── R3-NODE-CONNECTOR.ps1
│
├── MODULES/
│   ├── agent-reach-hq/                # HQ prompt & connector config
│   │   ├── agent-reach-router.yaml
│   │   ├── connector-matrix.yaml
│   │   ├── hq-coding-prompt.md
│   │   ├── hq-scripter-prompt.md
│   │   ├── deep-research-prompt.md
│   │   ├── obliteratus.md
│   │   ├── claude-code.md
│   │   ├── vscode-gadget.md
│   │   ├── local.sh, vps.sh
│   │   └── README.md
│   ├── agent-skills/                  # 21 skills + agent config
│   │   ├── AGENTS.md, CLAUDE.md, CONTRIBUTING.md, LICENSE, README.md
│   │   ├── .claude/, .claude-plugin/, .github/, agents/, docs/, hooks/, references/
│   │   └── skills/  (21 subdirs — all verified SKILL.md only, except idea-refine)
│   │       ├── api-and-interface-design/SKILL.md
│   │       ├── browser-testing-with-devtools/SKILL.md
│   │       ├── ci-cd-and-automation/SKILL.md
│   │       ├── code-review-and-quality/SKILL.md
│   │       ├── code-simplification/SKILL.md
│   │       ├── context-engineering/SKILL.md
│   │       ├── debugging-and-error-recovery/SKILL.md
│   │       ├── deprecation-and-migration/SKILL.md
│   │       ├── documentation-and-adrs/SKILL.md
│   │       ├── frontend-ui-engineering/SKILL.md
│   │       ├── git-workflow-and-versioning/SKILL.md
│   │       ├── idea-refine/
│   │       │   ├── SKILL.md, examples.md, frameworks.md
│   │       │   ├── refinement-criteria.md
│   │       │   └── scripts/idea-refine.sh
│   │       ├── incremental-implementation/SKILL.md
│   │       ├── performance-optimization/SKILL.md
│   │       ├── planning-and-task-breakdown/SKILL.md
│   │       ├── security-and-hardening/SKILL.md
│   │       ├── shipping-and-launch/SKILL.md
│   │       ├── source-driven-development/SKILL.md
│   │       ├── spec-driven-development/SKILL.md
│   │       ├── test-driven-development/SKILL.md
│   │       └── using-agent-skills/SKILL.md
│   ├── obliteratus/                   # Python ML model abliteration toolkit
│   │   ├── app.py                     # Flask entry point
│   │   ├── index.html
│   │   ├── Dockerfile
│   │   ├── pyproject.toml
│   │   ├── requirements.txt, requirements-apple.txt
│   │   ├── CONTRIBUTING.md, SECURITY.md, README.md
│   │   ├── docs/                          # Research documentation
│   │   │   ├── EFFICIENCY_AUDIT.md, RESEARCH_SURVEY.md, SENSITIVE_DATA_AUDIT.md
│   │   │   ├── mechanistic_interpretability_research.md, theory_journal.md
│   │   │   └── index.html
│   │   ├── examples/                      # YAML study configs
│   │   │   ├── full_study.yaml
│   │   │   ├── gpt2_head_ablation.yaml, gpt2_layer_ablation.yaml
│   │   │   ├── preset_attention.yaml, preset_knowledge.yaml, preset_quick.yaml
│   │   │   └── remote_gpu_node.yaml
│   │   ├── hf-spaces/
│   │   │   └── README.md
│   │   ├── notebooks/
│   │   │   └── abliterate.ipynb
│   │   ├── tests/                         # Pytest suite (15+ test files)
│   │   │   ├── __init__.py
│   │   │   ├── test_informed_pipeline.py, test_logit_lens.py, test_metrics.py
│   │   │   ├── test_module_imports.py, test_new_analysis_modules.py
│   │   │   ├── test_novel_analysis.py, test_refusal_detection.py, test_report.py
│   │   │   ├── test_strategies.py, test_study_presets.py
│   │   │   └── [+ more test files]
│   │   └── obliteratus/               # Python package internals
│   │       ├── __init__.py, __main__.py
│   │       ├── abliterate.py          # Core abliteration logic
│   │       ├── adaptive_defaults.py
│   │       ├── architecture_profiles.py
│   │       ├── bayesian_optimizer.py
│   │       ├── cli.py
│   │       ├── community.py
│   │       ├── config.py
│   │       ├── device.py
│   │       ├── informed_pipeline.py
│   │       └── [+ more: evaluator, presets, probing_classifiers, etc.]
│   ├── re-gre-generator/              # Core output generator (spec-driven)
│   │   ├── generator-spec.yaml
│   │   ├── generator-output-spec.yaml
│   │   ├── preflight-spec.yaml
│   │   ├── policy.yaml
│   │   ├── agent-reach-config.yaml
│   │   ├── bundle-manifest.yaml
│   │   ├── install_plan.py, build.py, serve.py
│   │   ├── define_next_module.py, define_output.py
│   │   ├── expand_registry.py, first_run.py
│   │   ├── register_connector.py
│   │   ├── run_install_plan.ps1, build.ps1
│   │   ├── pyproject.toml, requirements.txt
│   │   └── README.md
│   ├── re-agent-dispatcher/
│   │   ├── dispatcher.py
│   │   └── README.md
│   ├── re-local-agent-int/            # Anthropics Claude SDK reference docs
│   │   ├── Anthropics_Claude Client CLI.md
│   │   ├── Anthropics_Claude Client Java SDK.md
│   │   ├── Anthropics_Claude Client OpenAI SDK compatibility.md
│   │   ├── Anthropics_Claude Client Python SDK.md
│   │   ├── Anthropics_Claude Client SDKs.md
│   │   └── Anthropics_Claude Client TypeScript SDK.md
│   ├── re-output-collector/
│   │   └── collector.py
│   ├── re-preflight-agent/
│   │   ├── preflight_agent.py
│   │   └── preflight-report.json
│   ├── re-prompt-router/
│   │   ├── prompt_router.py
│   │   └── router-config.yaml
│   ├── re-provider-registry/
│   │   └── provider-account-registry.yaml
│   ├── re-social-connectors/
│   │   ├── social-connectors.yaml
│   │   └── specialty-connectors.yaml
│   └── g0dm0d3_hybrid_agent/          # Hybrid agent app (Node.js)
│       ├── data/, public/, scripts/, skills/
│       ├── .env.example, .env.local, .env.runtime
│       ├── .runtime-env-summary.json
│       ├── docker-compose.yml
│       └── package.json
│
├── n8n-workflows/                     # n8n workflow engine
│   ├── browser-dash/
│   │   ├── r3-master-hub-v2.html
│   │   ├── docker-compose.yml
│   │   ├── APPLY-N8N-FIX.ps1
│   │   ├── FINAL/FIX/INSTALL-R3.ps1
│   │   ├── health-check.sh
│   │   ├── token-refresh.sh
│   │   └── incident-log.md
│   └── workflow-agents/
│       ├── .claude.json
│       ├── .gitconfig
│       └── .wslconfig
│
├── NETWORK/                           # 11 mapped network devices
│   ├── APPSEN_C (Windows 500GB)
│   ├── DOCKER MCP NVMe (1024GB)
│   ├── FEDORA43 + KALI-LINUX + TOOL-KITS (320GB)
│   ├── RAZER (990EVO NVMe 5.0)
│   ├── STARLINK ROUTER UTR-232
│   └── [+ 6 more devices]
│
├── R_VIB.3_CENTRAL-DASHBOARD/         # Central dashboard sub-module
│
├── services/
│   ├── ki-api/                        # Python Flask AI routing API
│   │   ├── app.py, routing_engine.py
│   │   ├── Dockerfile, requirements.txt
│   │   └── [+ .bak variants]
│   └── r3-rec/                        # Node.js recommendation service
│       └── index.js [+ .bak variants]
│
├── SOURCE/
│   ├── chat-legs/                     # Main proxy server + React frontend
│   │   ├── [34 root files incl. .env, AGENT.md, KNOWLEDGE.md, MEMORY.md,
│   │   │   docker-compose*.yml, package.json, R3-AUTO-MOUNT-HOOK.js,
│   │   │   R3-Canonical-JS-PostDeployment-Integrity-Audit-v5.ps1,
│   │   │   r3-control-plane-overview-api-v2.js, R3-FIX-*.ps1]
│   │   ├── _backups/                  # Timestamped live-status patch sets
│   │   ├── _runtime/                  # matrix-control-plane/ live working copies
│   │   ├── bridges/
│   │   │   ├── openai-8512/
│   │   │   └── perplexity-8511/
│   │   ├── hf-proxy/
│   │   │   ├── Dockerfile, package.json, server.js
│   │   ├── lib/
│   │   │   └── (avatar-engine, providers, registry, router, runtime-env, skills).js
│   │   ├── node_modules/              # npm deps (excluded from map)
│   │   ├── payload/public/, src/, workspace/
│   │   ├── public/index.html
│   │   ├── r3_control_plane_live_package/
│   │   │   ├── control-plane-dashboard-router.js
│   │   │   └── R3-Install-Control-Plane-Dashboard.ps1
│   │   ├── r3_fix_bundle_v6/
│   │   │   ├── R3-Canonical-JS-PostDeployment-Integrity-Audit-v6-Hardened.ps1
│   │   │   └── r3-control-plane-overview-api-v3.cjs
│   │   ├── r3_matrix_control_plane_pack/payload/, README.md, scripts/
│   │   ├── r3_next_step_package/
│   │   │   ├── 002_r3_guardrail_control_plane.sql
│   │   │   ├── r3-control-plane-overview-api.js
│   │   │   └── R3-Install-Guardrail-Scheduler.ps1
│   │   ├── r3_next_step_package_rebuilt/  (same + .cjs variant)
│   │   ├── R3-Canonical-JS-Hardened-Toolchain-v4-Fix/
│   │   │   ├── R3-Install-*.ps1
│   │   │   └── R3-Activate-*.ps1
│   │   ├── scripts/windows/
│   │   │   ├── apply-r3-live-status-patch.ps1
│   │   │   └── rollback-r3-live-status-patch.ps1
│   │   ├── src/
│   │   │   ├── components/
│   │   │   │   └── ConnectorsModal.tsx
│   │   │   ├── lib/
│   │   │   │   └── avatar-engine.js, config.js, db.js + more
│   │   │   ├── providers/             # Provider integrations
│   │   │   ├── ConnectorsModal.tsx    # (also at src/ root)
│   │   │   └── server.js
│   │   └── workspace/live-status/current/ + backup sets
│   ├── data/
│   │   └── R3_VIBE_REGISTRY.json [+ 5× .bak]
│   ├── js/
│   │   ├── app.js, modules-loader.js, sync-engine.js
│   │   ├── rollback-registry.json
│   │   ├── shopify-order-ebay-deduct-v1.json
│   │   ├── shopify-price-sync-v1.json
│   │   └── upgrade-map.json
│   └── prompts/
│       ├── R³ VIB.E HD-PROMPT-GENERATOR.MD (×2 versions)
│       ├── MOD-07-STAMMDATEN-GENERATOR-SPEC.md (×2 versions)
│       ├── R3-DASHBOARD-BAUANLEITUNG-v2.md
│       ├── 4-Prompt Content Engine System.md
│       ├── AI Marketing Skills.md
│       ├── CLI-Aufruf.md
│       └── Setup-Script-CLI.md
│
├── dashboard.html                     # Root dashboard entry point
├── engine-registry.json               # Live engine registry (ports 8420/8421/8422)
├── n8n-mcp-bridge.mjs                 # n8n ↔ MCP bridge (ESM)
├── package.json                       # Root Node.js manifest
├── r3-vibe-dash-struktur.yaml         # Architecture YAML
├── tsconfig.json
└── Root PS1 scripts:
    R3-BOOTSTRAP.ps1    R3-BUILD-BASIC.ps1   R3-DEEP-SCAN.ps1
    R3-MERGE.ps1        R3-SMART-MERGE.ps1   R3-TREE.ps1
    R3-NODE-CONNECTOR.ps1  R3-TREE-NODE-CONNECTOR.ps1
    start-all.ps1       start-clean.ps1      start-visible.ps1
```

### SKILL.md Locations in R3-DASHBOARD

typeui.sh writes to / reads from these paths:

| Target                    | Path                                                   |
| ------------------------- | ------------------------------------------------------ |
| Universal (all providers) | `MODULES/agent-skills/skills/<slug>/SKILL.md`          |
| Claude Code               | `MODULES/agent-skills/CLAUDE.md` (managed block)       |
| Cursor / Windsurf         | `GH_MD/#AGENT.MD/cursor-setup.md`, `windsurf-setup.md` |
| Per-module skills         | `COLLECTED-OUTPUTS/<module>/SKILL.md`                  |
| HQ knowledge              | `GH_MD/#SKILLS.MD/SKILL.merged.md`                     |

### typeui.sh Integration Points

```sh
# Run from R3-DASHBOARD root (Windows):
node dist/cli.js generate        # Scaffold new SKILL.md for a module
node dist/cli.js pull <slug>     # Pull design-system skill from registry
node dist/cli.js update          # Rewrite managed blocks only

# Relevant registries:
#   engine-registry.json                              — active engine ports/status
#   SOURCE/data/R3_VIBE_REGISTRY.json                 — vibe provider registry
#   MODULES/re-provider-registry/provider-account-registry.yaml
```

### Deep-Read Navigation

See `r3-node-map.json` in workspace root for the full structured index.
Quick reference by goal:

| Goal                    | Start with                                        |
| ----------------------- | ------------------------------------------------- |
| Understand architecture | docker/ → SOURCE/chat-legs/lib/ → engine-registry |
| Work on agent system    | MODULES/agent-skills/skills/ → GH_MD/#AGENT.MD/   |
| Work on frontend        | SOURCE/chat-legs/src/ → SOURCE/chat-legs/public/  |
| Work on generator       | MODULES/re-gre-generator/ → GH_MD/#STRATEGY.MD/   |
| Debug production        | SOURCE/chat-legs/\_runtime/ → GH_MD/#SYSTEM.MD/   |
| Orient new agent        | 01.] R³ INSTRUCTIONS/ → GH_MD/#KNOWLEDGE.MD/      |
