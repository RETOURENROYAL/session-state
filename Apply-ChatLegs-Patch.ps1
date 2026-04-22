# Apply-ChatLegs-Patch.ps1
# Ergänzt SOURCE/chat-legs/server.js um:
#   POST /v1/chat/completions  — OpenAI-kompatibles SSE-Streaming (das was das Dashboard aufruft)
#   GET  /health               — Health-Alias (für Chip-Ping im Dashboard)
#   GET  /status               — Status-Alias (für Chip-Ping im Dashboard)
#
# Ausführen (einmalig):
#   pwsh -File "C:\Users\mail\R3-DASHBOARD\Apply-ChatLegs-Patch.ps1"
# oder direkt in PowerShell einfügen und ausführen.

$serverPath = "C:\Users\mail\R3-DASHBOARD\SOURCE\chat-legs\server.js"
$marker     = "// ── Fallback SPA"

# ─── Patch-Code (wird VOR dem Fallback-SPA eingefügt) ────────────────────────
$patch = @'

// ── OpenAI-compatible /v1/chat/completions ────────────────────────────────────
// Wird vom R3-Dashboard-Frontend (dashboard.html / R3-DASHBOARD-CENTRAL.html)
// für SSE-Streaming-Chat aufgerufen.
app.post('/v1/chat/completions', async (req, res) => {
  const { messages = [], model = 'auto', stream = false } = req.body || {};
  if (!messages.length) { res.status(400).json({ error: 'messages required' }); return; }

  const prompt = [...messages].reverse().find(m => m.role === 'user')?.content || '';
  const plan   = buildRoutingPlan({
    config, prompt, skillId: '/chat',
    mode: config.defaultMode, execution: config.defaultExecution,
  });

  if (plan.candidates.length === 0) {
    res.status(503).json({ error: 'No providers available' });
    return;
  }

  if (stream) {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.flushHeaders();
  }

  try {
    const result = await executePlan({ config, plan, messages });
    const text   = result.winner?.content
                ?? result.winner?.message?.content
                ?? result.results?.[0]?.content
                ?? result.results?.[0]?.message?.content
                ?? '';
    const id      = 'chatcmpl-' + Date.now();
    const created = Math.floor(Date.now() / 1000);
    const mdl     = result.winner?.provider || model;

    if (stream) {
      const d1 = {
        id, object: 'chat.completion.chunk', created, model: mdl,
        choices: [{ index: 0, delta: { role: 'assistant', content: text }, finish_reason: null }],
      };
      res.write('data: ' + JSON.stringify(d1) + '\n\n');
      const d2 = {
        id, object: 'chat.completion.chunk', created, model: mdl,
        choices: [{ index: 0, delta: {}, finish_reason: 'stop' }],
      };
      res.write('data: ' + JSON.stringify(d2) + '\n\n');
      res.write('data: [DONE]\n\n');
      res.end();
    } else {
      res.json({
        id, object: 'chat.completion', created, model: mdl,
        choices: [{ index: 0, message: { role: 'assistant', content: text }, finish_reason: 'stop' }],
        usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 },
      });
    }
  } catch (err) {
    if (stream && res.headersSent) {
      res.write('data: ' + JSON.stringify({ error: err.message }) + '\n\n');
      res.end();
    } else {
      res.status(500).json({ error: err.message || 'Chat completion failed' });
    }
  }
});

// ── Health / Status aliases (für Dashboard-Chip-Ping) ────────────────────────
app.get('/health', (_req, res) =>
  res.json({ status: 'ok', app: config.appName, port, ts: new Date().toISOString() }));
app.get('/status', (_req, res) =>
  res.json({ status: 'ok', app: config.appName, port, ts: new Date().toISOString() }));

'@

# ─── Patch anwenden ──────────────────────────────────────────────────────────
if (-not (Test-Path $serverPath)) {
  Write-Host "ERROR: $serverPath nicht gefunden." -ForegroundColor Red
  exit 1
}

$content = [System.IO.File]::ReadAllText($serverPath, [System.Text.Encoding]::UTF8)

if ($content.Contains('/v1/chat/completions')) {
  Write-Host "SKIP: /v1/chat/completions bereits vorhanden — kein Patch nötig." -ForegroundColor Yellow
  exit 0
}

if (-not $content.Contains($marker)) {
  Write-Host "ERROR: Marker '$marker' nicht in server.js gefunden." -ForegroundColor Red
  exit 1
}

# Backup anlegen
$backupPath = $serverPath + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
[System.IO.File]::Copy($serverPath, $backupPath)
Write-Host "Backup: $backupPath" -ForegroundColor DarkGray

# Einfügen vor dem Fallback-SPA marker
$patched = $content.Replace($marker, $patch + $marker)
[System.IO.File]::WriteAllText($serverPath, $patched, (New-Object System.Text.UTF8Encoding $false))

Write-Host ""
Write-Host "DONE: server.js gepatcht." -ForegroundColor Green
Write-Host "  + POST /v1/chat/completions  (SSE streaming — Dashboard-Chat)" -ForegroundColor Cyan
Write-Host "  + GET  /health               (Chip-Ping)" -ForegroundColor Cyan
Write-Host "  + GET  /status               (Chip-Ping)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Jetzt Server neu starten (z.B. node server.js oder start-all.ps1)." -ForegroundColor White
