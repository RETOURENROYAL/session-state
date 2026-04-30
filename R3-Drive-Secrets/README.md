# R3 Google Drive — Secret Connector
> Stand: 2026-04-30 | Smarter als Google Drive Desktop

## Architektur

```
Google Drive (Ordner: .env-aktuell)
         ↓ (Google Drive API v3)
  R3-Drive-Secrets.ps1
         ↓ (parsed .env)
  Docker Compose / n8n Credentials
         ↓
  APPSEN Stack (live)
```

## Vorteile vs. Google Drive Desktop
| | Drive Desktop | Dieser Connector |
|---|---|---|
| Lokaler Sync-Daemon | ❌ ja | ✅ nein |
| Automatisierbar | ⚠️ schwer | ✅ vollständig |
| On-Demand-Abruf | ❌ nein | ✅ ja |
| n8n-Integration | ❌ manuell | ✅ nativ |
| Service Account | ❌ nein | ✅ ja |

## Setup (einmalig)

1. `R3-Drive-Auth-Setup.ps1` ausführen → Service Account erstellen
2. Ordner-IDs aus deinen Drive-Links eintragen (s.u.)
3. `R3-Drive-Secrets.ps1` bei Bedarf ausführen oder als Scheduled Task

## Ordner-IDs

```
.env-Archiv:  188gXvT5agPG-CWxN0E1ZMKf7Nkh0S5P8
.env-aktuell: 1sZWT6d5AZgOnOR-_9ZF8Y2sNeid1kGQa
```
