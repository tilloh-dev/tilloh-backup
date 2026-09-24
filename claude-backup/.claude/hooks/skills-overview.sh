#!/usr/bin/env bash
# SessionStart hook: one-screen overview of the skills available in this session.
#
# Prints a systemMessage (visible to the user only). Nothing goes into the model's
# context - Claude already receives the full skill listing from the harness.
# Fires on a fresh start and after /clear; stays silent on resume and compact so a
# long session is not interrupted by the same list again.
#
# Layout (kept deliberately small):
#   user skills     one line each: /name + first sentence of the description
#   project skills  same, from <cwd>/.claude/skills
#   synced          names only, one line (Anthropic-managed, ~/.claude/skills/synced)

set -euo pipefail

input=$(cat 2>/dev/null || true)
source=$(printf '%s' "$input" | jq -r '.source // "startup"' 2>/dev/null || echo startup)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
[[ -z "$cwd" ]] && cwd=$PWD

case "$source" in
  startup|clear) ;;
  *) exit 0 ;;
esac

DESC_MAX=${SKILLS_OVERVIEW_DESC_MAX:-64}

# frontmatter value for a key; strips surrounding quotes, joins YAML block
# scalars (">" / "|") into one line
fm_value() { # file key
  awk -v key="$2" '
    NR==1 && $0!="---" { exit }
    NR>1 && $0=="---" { exit }
    block { if ($0 ~ /^[ \t]/) { sub(/^[ \t]+/, ""); acc=acc (acc==""?"":" ") $0; next } else { print acc; exit } }
    index($0, key ":")==1 {
      v=substr($0, length(key)+2); sub(/^[ \t]+/, "", v)
      if (v ~ /^[>|][-+]?$/) { block=1; next }
      if (v ~ /^".*"$/ || v ~ /^'"'"'.*'"'"'$/) v=substr(v, 2, length(v)-2)
      gsub(/'"'"''"'"'/, "'"'"'", v)
      print v; exit
    }
    END { if (block && acc!="") print acc }' "$1"
}

# first clause (cut at ". " or ": "), truncated at a word boundary
short() { # text
  local t=$1
  t=${t%%. *}
  t=${t%%: *}
  t=${t%%.}
  if (( ${#t} > DESC_MAX )); then
    local hard=${t:0:DESC_MAX} soft
    soft=${hard% *}
    # prefer the word boundary, unless the dropped word is so long (a path, an
    # identifier) that the line would lose most of its meaning
    if (( ${#soft} >= DESC_MAX - 16 )); then t=$soft; else t=$hard; fi
    t=${t%%[,;:]}
    t+="…"
  fi
  printf '%s' "$t"
}

# section header: "── title ── … ──" padded to WIDTH
WIDTH=${SKILLS_OVERVIEW_WIDTH:-88}
header() { # title
  local title="── $1 " pad
  pad=$(( WIDTH - ${#title} ))
  (( pad < 4 )) && pad=4
  printf '%s%s\n' "$title" "$(printf '─%.0s' $(seq 1 $pad))"
}

list_dir() { # dir
  local d=$1 f name desc
  [[ -d "$d" ]] || return 0
  for f in "$d"/*/SKILL.md; do
    [[ -f "$f" ]] || continue
    name=$(fm_value "$f" name); [[ -n "$name" ]] || name=$(basename "$(dirname "$f")")
    desc=$(short "$(fm_value "$f" description)")
    printf '  /%-21s %s\n' "$name" "$desc"
  done
}

out=""
user_lines=$(list_dir "$HOME/.claude/skills")
[[ -n "$user_lines" ]] && out+=$'\n'"$(header "Skills · user  ~/.claude/skills")"$'\n'"$user_lines"$'\n'

proj_lines=$(list_dir "$cwd/.claude/skills")
[[ -n "$proj_lines" ]] && out+=$'\n'"$(header "Skills · projekt  .claude/skills")"$'\n'"$proj_lines"$'\n'

synced=""
for f in "$HOME"/.claude/skills/synced/*/*/SKILL.md; do
  [[ -f "$f" ]] || continue
  synced+="${synced:+ · }$(basename "$(dirname "$f")")"
done
[[ -n "$synced" ]] && out+=$'\n'"$(header "Anthropic · synced")"$'\n'"  $synced"$'\n'

[[ -n "$out" ]] || exit 0
# keep the leading newline: Claude Code prints the message after
# "SessionStart:startup says: ", so the first header would otherwise sit on
# that line, indented differently from the rest
jq -n --arg m "${out%$'\n'}" '{systemMessage: $m}'
