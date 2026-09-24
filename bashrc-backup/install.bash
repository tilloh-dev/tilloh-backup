#!/bin/bash
# Deploys the bash config into $HOME and replaces the "# CUSTOM START … # CUSTOM END"
# block of ~/.bashrc with the one from this directory.
#
# API keys: the template carries the placeholder "insert_api_key_here" for every
# "export *_API_KEY=" line. The script first asks, per key, whether to keep the value
# the current ~/.bashrc block already has or type a new one (input is silent, never
# echoed), then copies files and rewrites the block. Without a terminal on stdin it
# keeps the existing values and asks nothing.

set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1

PLACEHOLDER=insert_api_key_here
BLOCK_START='^# CUSTOM START'
BLOCK_END='^# CUSTOM END'

# ── styling (only when stdout is a terminal) ─────────────────────────────────
if [[ -t 1 ]] && command -v tput >/dev/null && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
  B=$(tput bold) D=$(tput dim) G=$(tput setaf 2) Y=$(tput setaf 3) C=$(tput setaf 6) R=$(tput sgr0)
else
  B="" D="" G="" Y="" C="" R=""
fi
h()   { printf '\n%s%s%s\n' "$B" "$1" "$R"; }                    # section header
ok()  { printf '  %s✔%s %s\n' "$G" "$R" "$1"; }
warn(){ printf '  %s!%s %s\n' "$Y" "$R" "$1"; }
kv()  { printf '  %s✔%s %-26s %s%s%s\n' "$G" "$R" "$1" "$D" "$2" "$R"; }
kw()  { printf '  %s!%s %-26s %s%s%s\n' "$Y" "$R" "$1" "$D" "$2" "$R"; }

printf '%s%sBash config install%s  %s%s → ~%s\n' "$B" "$C" "$R" "$D" "$PWD" "$R"

# ── gather ────────────────────────────────────────────────────────────────────
new_block=$(sed -n "/$BLOCK_START/,/$BLOCK_END/p" .bashrc)
current_block=""
[[ -f ~/.bashrc ]] && current_block=$(sed -n "/$BLOCK_START/,/$BLOCK_END/p" ~/.bashrc)

mapfile -t key_vars < <(printf '%s\n' "$new_block" | sed -n 's/^export \([A-Za-z_][A-Za-z0-9_]*_API_KEY\)=.*/\1/p')

# Value of "export VAR=…" in the current block, quotes stripped; empty if unset or placeholder.
current_value() { # var
  local v
  v=$(printf '%s\n' "$current_block" | sed -n "s/^export $1=//p" | tail -1)
  v=${v#\'}; v=${v%\'}; v=${v#\"}; v=${v%\"}
  [[ "$v" == "$PLACEHOLDER" ]] && v=""
  printf '%s' "$v"
}

# ── 1. ask ────────────────────────────────────────────────────────────────────
declare -A key_value=() key_state=()
if (( ${#key_vars[@]} )); then
  h "API keys"
  if [[ -t 0 ]]; then
    printf '  %sEnter keeps the current value. Input is not echoed.%s\n' "$D" "$R"
  else
    printf '  %sNo terminal on stdin - keeping current values.%s\n' "$D" "$R"
  fi
fi
for var in "${key_vars[@]}"; do
  cur=$(current_value "$var")
  new=""
  if [[ -t 0 ]]; then
    label=$(printf '%-26s' "$var")
    if [[ -n "$cur" ]]; then
      read -rs -p "  ${B}${label}${R} ${D}found in ~/.bashrc, new value?${R} " new
    else
      read -rs -p "  ${B}${label}${R} ${D}not set, value?${R} " new
    fi
    printf '\n'
  fi
  if [[ -n "$new" ]]; then
    key_value[$var]=$new; key_state[$var]=set
  elif [[ -n "$cur" ]]; then
    key_value[$var]=$cur; key_state[$var]=kept
  else
    key_value[$var]=$PLACEHOLDER; key_state[$var]=placeholder
  fi
done

# ── 2. files ──────────────────────────────────────────────────────────────────
h "Files"
cp .bashrc-aliases   ~/.bashrc-aliases   && ok "~/.bashrc-aliases"
cp .bashrc-functions ~/.bashrc-functions && ok "~/.bashrc-functions"

# Rewrite the export lines in the new block. Done in bash, not sed, so a value
# with "/", "&" or "|" cannot break the substitution.
installed_block=""
while IFS= read -r line; do
  for var in "${key_vars[@]}"; do
    if [[ "$line" == "export $var="* ]]; then
      line="export $var=${key_value[$var]}"
      break
    fi
  done
  installed_block+="$line"$'\n'
done <<< "$new_block"

if [[ -n "$current_block" ]]; then
  sed -i "/$BLOCK_START/,/$BLOCK_END/d" ~/.bashrc
  action="CUSTOM block replaced"
else
  action="CUSTOM block appended"
fi
{ printf '\n'; printf '%s' "$installed_block"; } >> ~/.bashrc
ok "~/.bashrc  ${D}${action}${R}"

# ── 3. summary ────────────────────────────────────────────────────────────────
if (( ${#key_vars[@]} )); then
  h "Keys"
  for var in "${key_vars[@]}"; do
    case ${key_state[$var]} in
      kept)        kv "$var" "kept" ;;
      set)         kv "$var" "set" ;;
      placeholder) kw "$var" "placeholder - edit ~/.bashrc when you have the key" ;;
    esac
  done
fi

printf '\n%sDone.%s %sType %saliases%s or %sfunctions%s to list what is installed. Reloading shell…%s\n' \
  "$B" "$R" "$D" "$R$C" "$R$D" "$R$C" "$R$D" "$R"

exec bash -l
