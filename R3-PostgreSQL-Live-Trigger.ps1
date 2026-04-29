# R3-PostgreSQL-Live-Trigger.ps1
# Macht die r3_ssot Datenbank LIVE und NUTZBAR
# Ausführen: auf RAZER — einmalig Setup + dauerhafter Betrieb
# Erstellt: 2026-04-30

Write-Host "`n=== R3 POSTGRESQL LIVE-TRIGGER ===" -ForegroundColor Cyan

$APPSEN_IP   = "192.168.1.226"
$DB_USER     = "admin"
$DB_NAME     = "r3_ssot"
$SSH_KEY     = "$env:USERPROFILE\.ssh\r3_appsen"
$DOCKER_CTX  = "appsen"

function Invoke-R3SQL {
    param([string]$sql)
    docker --context $DOCKER_CTX exec db psql -U $DB_USER -d $DB_NAME -c $sql
}

# --- SCHRITT 1: DB-Daten korrigieren ---
Write-Host "`n[1/5] Devices-Tabelle korrigieren..." -ForegroundColor Yellow

Invoke-R3SQL @"
UPDATE devices SET 
    os = 'Windows 11',
    hostname = 'APPSEN-WIN'
WHERE device_key = 'APPSEN';

UPDATE devices SET 
    is_online = true,
    last_seen = NOW()
WHERE device_key IN ('RAZER', 'APPSEN');

SELECT device_key, hostname, ip_static, os, is_online, last_seen FROM devices;
"@
Write-Host "✅ Devices korrigiert" -ForegroundColor Green

# --- SCHRITT 2: updated_at Trigger erstellen ---
Write-Host "`n[2/5] Auto-Timestamp Trigger anlegen..." -ForegroundColor Yellow

Invoke-R3SQL @"
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS `$`$
BEGIN
  NEW.last_seen = NOW();
  RETURN NEW;
END;
`$`$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_devices_updated ON devices;

CREATE TRIGGER trg_devices_updated
  BEFORE UPDATE ON devices
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

SELECT 'Trigger aktiv' as status;
"@
Write-Host "✅ Trigger 'trg_devices_updated' aktiv" -ForegroundColor Green

# --- SCHRITT 3: PostgREST Health-Check ---
Write-Host "`n[3/5] PostgREST API prüfen..." -ForegroundColor Yellow
try {
    $resp = Invoke-RestMethod -Uri "http://${APPSEN_IP}:3001/devices" -Method GET -TimeoutSec 5
    Write-Host "✅ PostgREST antwortet — $(($resp | Measure-Object).Count) Devices über API abrufbar" -ForegroundColor Green
    $resp | Select-Object device_key, hostname, is_online | Format-Table
} catch {
    Write-Host "❌ PostgREST nicht erreichbar: $_" -ForegroundColor Red
    Write-Host "   Container prüfen: docker --context appsen logs r3-postgrest" -ForegroundColor Gray
}

# --- SCHRITT 4: Heartbeat-Funktion in DB registrieren ---
Write-Host "`n[4/5] Heartbeat-Prozedur in DB anlegen..." -ForegroundColor Yellow

Invoke-R3SQL @"
CREATE OR REPLACE FUNCTION heartbeat(p_device_key TEXT, p_ip TEXT DEFAULT NULL)
RETURNS TEXT AS `$`$
BEGIN
  UPDATE devices
  SET 
    is_online = true,
    last_seen = NOW(),
    ip_dynamic = COALESCE(p_ip, ip_dynamic)
  WHERE device_key = p_device_key;
  
  IF NOT FOUND THEN
    RETURN 'DEVICE_NOT_FOUND: ' || p_device_key;
  END IF;
  
  RETURN 'OK: ' || p_device_key || ' @ ' || NOW()::TEXT;
END;
`$`$ LANGUAGE plpgsql;

SELECT heartbeat('RAZER', '192.168.1.30') as razer_hb;
SELECT heartbeat('APPSEN', '192.168.1.226') as appsen_hb;
"@
Write-Host "✅ Heartbeat-Funktion aktiv" -ForegroundColor Green

# --- SCHRITT 5: Windows Task Scheduler — Heartbeat alle 5 min ---
Write-Host "`n[5/5] Windows Task Scheduler — Heartbeat RAZER alle 5 min..." -ForegroundColor Yellow

$taskName   = "R3-Heartbeat-RAZER"
$scriptPath = "$env:USERPROFILE\R3-Heartbeat.ps1"

# Heartbeat-Script erstellen
@"
# R3-Heartbeat.ps1 — automatisch generiert
`$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { `$_.IPAddress -like '192.168.*' } | Select-Object -First 1).IPAddress
docker --context appsen exec db psql -U admin -d r3_ssot -c `"SELECT heartbeat('RAZER', '`$ip');`"
"@ | Set-Content $scriptPath

# Task registrieren
$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NonInteractive -WindowStyle Hidden -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 1) -StartWhenAvailable

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force | Out-Null
Write-Host "✅ Task '$taskName' aktiv — Heartbeat alle 5 min" -ForegroundColor Green

# --- ABSCHLUSS ---
Write-Host "`n=== POSTGRESQL LIVE — FERTIG ===" -ForegroundColor Cyan
Write-Host @"

Nützliche Befehle:
  r3db -c "SELECT * FROM devices;"          # Alle Devices
  r3db -c "SELECT heartbeat('RAZER');"      # Manueller Heartbeat
  curl http://192.168.1.226:3001/devices    # PostgREST API
  docker --context appsen logs r3-postgrest # PostgREST Logs

"@ -ForegroundColor Gray
