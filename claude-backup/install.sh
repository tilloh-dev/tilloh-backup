#!/usr/bin/env bash
# Claude Code personal-config installer (add-only).
#
# Copies skills and hook scripts from this backup into ~/.claude/ without removing
# anything already there. Files this script owns are overwritten in place; skills
# and hooks from other sources (team installers, claude.ai sync) are kept.
# ~/.claude/settings.json is never touched - hook registration is a manual merge
# from hooks.md, because that file also carries the team command guard.

set -euo pipefail
: "${HOME:?HOME must be set and non-empty}"

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SOURCE_DIR="$SCRIPT_DIR/.claude"
TARGET_DIR="$HOME/.claude"

# ── styling (only when stdout is a terminal) ─────────────────────────────────
if [[ -t 1 ]] && command -v tput >/dev/null && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
  B=$(tput bold) D=$(tput dim) G=$(tput setaf 2) Y=$(tput setaf 3) C=$(tput setaf 6) R=$(tput sgr0)
else
  B="" D="" G="" Y="" C="" R=""
fi
h()    { printf '\n%s%s%s\n' "$B" "$1" "$R"; }
tilde(){ printf '%s' "${1/#$HOME/\~}"; }   # print a path with ~ for $HOME
ok()   { printf '  %s✔%s %s\n' "$G" "$R" "$1"; }
warn() { printf '  %s!%s %s\n' "$Y" "$R" "$1"; }
kv()   { printf '  %s✔%s %-26s %s%s%s\n' "$G" "$R" "$1" "$D" "$2" "$R"; }
die()  { printf '  %s✖%s %s\n' "$Y" "$R" "$1" >&2; exit 1; }

printf '%s%sClaude Code config install%s  %s%s → %s%s\n' "$B" "$C" "$R" "$D" "$(tilde "$SCRIPT_DIR")" "$(tilde "$TARGET_DIR")" "$R"

[[ -d "$SOURCE_DIR/skills" ]] || die "skills source not found: $SOURCE_DIR/skills"
mkdir -p "$TARGET_DIR"

# ── settings ─────────────────────────────────────────────────────────────────
h "Settings"
if [[ -f "$SOURCE_DIR/settings.local.json" ]]; then
  cp "$SOURCE_DIR/settings.local.json" "$TARGET_DIR/settings.local.json"
  chmod 600 "$TARGET_DIR/settings.local.json"
  kv "settings.local.json" "copied, mode 0600"
else
  warn "settings.local.json  ${D}not in this checkout (gitignored) - skipped${R}"
fi

# ── skills ───────────────────────────────────────────────────────────────────
h "Skills  ${D}→ $(tilde "$TARGET_DIR")/skills (existing skills kept)${R}"
mkdir -p "$TARGET_DIR/skills"
shopt -s nullglob
for skill_dir in "$SOURCE_DIR"/skills/*/; do
  name=$(basename "$skill_dir")
  if [[ -d "$TARGET_DIR/skills/$name" ]]; then state="updated"; else state="new"; fi
  mkdir -p "$TARGET_DIR/skills/$name"
  cp -R "$skill_dir." "$TARGET_DIR/skills/$name/"
  kv "$name" "$state"
done

# ── hooks ────────────────────────────────────────────────────────────────────
if [[ -d "$SOURCE_DIR/hooks" ]]; then
  h "Hooks  ${D}→ $(tilde "$TARGET_DIR")/hooks${R}"
  mkdir -p "$TARGET_DIR/hooks"
  for f in "$SOURCE_DIR"/hooks/*; do
    [[ -f "$f" ]] || continue
    cp "$f" "$TARGET_DIR/hooks/"
    [[ "$f" == *.sh ]] && chmod +x "$TARGET_DIR/hooks/$(basename "$f")"
    kv "$(basename "$f")" "copied"
  done
  warn "not registered  ${D}merge the snippet from claude-backup/hooks.md into ~/.claude/settings.json${R}"
fi
shopt -u nullglob

printf '\n%sDone.%s %sSkills and hooks are live in new sessions; open %s/hooks%s once if a hook was registered just now.%s\n' \
  "$B" "$R" "$D" "$R$C" "$R$D" "$R"
