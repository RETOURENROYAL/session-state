# R3-Barrier-Free-Setup.ps1
# Barrierefreies Arbeiten — EINMALIG ausführen auf RAZER
# Erstellt: 2026-04-30
# Zweck: Alle Zugänge ohne Passwort-Theater sofort verfügbar

Write-Host "`n=== R3 BARRIER-FREE SETUP ===" -ForegroundColor Cyan
Write-Host "Richtet alle Kurzwege für RAZER → APPSEN ein.`n"

# --- 1. SSH-Agent sicherstellen ---
Write-Host "[1/5] SSH-Agent starten..." -ForegroundColor Yellow
Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent
ssh-add "$env:USERPROFILE\.ssh\r3_appsen"
Write-Host "✅ SSH-Key geladen" -ForegroundColor Green

# --- 2. Docker Context setzen ---
Write-Host "`n[2/5] Docker Context 'appsen' setzen..." -ForegroundColor Yellow
docker context rm appsen 2>$null
docker context create appsen --docker "host=ssh://retouren-royal@192.168.1.226" --description "APPSEN R3-Server"
docker context use appsen
Write-Host "✅ Docker Context 'appsen' aktiv" -ForegroundColor Green

# --- 3. PowerShell Profile — Aliase dauerhaft ---
Write-Host "`n[3/5] PowerShell Aliase ins Profil schreiben..." -ForegroundColor Yellow
$profileDir = Split-Path $PROFILE
if (!(Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }

$aliases = @"

# === R3 BARRIER-FREE ALIASES ===
function appsen { ssh -i `"`$env:USERPROFILE\.ssh\r3_appsen`" retouren-royal@192.168.1.226 @args }
function r3db { docker --context appsen exec db psql -U admin -d r3_ssot @args }
function r3ps { docker --context appsen ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" }
function r3logs { param(`$name) docker --context appsen logs --tail 50 -f `$name }
Set-Alias dca 'docker --context appsen'
`$env:DOCKER_HOST = "ssh://retouren-royal@192.168.1.226"
"@

Add-Content -Path $PROFILE -Value $aliases
Write-Host "✅ Aliase ins PowerShell-Profil geschrieben" -ForegroundColor Green

# --- 4. Windows-Umgebungsvariablen dauerhaft ---
Write-Host "`n[4/5] Umgebungsvariablen setzen..." -ForegroundColor Yellow
[System.Environment]::SetEnvironmentVariable("GIT_SSH", "$env:WINDIR\System32\OpenSSH\ssh.exe", "User")
[System.Environment]::SetEnvironmentVariable("DOCKER_APPSEN", "ssh://retouren-royal@192.168.1.226", "User")
Write-Host "✅ Env-Variablen gesetzt" -ForegroundColor Green

# --- 5. Soforttest ---
Write-Host "`n[5/5] Verbindungstest..." -ForegroundColor Yellow
$sshTest = ssh -i "$env:USERPROFILE\.ssh\r3_appsen" retouren-royal@192.168.1.226 "echo SSH_OK"
$dockerTest = docker --context appsen ps --format "{{.Names}}" 2>&1

if ($sshTest -eq "SSH_OK") {
    Write-Host "✅ SSH passwordless: OK" -ForegroundColor Green
} else {
    Write-Host "❌ SSH Test fehlgeschlagen!" -ForegroundColor Red
}

if ($dockerTest -notmatch "error") {
    Write-Host "✅ Docker Context APPSEN: OK" -ForegroundColor Green
    Write-Host "`nAktive Container:" -ForegroundColor Cyan
    docker --context appsen ps --format "table {{.Names}}`t{{.Status}}"
} else {
    Write-Host "❌ Docker Context fehlgeschlagen: $dockerTest" -ForegroundColor Red
}

Write-Host "`n=== SETUP ABGESCHLOSSEN ==="  -ForegroundColor Cyan
Write-Host "Neue Session öffnen oder '. `$PROFILE' ausführen.`n"
