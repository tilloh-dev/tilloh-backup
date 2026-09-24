#!/bin/bash
# OpenCode personal-config installer (add-only).
#
# Copies this backup's personal opencode.jsonc, AGENTS.md, agents/ and skills/
# into ~/.config/opencode/ WITHOUT removing anything already there. Other sources
# (e.g. the C4 team installer) install their own agents/skills/plugins alongside
# these - this script must never wipe them. Files this script owns are overwritten
# in place; the git history of this repo is the backup.
#
# No plugins here on purpose. The bash guard lives in stadtwerk_ai_config
# (.opencode/plugin/command-guard.js) and is installed by its own
# install-opencode.sh into the same ~/.config/opencode/plugin/. Shipping a second
# copy from here would run two guards side by side.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.config/opencode"

# ── styling (only when stdout is a terminal) ─────────────────────────────────
if [[ -t 1 ]] && command -v tput >/dev/null && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
  B=$(tput bold) D=$(tput dim) G=$(tput setaf 2) Y=$(tput setaf 3) C=$(tput setaf 6) R=$(tput sgr0)
else
  B="" D="" G="" Y="" C="" R=""
fi
h()    { printf '\n%s%s%s\n' "$B" "$1" "$R"; }
tilde(){ printf '%s' "${1/#$HOME/\~}"; }   # print a path with ~ for $HOME
warn() { printf '  %s!%s %s\n' "$Y" "$R" "$1"; }
kv()   { printf '  %s✔%s %-26s %s%s%s\n' "$G" "$R" "$1" "$D" "$2" "$R"; }

# copy one file, report new/updated
install_file() { # src dst label
  local state="new"
  [[ -f "$2" ]] && state="updated"
  mkdir -p "$(dirname "$2")"
  cp "$1" "$2"
  kv "$3" "$state"
}

printf '%s%sOpenCode config install%s  %s%s → %s%s\n' "$B" "$C" "$R" "$D" "$(tilde "$SCRIPT_DIR")" "$(tilde "$TARGET_DIR")" "$R"
mkdir -p "$TARGET_DIR"

# ── config + global rules ────────────────────────────────────────────────────
h "Config"
install_file "$SCRIPT_DIR/opencode.jsonc" "$TARGET_DIR/opencode.jsonc" "opencode.jsonc"
if [[ -f "$SCRIPT_DIR/AGENTS.md" ]]; then
  install_file "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md" "AGENTS.md"
else
  warn "AGENTS.md  ${D}not in this checkout - skipped${R}"
fi

shopt -s nullglob

# ── agents ───────────────────────────────────────────────────────────────────
agents=("$SCRIPT_DIR"/agents/*.md)
if (( ${#agents[@]} )); then
  h "Agents  ${D}→ $(tilde "$TARGET_DIR")/agents (existing agents kept)${R}"
  for f in "${agents[@]}"; do
    install_file "$f" "$TARGET_DIR/agents/$(basename "$f")" "$(basename "$f" .md)"
  done
fi

# ── skills ───────────────────────────────────────────────────────────────────
skills=("$SCRIPT_DIR"/skills/*/)
if (( ${#skills[@]} )); then
  h "Skills  ${D}→ $(tilde "$TARGET_DIR")/skills (existing skills kept)${R}"
  for skill_dir in "${skills[@]}"; do
    name="$(basename "$skill_dir")"
    if [[ -d "$TARGET_DIR/skills/$name" ]]; then state="updated"; else state="new"; fi
    # copy file-by-file so a same-named skill is updated, not wiped-and-replaced
    while IFS= read -r -d '' src; do
      rel="${src#"$skill_dir"}"
      mkdir -p "$(dirname "$TARGET_DIR/skills/$name/$rel")"
      cp "$src" "$TARGET_DIR/skills/$name/$rel"
    done < <(find "$skill_dir" -type f -print0)
    kv "$name" "$state"
  done
fi
shopt -u nullglob

printf '\n%sDone.%s %sadd-only: nothing outside these files was touched. The bash guard comes from stadtwerk_ai_config, not from here.%s\n' "$B" "$R" "$D" "$R"
