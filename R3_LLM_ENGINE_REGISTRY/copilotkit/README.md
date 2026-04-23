# R³ VIB.E — CopilotKit Integration

Integriert [CopilotKit](https://docs.copilotkit.ai) in den R³-Stack.
**Backend**: ChatLegs `:8420`/`:8421` — **Frontend**: React (`SOURCE/chat-legs/src/`)

---

## 📦 Installation

```bash
# Im R3-DASHBOARD Root:
node R3_LLM_ENGINE_REGISTRY/copilotkit/install.js
```

Oder manuell:

```bash
cd SOURCE/chat-legs
npm install @copilotkit/runtime @copilotkit/react-core @copilotkit/react-ui
```

---

## 🔌 Schritt 1 — Backend Runtime (server.js)

In `SOURCE/chat-legs/server.js` einfügen:

```javascript
const {
  registerCopilotKit,
} = require("../../R3_LLM_ENGINE_REGISTRY/copilotkit/runtime");

// Nach app = express() und Middleware:
registerCopilotKit(app);
// → CopilotKit runtime verfügbar unter POST /copilotkit
// → Nutzt LiteLLM :4000 (r3/fast default)
// → MCP tools von :8420/:8421 werden automatisch eingebunden
```

**Endpoint:** `http://localhost:8420/copilotkit`

---

## ⚛️ Schritt 2 — React Provider einbinden

In `SOURCE/chat-legs/src/App.tsx` (oder `index.tsx`):

```tsx
import { R3CopilotProvider } from "../../R3_LLM_ENGINE_REGISTRY/copilotkit/components/R3CopilotProvider";

export default function App() {
  return (
    <R3CopilotProvider>
      <YourExistingApp />
    </R3CopilotProvider>
  );
}
```

Fügt automatisch ein Chat-Popup (CopilotPopup) zur Seite hinzu.

---

## 🛠️ Schritt 3 — Frontend Tools registrieren

In beliebiger React-Komponente (Kind von `R3CopilotProvider`):

```tsx
import { useR3FrontendTools } from "../../R3_LLM_ENGINE_REGISTRY/copilotkit/hooks/useR3FrontendTools";

function Dashboard() {
  useR3FrontendTools(); // Registriert alle r3-Tools
  return <div>...</div>;
}
```

**Verfügbare Tools für den Agenten:**

| Tool               | Beschreibung                                   |
| ------------------ | ---------------------------------------------- |
| `listR3Routes`     | Alle LiteLLM-Routen auflisten                  |
| `queryR3Model`     | Prompt an r3/code, r3/reasoning, etc. senden   |
| `getR3StackStatus` | Alle Dienste live prüfen                       |
| `embedText`        | Text-Embedding via r3/embed (nomic-embed-text) |

---

## 🔑 MCP: GitHub MCP Server

**VS Code `mcp.json`** (`C:\Users\mail\AppData\Roaming\Code\User\mcp.json`):

```json
{
  "servers": {
    "r3-chatlegs-primary": {
      "type": "sse",
      "url": "http://localhost:8420/mcp"
    },
    "r3-chatlegs-shadow": { "type": "sse", "url": "http://localhost:8421/mcp" },
    "github": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-e",
        "GITHUB_PERSONAL_ACCESS_TOKEN",
        "ghcr.io/github/github-mcp-server"
      ],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${input:github_token}" }
    }
  }
}
```

> ⚠️ `GITHUB_HOST` für `github-mcp-server` muss eine echte GitHub-Instanz sein (`https://api.github.com`), NICHT `localhost:8420/8421`. Ohne `GITHUB_HOST` wird automatisch `api.github.com` verwendet.

**PowerShell Paste** (schreibt die korrekte mcp.json):

```powershell
@'
{
  "servers": {
    "r3-chatlegs-primary": { "type": "sse", "url": "http://localhost:8420/mcp" },
    "r3-chatlegs-shadow":  { "type": "sse", "url": "http://localhost:8421/mcp" },
    "github": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-e", "GITHUB_PERSONAL_ACCESS_TOKEN", "ghcr.io/github/github-mcp-server"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${input:github_token}" }
    }
  }
}
'@ | Set-Content "$env:APPDATA\Code\User\mcp.json" -Encoding UTF8
```

---

## 📁 Dateien

| Datei                              | Zweck                                   |
| ---------------------------------- | --------------------------------------- |
| `runtime.js`                       | CopilotKit Runtime für Express/ChatLegs |
| `components/R3CopilotProvider.tsx` | React Provider + Chat-Popup             |
| `hooks/useR3FrontendTools.tsx`     | useFrontendTool hooks (4 Tools)         |
| `install.js`                       | npm-Abhängigkeiten installieren         |

---

## Architektur

```
React Frontend (src/)
  └─ <R3CopilotProvider runtimeUrl=":8420/copilotkit">
        └─ useR3FrontendTools()  ← client-side tools
              ↕
ChatLegs :8420 (server.js)
  └─ POST /copilotkit  ← CopilotKit Runtime
        ├─ LLM → LiteLLM :4000 (r3/fast)
        └─ MCP → :8420/mcp + :8421/mcp (SSE)
```
