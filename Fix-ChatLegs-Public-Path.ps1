# Fix-ChatLegs-Public-Path.ps1
# Behebt: ENOENT: C:\Users\mail\R3-DASHBOARD\SOURCE\public\index.html
# Ursache: appRoot zeigt auf SOURCE\ statt SOURCE\chat-legs\
#
# Führt mehrere Pattern-Fixes aus (erster Treffer gewinnt):
#   Fix A: path.resolve(__dirname, '..') → path.resolve(__dirname)
#   Fix B: path.join(R3_ROOT, 'SOURCE')  → path.join(R3_ROOT, 'SOURCE', 'chat-legs')
#   Fix C: express.static(.., '..', 'public') → ohne '..'
#   Fix D: Fallback — hardcoded korrekte public-Path in static/sendFile
#
# Ausführen: pwsh -File "C:\Users\mail\R3-DASHBOARD\Fix-ChatLegs-Public-Path.ps1"

$serverPath = "C:\Users\mail\R3-DASHBOARD\SOURCE\chat-legs\server.js"

if (-not (Test-Path $serverPath)) {
    Write-Host "ERROR: $serverPath nicht gefunden." -ForegroundColor Red
    exit 1
}

$content = [System.IO.File]::ReadAllText($serverPath, [System.Text.Encoding]::UTF8)

# Backup
$backup = $serverPath + '.bak-pubfix-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
[System.IO.File]::Copy($serverPath, $backup)
Write-Host "Backup: $backup" -ForegroundColor DarkGray

$changed = $false

# ── Fix A: const appRoot = path.resolve(__dirname, '..') → path.resolve(__dirname) ──
if ($content -match [regex]::Escape("path.resolve(__dirname, '..')")) {
    $content = $content.Replace("path.resolve(__dirname, '..')", "path.resolve(__dirname)")
    $changed = $true
    Write-Host "Fix A: path.resolve(__dirname, '..') → path.resolve(__dirname)" -ForegroundColor Cyan
}

# ── Fix B: path.join(R3_ROOT, 'SOURCE') → path.join(R3_ROOT, 'SOURCE', 'chat-legs') ──
if (-not $changed -and $content -match [regex]::Escape("path.join(R3_ROOT, 'SOURCE')")) {
    $content = $content.Replace("path.join(R3_ROOT, 'SOURCE')", "path.join(R3_ROOT, 'SOURCE', 'chat-legs')")
    $changed = $true
    Write-Host "Fix B: R3_ROOT/SOURCE → R3_ROOT/SOURCE/chat-legs" -ForegroundColor Cyan
}

# ── Fix C: express.static mit '..' in public-Pfad ──
foreach ($variant in @(
    "express.static(path.join(appRoot, '..', 'public'))",
    "express.static(path.resolve(appRoot, '..', 'public'))"
)) {
    if (-not $changed -and $content.Contains($variant)) {
        $content = $content.Replace($variant, "express.static(path.join(appRoot, 'public'))")
        $changed = $true
        Write-Host "Fix C: express.static '..' entfernt" -ForegroundColor Cyan
    }
}

# ── Fix D: Fallback — hardcode den korrekten public-Pfad direkt ──
if (-not $changed) {
    $wrongStatic  = "express.static(path.join(appRoot, 'public'))"
    $correctStatic = "express.static(path.join('C:\\Users\\mail\\R3-DASHBOARD\\SOURCE\\chat-legs', 'public'))"
    if ($content.Contains($wrongStatic)) {
        $content = $content.Replace($wrongStatic, $correctStatic)
        $changed = $true
        Write-Host "Fix D: express.static auf expliziten chat-legs Pfad gesetzt" -ForegroundColor Cyan
    }
}

# ── sendFile SPA-Fallback korrigieren (falls '..' vorhanden) ──
foreach ($variant in @(
    "path.join(appRoot, '..', 'public', 'index.html')",
    "path.resolve(appRoot, '..', 'public', 'index.html')"
)) {
    if ($content.Contains($variant)) {
        $content = $content.Replace($variant, "path.join(appRoot, 'public', 'index.html')")
        $changed = $true
        Write-Host "Fix SPA: sendFile '..' entfernt" -ForegroundColor Cyan
    }
}

# ── Schreiben ──
if ($changed) {
    [System.IO.File]::WriteAllText($serverPath, $content, (New-Object System.Text.UTF8Encoding $false))
    Write-Host ""
    Write-Host "DONE: public-path fix angewendet." -ForegroundColor Green
    Write-Host "Bitte Server neu starten." -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "WARN: Kein passendes Pattern gefunden." -ForegroundColor Yellow
    Write-Host "Bitte diesen Block aus server.js einfügen (manuell vor die express.static Zeile):" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  // R3-PATH-FIX" -ForegroundColor White
    Write-Host "  const _r3Public = path.join('C:\\Users\\mail\\R3-DASHBOARD\\SOURCE\\chat-legs', 'public');" -ForegroundColor White
    Write-Host "  // dann ersetze: path.join(appRoot, 'public') -> _r3Public" -ForegroundColor White
    Write-Host ""
    Write-Host "Aktueller appRoot-Wert laut Fehler: C:\Users\mail\R3-DASHBOARD\SOURCE" -ForegroundColor Gray
    Write-Host "Erwartet:                           C:\Users\mail\R3-DASHBOARD\SOURCE\chat-legs" -ForegroundColor Gray
}
