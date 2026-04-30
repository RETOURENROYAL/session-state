# R3-Drive-Auth-Setup.ps1
# EINMALIG ausführen — erstellt Google Service Account + Credentials
# Voraussetzung: gcloud CLI installiert ODER manuell via Google Cloud Console

Write-Host "`n=== R3 GOOGLE DRIVE AUTH SETUP ===" -ForegroundColor Cyan
Write-Host "Dieser Schritt ist EINMALIG.`n"

# --- OPTION A: Manuell (empfohlen, kein gcloud nötig) ---
Write-Host @"
[MANUELL — einmalig in Google Cloud Console]

1. https://console.cloud.google.com aufrufen
2. Projekt erstellen: 'r3-secrets-connector'
3. APIs aktivieren:
   Navigation: APIs & Services > Library
   Suchen + aktivieren: 'Google Drive API'

4. Service Account erstellen:
   Navigation: APIs & Services > Credentials
   > + CREATE CREDENTIALS > Service Account
   Name: r3-drive-reader
   Role: Viewer
   > DONE

5. JSON-Key herunterladen:
   Service Account anklicken > Keys > ADD KEY > JSON
   Speichern als: C:\Users\mail\.r3\gdrive-service-account.json

6. Drive-Ordner freigeben:
   Drive-Ordner ".env-aktuell" öffnen
   > Teilen > E-Mail des Service Accounts einfügen
   (Format: r3-drive-reader@r3-secrets-connector.iam.gserviceaccount.com)
   > Rolle: Leser > Fertig
   Dasselbe für ".env-Archiv"

"@ -ForegroundColor White

# --- Zielordner erstellen ---
$credDir = "$env:USERPROFILE\.r3"
if (!(Test-Path $credDir)) {
    New-Item -ItemType Directory -Path $credDir -Force | Out-Null
    Write-Host "✅ Ordner '$credDir' erstellt" -ForegroundColor Green
}

# --- Prüfen ob Key schon da ---
$keyPath = "$credDir\gdrive-service-account.json"
if (Test-Path $keyPath) {
    Write-Host "✅ Service Account Key gefunden: $keyPath" -ForegroundColor Green
    $key = Get-Content $keyPath | ConvertFrom-Json
    Write-Host "   Account: $($key.client_email)" -ForegroundColor Gray
} else {
    Write-Host "⚠️ Key noch nicht gefunden." -ForegroundColor Yellow
    Write-Host "   Bitte JSON nach '$keyPath' ablegen, dann erneut ausführen." -ForegroundColor Gray
}

Write-Host "`nWeiter mit: R3-Drive-Secrets.ps1`n"
