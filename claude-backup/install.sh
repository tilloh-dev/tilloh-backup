#!/bin/bash

TARGET_DIR="$HOME/.claude"

printf "Copying settings.local.json to %s...\n" "$TARGET_DIR"
cp .claude/settings.local.json "$TARGET_DIR/settings.local.json"

printf "Copying skills to %s/skills...\n" "$TARGET_DIR"
mkdir -p "$TARGET_DIR/skills"
cp -r .claude/skills/. "$TARGET_DIR/skills/"

printf "Installation complete! Claude configuration updated successfully.\n"
