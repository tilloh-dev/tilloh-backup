#!/usr/bin/env bash

set -euo pipefail

: "${HOME:?HOME must be set and non-empty}"

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SOURCE_DIR="$SCRIPT_DIR/.claude"
TARGET_DIR="$HOME/.claude"

if [[ ! -d "$SOURCE_DIR/skills" ]]; then
  printf "Skills source not found: %s\n" "$SOURCE_DIR/skills" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

if [[ -f "$SOURCE_DIR/settings.local.json" ]]; then
  printf "Copying settings.local.json to %s...\n" "$TARGET_DIR"
  cp "$SOURCE_DIR/settings.local.json" "$TARGET_DIR/settings.local.json"
  chmod 600 "$TARGET_DIR/settings.local.json"
else
  printf "Skipping settings.local.json (local file not present).\n"
fi

printf "Copying skills to %s/skills...\n" "$TARGET_DIR"
mkdir -p "$TARGET_DIR/skills"
cp -R "$SOURCE_DIR/skills/." "$TARGET_DIR/skills/"

if [[ -d "$SOURCE_DIR/hooks" ]]; then
  printf "Copying hooks to %s/hooks...\n" "$TARGET_DIR"
  mkdir -p "$TARGET_DIR/hooks"
  cp -R "$SOURCE_DIR/hooks/." "$TARGET_DIR/hooks/"
  chmod +x "$TARGET_DIR"/hooks/*.sh 2>/dev/null || true
fi

printf "Installation complete! Claude configuration updated successfully.\n"
printf "Hooks are copied but not registered: see claude-backup/hooks.md for the settings.json snippet.\n"
