# Add-NodeMap-Dashboard.ps1
# Ergänzt den Control Plane Router (createControlPlaneRouter / buildOverview) um:
#   1. nodeMapJson in collectSources() — liest r3-node-map.json aus R3-DASHBOARD Root
#   2. loadNodeMapData() Funktion — extrahiert Domains + Snapshots
#   3. nodeMap in buildOverview() Return
#   4. GET /api/node-map Endpoint
#   5. HTML Panel "Node Map — Domain Index" im Dashboard
#   6. renderNodeMap() + loadNodeMap() JS im Dashboard
#
# Setzt voraus: r3-node-map.json liegt in C:\Users\mail\R3-DASHBOARD\
# Falls nicht vorhanden: Script bietet Download an.
#
# Ausführen: pwsh -File "C:\Users\mail\R3-DASHBOARD\Add-NodeMap-Dashboard.ps1"

$chatLegs  = "C:\Users\mail\R3-DASHBOARD\SOURCE\chat-legs"
$r3Root    = "C:\Users\mail\R3-DASHBOARD"
$nodeMapDst = "$r3Root\r3-node-map.json"

# ─── r3-node-map.json auf Windows-Host sicherstellen ─────────────────────────
if (-not (Test-Path $nodeMapDst)) {
    Write-Host "INFO: r3-node-map.json nicht in $r3Root gefunden." -ForegroundColor Yellow
    Write-Host "Versuche Download aus session-state Repo..." -ForegroundColor Cyan
    try {
        $url = "https://raw.githubusercontent.com/RETOURENROYAL/session-state/main/r3-node-map.json"
        Invoke-WebRequest -Uri $url -OutFile $nodeMapDst -UseBasicParsing -ErrorAction Stop
        Write-Host "OK: r3-node-map.json heruntergeladen." -ForegroundColor Green
    } catch {
        Write-Host "WARN: Download fehlgeschlagen ($_). Bitte manuell kopieren:" -ForegroundColor Yellow
        Write-Host "  Codespace: /workspaces/session-state/r3-node-map.json" -ForegroundColor Gray
        Write-Host "  Windows:   $nodeMapDst" -ForegroundColor Gray
        Write-Host "  Control Plane wird trotzdem gepatcht (zeigt 'nicht gefunden' bis Datei vorhanden)." -ForegroundColor Gray
    }
} else {
    Write-Host "OK: r3-node-map.json vorhanden in $r3Root" -ForegroundColor Green
}

# ─── Control Plane Router finden ─────────────────────────────────────────────
Write-Host ""
Write-Host "Suche Control Plane Router (createControlPlaneRouter + buildOverview)..." -ForegroundColor Cyan

$routerFile = $null
Get-ChildItem -Path $chatLegs -Recurse -Include "*.js","*.cjs","*.mjs" -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt 1000 } |
    ForEach-Object {
        if ($routerFile) { return }
        try {
            $t = [System.IO.File]::ReadAllText($_.FullName)
            if ($t -match 'createControlPlaneRouter' -and $t -match 'buildOverview' -and $t -match 'collectSources') {
                $routerFile = $_.FullName
            }
        } catch {}
    }

if (-not $routerFile) {
    Write-Host "ERROR: Control Plane Router nicht gefunden in $chatLegs" -ForegroundColor Red
    Write-Host "Gesucht: createControlPlaneRouter + buildOverview + collectSources" -ForegroundColor Gray
    Write-Host "Bitte Dateipfad prüfen oder manuell patchen." -ForegroundColor Gray
    exit 1
}

Write-Host "Gefunden: $routerFile" -ForegroundColor Green

$raw     = [System.IO.File]::ReadAllText($routerFile, [System.Text.Encoding]::UTF8)
$content = $raw.Replace("`r`n", "`n")  # Normalisiere LF

$backup = $routerFile + '.bak-nodemap-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
[System.IO.File]::Copy($routerFile, $backup)
Write-Host "Backup: $backup" -ForegroundColor DarkGray

# ─── Guard: bereits gepatcht? ────────────────────────────────────────────────
if ($content -match 'loadNodeMapData') {
    Write-Host ""
    Write-Host "INFO: loadNodeMapData bereits vorhanden — kein Patch notwendig." -ForegroundColor Yellow
    Write-Host "Falls neu patchen gewünscht: Backup wiederherstellen und erneut ausführen." -ForegroundColor Gray
    exit 0
}

$steps = 0

# ═══════════════════════════════════════════════════════════════════════════════
# SCHRITT 1: nodeMapJson in collectSources() einfügen
# ═══════════════════════════════════════════════════════════════════════════════
$OLD1 = "    automationDir: resolveFirstExisting("
$NEW1 = "    nodeMapJson: resolveFirstExisting(`n      path.join(dashboardRoot, 'r3-node-map.json')`n    ),`n    automationDir: resolveFirstExisting("

if ($content.Contains($OLD1)) {
    $content = $content.Replace($OLD1, $NEW1)
    $steps++
    Write-Host "  [1/6] nodeMapJson in collectSources() eingefügt" -ForegroundColor Green
} else {
    Write-Host "  [1/6] WARN: automationDir-Pattern nicht gefunden" -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCHRITT 2: loadNodeMapData() Funktion einfügen (vor buildAutomationSummary)
# ═══════════════════════════════════════════════════════════════════════════════
$OLD2 = "function buildAutomationSummary(sources) {"
$NEW2 = @'
function loadNodeMapData(sources) {
  const nm = readJsonSafe(sources.nodeMapJson) || {};
  const domains = nm.domains || {};
  const snapshots = nm.content_snapshots || {};

  const domainList = Object.entries(domains)
    .filter(function(entry) { return !entry[0].startsWith('_'); })
    .map(function(entry) {
      const key = entry[0]; const d = entry[1];
      return {
        key: key,
        description: d.description || '',
        completeness: d.completeness || 'UNKNOWN',
        exportFiles: (d.export_files || []).length,
      };
    });

  const snapshotList = Object.entries(snapshots)
    .filter(function(entry) { return !entry[0].startsWith('_'); })
    .map(function(entry) {
      const key = entry[0]; const s = entry[1];
      return {
        key: key,
        status: s.status || '?',
        fileCount: s.file_count || 0,
        sizeKb: s.size_kb || 0,
        scanned: s.scanned || '',
      };
    });

  const meta = nm._meta || {};
  return {
    exists: !!sources.nodeMapJson,
    generated: meta.generated || null,
    projectRoot: meta.local_root || null,
    totalDomains: domainList.length,
    fullDomains: domainList.filter(function(d) { return d.completeness === 'FULL'; }).length,
    domains: domainList,
    snapshots: snapshotList,
    readOrderGoals: Object.keys(nm.read_order_by_goal || {}),
  };
}

function buildAutomationSummary(sources) {
'@.Replace("`r`n", "`n")

if ($content.Contains($OLD2)) {
    $content = $content.Replace($OLD2, $NEW2)
    $steps++
    Write-Host "  [2/6] loadNodeMapData() Funktion eingefügt" -ForegroundColor Green
} else {
    Write-Host "  [2/6] WARN: buildAutomationSummary-Pattern nicht gefunden" -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCHRITT 3: nodeMap in buildOverview() Return einfügen
# Suche nach "    automation," unmittelbar vor "    sources:" im return-Objekt
# ═══════════════════════════════════════════════════════════════════════════════
# Versuche exaktes Muster
$OLD3a = "    automation,`n    sources:"
$OLD3b = "    automation,`n    sources:"   # identisch, zweiter Versuch ohne Whitespace-Varianz
$NEW3  = "    automation,`n    nodeMap: loadNodeMapData(sources),`n    sources:"

if ($content.Contains($OLD3a)) {
    $content = $content.Replace($OLD3a, $NEW3)
    $steps++
    Write-Host "  [3/6] nodeMap in buildOverview() Return eingefügt" -ForegroundColor Green
} else {
    # Fallback: suche "automation," allein auf einer Zeile gefolgt von "sources:"
    $content = $content -replace "(\s{4}automation,\n)(\s{4}sources:)", "`$1    nodeMap: loadNodeMapData(sources),`n`$2"
    if ($content -match 'loadNodeMapData\(sources\)') {
        $steps++
        Write-Host "  [3/6] nodeMap in buildOverview() Return eingefügt (regex)" -ForegroundColor Green
    } else {
        Write-Host "  [3/6] WARN: automation/sources Pattern nicht gefunden — manuell `'nodeMap: loadNodeMapData(sources),`' im return von buildOverview() einfügen" -ForegroundColor Yellow
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCHRITT 4: /api/node-map Route einfügen (vor /api/sources)
# ═══════════════════════════════════════════════════════════════════════════════
$OLD4 = "  router.get('/api/sources', (_req, res) => {"
$NEW4 = "  router.get('/api/node-map', (_req, res) => {`n    res.json(buildOverview(options).nodeMap);`n  });`n`n  router.get('/api/sources', (_req, res) => {"

if ($content.Contains($OLD4)) {
    $content = $content.Replace($OLD4, $NEW4)
    $steps++
    Write-Host "  [4/6] GET /api/node-map Route eingefügt" -ForegroundColor Green
} else {
    Write-Host "  [4/6] WARN: /api/sources Route Pattern nicht gefunden" -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCHRITT 5: HTML Panel "Node Map" vor dem footer einfügen
# ═══════════════════════════════════════════════════════════════════════════════
$OLD5 = '    <div class="footer" id="footer"></div>'
$NEW5 = @'
    <div class="panel" style="margin-top:16px;">
      <h3>Node Map &mdash; Domain Index <span id="nodemap-meta" style="font-weight:400;color:var(--muted);font-size:12px;margin-left:8px;"></span></h3>
      <div id="nodemap-content"><div class="empty muted">Lade...</div></div>
    </div>

    <div class="footer" id="footer"></div>
'@.Replace("`r`n", "`n")

if ($content.Contains($OLD5)) {
    $content = $content.Replace($OLD5, $NEW5)
    $steps++
    Write-Host "  [5/6] Node Map HTML Panel eingefügt" -ForegroundColor Green
} else {
    Write-Host "  [5/6] WARN: footer Panel Pattern nicht gefunden" -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCHRITT 6: renderNodeMap() Funktion + loadNodeMap() JS + Refresh-Button update
# ═══════════════════════════════════════════════════════════════════════════════
$OLD6 = "    document.getElementById('refreshBtn').addEventListener('click', () => load().catch(renderError));"
$NEW6 = @'
    function renderNodeMap(data) {
      const el = document.getElementById('nodemap-content');
      const meta = document.getElementById('nodemap-meta');
      if (!el) return;
      if (!data || !data.exists) {
        el.innerHTML = '<div class="empty">r3-node-map.json nicht gefunden — bitte in R3-DASHBOARD Root ablegen und Server neu starten.</div>';
        return;
      }
      if (meta) meta.textContent = 'Generated: ' + (data.generated || 'n/a') + ' \u00b7 ' + data.fullDomains + '/' + data.totalDomains + ' FULL';
      const rows = data.domains || [];
      const snaps = data.snapshots || [];
      const tableRows = rows.map(function(row) {
        const badge = row.completeness === 'FULL'
          ? '<span class="badge ok">FULL</span>'
          : (row.completeness === 'UNKNOWN' ? '<span class="badge warn">?</span>' : '<span class="badge err">' + row.completeness + '</span>');
        return '<tr><td class="mono" style="white-space:nowrap">' + row.key + '</td>' +
          '<td>' + badge + '</td>' +
          '<td style="font-size:13px">' + (row.description || '') + '</td>' +
          '<td style="text-align:right;color:var(--muted);font-size:12px">' + (row.exportFiles || 0) + ' exports</td></tr>';
      }).join('');
      const snapRows = snaps.map(function(s) {
        const badge = s.status === 'FULL' ? '<span class="badge ok">FULL</span>' : '<span class="badge warn">' + s.status + '</span>';
        return '<tr><td class="mono">' + s.key + '</td><td>' + badge + '</td>' +
          '<td>' + (s.fileCount || 0) + ' files</td>' +
          '<td style="color:var(--muted);font-size:12px">' + (s.sizeKb || 0) + ' KB</td>' +
          '<td style="color:var(--muted);font-size:12px">' + (s.scanned || '') + '</td></tr>';
      }).join('');
      el.innerHTML =
        '<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">' +
          '<div>' +
            '<div style="font-size:12px;color:var(--muted);margin-bottom:8px;font-weight:600">DOMAINS</div>' +
            '<table><thead><tr><th>Key</th><th>Status</th><th>Beschreibung</th><th>Exports</th></tr></thead>' +
            '<tbody>' + tableRows + '</tbody></table>' +
          '</div>' +
          '<div>' +
            '<div style="font-size:12px;color:var(--muted);margin-bottom:8px;font-weight:600">CONTENT SNAPSHOTS</div>' +
            '<table><thead><tr><th>Key</th><th>Status</th><th>Dateien</th><th>Größe</th><th>Gescannt</th></tr></thead>' +
            '<tbody>' + (snapRows || '<tr><td colspan="5" class="muted">keine Snapshots</td></tr>') + '</tbody></table>' +
          '</div>' +
        '</div>';
    }

    async function loadNodeMap() {
      try {
        const r = await fetch('./api/node-map', { cache: 'no-store' });
        if (r.ok) renderNodeMap(await r.json());
      } catch (_e) {
        const el = document.getElementById('nodemap-content');
        if (el) el.innerHTML = '<div class="empty">/api/node-map nicht erreichbar (' + _e.message + ')</div>';
      }
    }

    document.getElementById('refreshBtn').addEventListener('click', function() {
      load().catch(renderError);
      loadNodeMap();
    });
'@.Replace("`r`n", "`n")

if ($content.Contains($OLD6)) {
    $content = $content.Replace($OLD6, $NEW6)
    $steps++
    Write-Host "  [6/6] renderNodeMap() + loadNodeMap() JS eingefügt" -ForegroundColor Green
} else {
    Write-Host "  [6/6] WARN: refreshBtn-Pattern nicht gefunden" -ForegroundColor Yellow
}

# Update finaler load()-Aufruf um loadNodeMap() zu ergänzen
$OLD_LOAD = "    load().catch(renderError);`n  </script>"
$NEW_LOAD = "    load().catch(renderError);`n    loadNodeMap();`n  </script>"
if ($content.Contains($OLD_LOAD)) {
    $content = $content.Replace($OLD_LOAD, $NEW_LOAD)
    Write-Host "  [+]  loadNodeMap() beim Start aktiviert" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════════════════════
# Schreiben
# ═══════════════════════════════════════════════════════════════════════════════
if ($steps -gt 0) {
    [System.IO.File]::WriteAllText($routerFile, $content, (New-Object System.Text.UTF8Encoding $false))
    Write-Host ""
    Write-Host "DONE: $steps/6 Patches angewendet auf:" -ForegroundColor Green
    Write-Host "  $routerFile" -ForegroundColor White
    Write-Host ""
    Write-Host "Nächste Schritte:" -ForegroundColor Cyan
    Write-Host "  1. Server neu starten (Port 8420 / 8421 / 8422 je nach Setup)" -ForegroundColor Gray
    Write-Host "  2. Dashboard aufrufen und 'Refresh' klicken" -ForegroundColor Gray
    Write-Host "  3. Neuer Bereich 'Node Map — Domain Index' zeigt 19 Domains" -ForegroundColor Gray
    Write-Host "  4. /api/node-map liefert JSON (direkt aufrufbar)" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "WARN: Keine Patches angewendet — Patterns nicht gefunden." -ForegroundColor Yellow
    Write-Host "Datei: $routerFile" -ForegroundColor Gray
    Write-Host "Prüfen ob bereits gepatcht oder Datei-Struktur abweicht." -ForegroundColor Gray
}
