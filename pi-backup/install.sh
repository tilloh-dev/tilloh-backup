#!/usr/bin/env bash
set -euo pipefail

PI_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$PI_DIR"

# settings.json
if [ -f "$BACKUP_DIR/settings.json" ]; then
  cp -f "$BACKUP_DIR/settings.json" "$PI_DIR/settings.json"
  echo "Installed settings.json -> $PI_DIR/settings.json"
fi

# auth.json
if [ -f "$BACKUP_DIR/auth.json" ]; then
  cp -f "$BACKUP_DIR/auth.json" "$PI_DIR/auth.json"
  echo "Installed auth.json -> $PI_DIR/auth.json"
fi

# models.json - custom provider overrides
if [ -f "$BACKUP_DIR/models.json" ]; then
  cp -f "$BACKUP_DIR/models.json" "$PI_DIR/models.json"
  echo "Installed models.json -> $PI_DIR/models.json"
fi

echo "Pi Coding Agent backup installed."
