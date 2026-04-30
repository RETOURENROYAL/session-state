# R3-Drive-Secrets.ps1
# Google Drive → .env abrufen → in Stack injizieren
# Ausführen: auf RAZER oder APPSEN
# 2026-04-30

param(
    [string]$FolderMode = "aktuell",  # "aktuell" oder "archiv"
    [string]$FileName   = "",          # leer = alle .env Dateien listen
    [switch]$Inject,                   # $true = direkt in Umgebung laden
    [switch]$List                      # nur auflisten, nicht herunterladen
)

# === KONFIGURATION ===
$KEY_PATH    = "$env:USERPROFILE\.r3\gdrive-service-account.json"
$FOLDER_IDS  = @{
    aktuell = "1sZWT6d5AZgOnOR-_9ZF8Y2sNeid1kGQa"
    archiv  = "188gXvT5agPG-CWxN0E1ZMKf7Nkh0S5P8"
}
$OUT_DIR     = "$env:USERPROFILE\.r3\secrets"
$SCOPE       = "https://www.googleapis.com/auth/drive.readonly"

# === JWT ACCESS TOKEN (Service Account) ===
function Get-GDriveToken {
    $key = Get-Content $KEY_PATH -Raw | ConvertFrom-Json
    
    $now     = [int][double]::Parse((Get-Date -UFormat %s))
    $exp     = $now + 3600
    
    $header  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"alg":"RS256","typ":"JWT"}')) -replace '=',''
    $claims  = @{
        iss   = $key.client_email
        scope = $SCOPE
        aud   = "https://oauth2.googleapis.com/token"
        iat   = $now
        exp   = $exp
    } | ConvertTo-Json -Compress
    $claimsB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($claims)) -replace '=',''
    
    $unsigned  = "$header.$claimsB64"
    
    # RSA-SHA256 signieren mit privatem Key
    $rsa = [System.Security.Cryptography.RSA]::Create()
    $pemKey = $key.private_key -replace '-----BEGIN PRIVATE KEY-----','' -replace '-----END PRIVATE KEY-----','' -replace '\n',''
    $rsa.ImportPkcs8PrivateKey([Convert]::FromBase64String($pemKey), [ref]$null)
    
    $sigBytes  = $rsa.SignData([Text.Encoding]::UTF8.GetBytes($unsigned), [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $sig       = [Convert]::ToBase64String($sigBytes) -replace '=',''
    
    $jwt = "$unsigned.$sig"
    
    $body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$jwt"
    $resp = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
    return $resp.access_token
}

# === DRIVE: Dateien in Ordner listen ===
function Get-DriveFiles {
    param([string]$token, [string]$folderId)
    $uri = "https://www.googleapis.com/drive/v3/files?q='$folderId'+in+parents+and+trashed=false&fields=files(id,name,modifiedTime,size)&orderBy=modifiedTime+desc"
    $resp = Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $token" }
    return $resp.files
}

# === DRIVE: Datei herunterladen ===
function Get-DriveFile {
    param([string]$token, [string]$fileId, [string]$outPath)
    $uri = "https://www.googleapis.com/drive/v3/files/${fileId}?alt=media"
    Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $token" } -OutFile $outPath
}

# === .env parsen und als Hashtable zurückgeben ===
function Parse-EnvFile {
    param([string]$path)
    $vars = @{}
    Get-Content $path | ForEach-Object {
        $line = $_.Trim()
        if ($line -and !$line.StartsWith('#') -and $line -match '^([^=]+)=(.*)$') {
            $vars[$matches[1].Trim()] = $matches[2].Trim().Trim('"').Trim("'")
        }
    }
    return $vars
}

# === MAIN ===
Write-Host "`n=== R3 DRIVE SECRETS CONNECTOR ===" -ForegroundColor Cyan
Write-Host "Modus: $FolderMode | Ordner-ID: $($FOLDER_IDS[$FolderMode])`n"

if (!(Test-Path $KEY_PATH)) {
    Write-Host "❌ Service Account Key nicht gefunden: $KEY_PATH" -ForegroundColor Red
    Write-Host "   Zuerst R3-Drive-Auth-Setup.ps1 ausführen!" -ForegroundColor Gray
    exit 1
}

if (!(Test-Path $OUT_DIR)) { New-Item -ItemType Directory -Path $OUT_DIR -Force | Out-Null }

Write-Host "[1/3] Authentifizierung..." -ForegroundColor Yellow
$token = Get-GDriveToken
Write-Host "✅ Access Token erhalten" -ForegroundColor Green

Write-Host "`n[2/3] Dateien abrufen..." -ForegroundColor Yellow
$files = Get-DriveFiles -token $token -folderId $FOLDER_IDS[$FolderMode]

if (!$files -or $files.Count -eq 0) {
    Write-Host "❌ Keine Dateien gefunden (Ordner leer oder kein Zugriff)" -ForegroundColor Red
    exit 1
}

Write-Host "`nVearfügbare Dateien in '$FolderMode':" -ForegroundColor Cyan
$files | ForEach-Object {
    Write-Host "  [$($_.id.Substring(0,8))...] $($_.name) — $($_.modifiedTime)" -ForegroundColor White
}

if ($List) { exit 0 }

Write-Host "`n[3/3] Download + Verarbeitung..." -ForegroundColor Yellow

$targets = if ($FileName) {
    $files | Where-Object { $_.name -eq $FileName }
} else {
    $files
}

$allSecrets = @{}

foreach ($f in $targets) {
    $outPath = Join-Path $OUT_DIR $f.name
    Get-DriveFile -token $token -fileId $f.id -outPath $outPath
    Write-Host "✅ Heruntergeladen: $($f.name)" -ForegroundColor Green
    
    if ($f.name -match '\.env') {
        $vars = Parse-EnvFile -path $outPath
        $allSecrets += $vars
        Write-Host "   $($vars.Count) Variablen geladen" -ForegroundColor Gray
    }
}

# === In aktuelle Session injizieren ===
if ($Inject -and $allSecrets.Count -gt 0) {
    Write-Host "`nInjiziere in Session..." -ForegroundColor Yellow
    foreach ($kv in $allSecrets.GetEnumerator()) {
        [System.Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, "Process")
        Set-Item -Path "env:$($kv.Key)" -Value $kv.Value
    }
    Write-Host "✅ $($allSecrets.Count) Secrets in Session aktiv" -ForegroundColor Green
}

# === Summary ausgeben ===
Write-Host "`n=== SUMMARY ==="  -ForegroundColor Cyan
Write-Host "Gespeichert in: $OUT_DIR" -ForegroundColor Gray
$allSecrets.Keys | Sort-Object | ForEach-Object {
    $val = $allSecrets[$_]
    $masked = if ($val.Length -gt 6) { $val.Substring(0,4) + ('*' * ($val.Length - 4)) } else { '****' }
    Write-Host "  $_ = $masked"
}

Write-Host ""
