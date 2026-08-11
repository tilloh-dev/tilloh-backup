# Pi Coding Agent Backup

Backup für Pi Coding Agent Konfiguration, analog zu `opencode-backup`.

## Dateien

* `settings.json` – globale Pi-Einstellungen
* `auth.json` – Provider-Auth, gitignored im Live-System
* `models.json` – Custom Provider Overrides, z.B. OpenRouter ausblenden

## Installieren

```bash
cd "/home/tilloh/Code/ privat/tooling/pi-backup"
bash install.sh
```

Zielverzeichnis: `~/.pi/agent` bzw. `$PI_CODING_AGENT_DIR`
