# R3-Drive-Inject-APPSEN.ps1
# Zieht .env von Drive und injiziert direkt in laufende Docker Container auf APPSEN
# 2026-04-30

param(
    [string]$EnvFile    = ".env",
    [string]$Container  = "db",
    [switch]$DryRun
)

$SECRETS_DIR = "$env:USERPROFILE\.r3\secrets"
$ENV_PATH    = Join-Path $SECRETS_DIR $EnvFile

Write-Host "`n=== R3 DRIVE → DOCKER INJECT ===" -ForegroundColor Cyan

# 1. Secrets von Drive holen
Write-Host "[1/3] Drive Secrets abrufen..." -ForegroundColor Yellow
& "$PSScriptRoot\R3-Drive-Secrets.ps1" -FolderMode aktuell -FileName $EnvFile

if (!(Test-Path $ENV_PATH)) {
    Write-Host "❌ .env nicht gefunden: $ENV_PATH" -ForegroundColor Red
    exit 1
}

# 2. Variablen parsen
$vars = @{}
Get-Content $ENV_PATH | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $vars[$matches[1].Trim()] = $matches[2].Trim().Trim('"')
    }
}

Write-Host "✅ $($vars.Count) Variablen aus $EnvFile geladen" -ForegroundColor Green

# 3. In Container setzen
Write-Host "`n[2/3] In Container '$Container' injizieren..." -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "[DRY RUN] Würde setzen:" -ForegroundColor Magenta
    $vars.Keys | ForEach-Object { Write-Host "  $_ = $($vars[$_].Substring(0, [Math]::Min(8, $vars[$_].Length)))..." }
} else {
    foreach ($kv in $vars.GetEnumerator()) {
        $cmd = "export $($kv.Key)='$($kv.Value)'"
        docker --context appsen exec $Container bash -c $cmd 2>$null
    }
    Write-Host "✅ Injiziert in Container '$Container'" -ForegroundColor Green
}

# 4. PostgreSQL-spezifisch: DB-Variablen direkt prüfen
Write-Host "`n[3/3] Verify..." -ForegroundColor Yellow
docker --context appsen exec db psql -U admin -d r3_ssot -c "SELECT current_database(), current_user, NOW();"
Write-Host "✅ DB-Verbindung bestätigt"
