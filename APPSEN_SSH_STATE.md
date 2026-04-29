# APPSEN — SSH & Docker Context State
> Stand: 2026-04-30 | Version: WAHR-only

---

## ✅ SSH Passwordless RAZER → APPSEN

| Feld | Wert |
|---|---|
| Key-Name | `r3_appsen` (ed25519) |
| Key-Pfad RAZER | `$env:USERPROFILE\.ssh\r3_appsen` |
| Public Key | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMAu/FiHYCn3rFrripzYIJm9Mi6a6p3UTisRgUXQ4fam RAZER` |
| Ziel-Datei APPSEN | `C:\ProgramData\ssh\administrators_authorized_keys` |
| Root-Ursache Fix | `Match Group administrators` Block in `sshd_config` war auskommentiert |
| icacls Gruppe | `Administratoren` (deutsch, nicht `Administrators`) |
| Status | ✅ AKTIV — kein Passwort mehr |

### sshd_config relevante Zeilen (APPSEN)
```
PubkeyAuthentication yes
AuthorizedKeysFile      .ssh/authorized_keys
Match Group administrators
      AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

---

## ✅ Docker Context APPSEN

```powershell
# Korrekter Context (mit IP, NICHT Hostname):
docker context create appsen --docker "host=ssh://retouren-royal@192.168.1.226"

# Verwendung:
docker --context appsen ps
docker --context appsen exec db psql -U admin -d r3_ssot -c "SELECT * FROM devices;"
```

| Feld | Wert |
|---|---|
| Context-Name | `appsen` |
| SSH-URL | `ssh://retouren-royal@192.168.1.226` |
| Passwort nötig | ❌ NEIN |
| Fehler mit Hostname | `ssh://appsen` fragt noch Passwort — immer IP nutzen |

---

## 🐳 Aktive Container auf APPSEN

| Name | Image | Ports | Uptime |
|---|---|---|---|
| `db` | postgres:16 | 5432 | 4 Wochen |
| `r3-postgrest` | postgrest/postgrest:v12.0.2 | 3001→3000 | stabil |
| `r3-llama-factory` | hiyouga/llamafactory | 7860 | 3 Wochen |
| `portainer` | portainer/portainer-ce | 9000, 9443 | 4 Wochen |
| `hbbs` | rustdesk/rustdesk-server | 21115-21116, 21118 | 4 Wochen |
| `hbbr` | rustdesk/rustdesk-server | 21117, 21119 | 4 Wochen |

---

## 🗄️ PostgreSQL — r3_ssot Datenbank

| Feld | Wert |
|---|---|
| Host | `192.168.1.226` |
| Port | `5432` |
| DB | `r3_ssot` |
| User | `admin` |
| Container | `db` |

### Tabelle: devices (bestätigt)
```sql
id | device_key | hostname | ip_static | ip_dynamic | os | is_online | services | last_seen | created_at
```

### Einträge (Stand Session)
| id | device_key | ip_static | os | is_online |
|---|---|---|---|---|
| 1 | RAZER | 192.168.1.30 | Windows 11 | false ← TODO |
| 2 | APPSEN | 192.168.1.226 | Ubuntu ← FALSCH, ist Windows 11 | false ← TODO |
| 3 | TAB | 192.168.1.68 | Android | false ← TODO |

---

## 🌐 Netzwerk-Topologie (WAHR)

```
STARLINK GATEWAY (192.168.1.1)
  ├── LAN Port 1 → APPSEN (192.168.1.226)
  ├── LAN Port 2 → FritzBox 6591 (192.168.1.10)
  └── WLAN → RAZER (192.168.1.30), TAB (192.168.1.68)

FRITZBOX 6591 (192.168.1.10)
  └── LAN → FritzBox 7272 (IP: TODO)
```

---

## ✅ TODO-Liste (offen)

- [ ] `devices` Tabelle: APPSEN OS auf `Windows 11` korrigieren
- [ ] `is_online` für alle Devices auf `true` setzen
- [ ] Heartbeat-Script aktivieren (siehe `R3-Heartbeat-APPSEN.ps1`)
- [ ] FritzBox 7272 IP eintragen
- [ ] Tab A8 IP eintragen
- [ ] Pixel 7 Pro ADB-Status prüfen
