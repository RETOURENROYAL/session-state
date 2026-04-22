# Fix-SPA-SendFile.ps1
# Behebt: SPA-Fallback res.sendFile() liefert "ui = r'''<!DOCTYPE html>..." statt index.html
# Ursache: Fix D hat express.static gepatcht, NICHT das sendFile in der Catch-All Route
# Folge:   GET /api/* ohne dedizierten Handler → SPA Fallback → falsche Datei → 8422 JSON-Fehler
#
# Ausführen: pwsh -File "C:\Users\mail\R3-DASHBOARD\Fix-SPA-SendFile.ps1"

$serverPath = "C:\Users\mail\R3-DASHBOARD\SOURCE\chat-legs\server.js"
$R3ChatLegs = 'C:\Users\mail\R3-DASHBOARD\SOURCE\chat-legs'

if (-not (Test-Path $serverPath)) {
    Write-Host "ERROR: $serverPath nicht gefunden." -ForegroundColor Red; exit 1
}

$raw = [System.IO.File]::ReadAllText($serverPath, [System.Text.Encoding]::UTF8)
# Normalisiere Zeilenenden
$content = $raw.Replace("`r`n", "`n")

$backup = $serverPath + '.bak-spafix-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
[System.IO.File]::Copy($serverPath, $backup)
Write-Host "Backup: $backup" -ForegroundColor DarkGray

$changed = $false

# Alle bekannten sendFile-Varianten für die SPA-Fallback-Route
$variants = @(
    # path.join mit einfachen Quotes
    "res.sendFile(path.join(appRoot, 'public', 'index.html'))",
    # path.join mit doppelten Quotes
    'res.sendFile(path.join(appRoot, "public", "index.html"))',
    # path.resolve mit einfachen Quotes
    "res.sendFile(path.resolve(appRoot, 'public', 'index.html'))",
    # path.resolve mit doppelten Quotes
    'res.sendFile(path.resolve(appRoot, "public", "index.html"))',
    # Mit __dirname Varianten
    "res.sendFile(path.join(__dirname, 'public', 'index.html'))",
    'res.sendFile(path.join(__dirname, "public", "index.html"))'
)

$fixedLine = "res.sendFile(path.join('$R3ChatLegs', 'public', 'index.html'))"

foreach ($v in $variants) {
    if ($content.Contains($v)) {
        $content = $content.Replace($v, $fixedLine)
        $changed = $true
        Write-Host "Fixed sendFile: $v" -ForegroundColor Green
        # Kein break — mehrfache Vorkommen patchen
    }
}

if (-not $changed) {
    Write-Host "WARN: Kein Standard-sendFile Pattern gefunden." -ForegroundColor Yellow
    Write-Host "Aktuelle sendFile-Zeilen in server.js:" -ForegroundColor Cyan
    $lines = $content -split "`n"
    $i = 0
    foreach ($line in $lines) {
        $i++
        if ($line -match 'sendFile') {
            Write-Host "  L$($i): $($line.Trim())" -ForegroundColor White
        }
    }
    Write-Host ""
    Write-Host "Manuell patchen — ersetze die sendFile-Zeile mit:" -ForegroundColor Yellow
    Write-Host "  $fixedLine" -ForegroundColor White
    exit 0
}

# Schreiben (LF beibehalten)
[System.IO.File]::WriteAllText($serverPath, $content, (New-Object System.Text.UTF8Encoding $false))
Write-Host ""
Write-Host "DONE Fix-SPA-SendFile — Server neu starten:" -ForegroundColor Green
Write-Host "  Stop-Process -Id (Get-NetTCPConnection -LocalPort 8420).OwningProcess -Force -ErrorAction SilentlyContinue" -ForegroundColor Gray
Write-Host "  Start-Sleep 1" -ForegroundColor Gray
Write-Host "  node C:\Users\mail\R3-DASHBOARD\SOURCE\chat-legs\server.js" -ForegroundColor Gray
Write-Host ""
Write-Host "Test nach Restart:" -ForegroundColor Cyan
Write-Host "  Invoke-RestMethod http://localhost:8420/health" -ForegroundColor Gray
