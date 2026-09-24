#!/usr/bin/env bash
#
# server.sh — start llama-server in router mode (default) or for a single model.
#
# Linux adaptation of countzero/windows_llama.cpp's examples/server.ps1. Heavy
# per-model tuning lives in the preset INI; this script stays portable.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=config-load.sh
source "$SCRIPT_DIR/config-load.sh"
_llama_load_config "$SCRIPT_DIR"

LLAMA_MODELS_DIR="${LLAMA_MODELS_DIR:-$HOME/.local/share/llama.cpp/models}"
LLAMA_HOST="${LLAMA_HOST:-127.0.0.1}"
LLAMA_PORT="${LLAMA_PORT:-8081}"
LLAMA_PRESET="${LLAMA_PRESET:-presets/models.ini}"
LLAMA_MODELS_MAX="${LLAMA_MODELS_MAX:-1}"
LLAMA_NGL="${LLAMA_NGL:-999}"
LLAMA_CTX="${LLAMA_CTX:-0}"
LLAMA_KV="${LLAMA_KV:-f16}"
LLAMA_AUTO_UPDATE="${LLAMA_AUTO_UPDATE:-1}"
LLAMA_UPDATE_CHECK_INTERVAL="${LLAMA_UPDATE_CHECK_INTERVAL:-3600}"   # seconds; 0 = always check

# --- auto-update (throttled) ------------------------------------------------
# Runs bootstrap.sh before serving so LLAMA_VERSION=latest actually stays
# current. bootstrap.sh itself is idempotent (skips the download if the
# resolved tag is already installed), so this is cheap once up to date.
# Throttled by a local marker so restarts within LLAMA_UPDATE_CHECK_INTERVAL
# don't re-hit the GitHub API (rate limits) or need network at all.
maybe_auto_update() {
    [[ "$LLAMA_AUTO_UPDATE" == "0" ]] && return
    local marker="$SCRIPT_DIR/vendor/.last-auto-check" now last
    now="$(date +%s)"
    if [[ "$LLAMA_UPDATE_CHECK_INTERVAL" != "0" && -f "$marker" ]]; then
        last="$(cat "$marker" 2>/dev/null || printf 0)"
        if [[ "$last" =~ ^[0-9]+$ ]] && (( now - last < LLAMA_UPDATE_CHECK_INTERVAL )); then
            return
        fi
    fi
    printf 'Checking for llama.cpp updates (LLAMA_VERSION=%s, recheck every %ss)...\n' \
        "${LLAMA_VERSION:-latest}" "$LLAMA_UPDATE_CHECK_INTERVAL"
    mkdir -p "$SCRIPT_DIR/vendor"
    printf '%s' "$now" > "$marker"
    if ! bash "$SCRIPT_DIR/bootstrap.sh"; then
        printf 'WARNING: update check failed (offline / rate-limited?) — continuing with the installed build if present.\n' >&2
    fi
}

# --- locate binary (only when actually serving) ----------------------------
BIN=""
resolve_bin() {
    # -L: vendor/ or a parent may be a symlink. Prefer the extensionless Linux
    # binary, then the Windows .exe — on the WSL/Windows host vendor/ holds only
    # *.exe, and without this fallback serving fails there while --list works.
    BIN="$(find -L "$SCRIPT_DIR/vendor" -name llama-server -type f 2>/dev/null | head -n1)"
    [[ -n "$BIN" ]] || BIN="$(find -L "$SCRIPT_DIR/vendor" -name llama-server.exe -type f 2>/dev/null | head -n1)"
    [[ -n "$BIN" ]] || { printf 'llama-server not found. Run ./bootstrap.sh first.\n' >&2; exit 1; }
    export LD_LIBRARY_PATH="$(dirname "$BIN"):${LD_LIBRARY_PATH:-}"
}

# A Windows llama-server.exe cannot resolve /mnt/c/... — it needs C:/... back.
# config-load.sh deliberately hands bash the POSIX form (find/-f tests need it),
# so every path given to the .exe has to be converted at the call site.
host_path() {
    if [[ "$BIN" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
        wslpath -m "$1" 2>/dev/null || printf '%s' "$1"
    else
        printf '%s' "$1"
    fi
}

physical_cores() {
    local cps sockets
    if command -v lscpu >/dev/null 2>&1; then
        cps="$(lscpu | sed -n 's/^Core(s) per socket:[[:space:]]*//p')"
        sockets="$(lscpu | sed -n 's/^Socket(s):[[:space:]]*//p')"
        if [[ "$cps" =~ ^[0-9]+$ && "$sockets" =~ ^[0-9]+$ ]]; then
            printf '%s' "$(( cps * sockets ))"
            return
        fi
    fi
    nproc
}

list_models() {
    printf 'GGUF models under %s:\n' "$LLAMA_MODELS_DIR"
    if [[ -d "$LLAMA_MODELS_DIR" ]]; then
        find "$LLAMA_MODELS_DIR" -type f -name '*.gguf' \
            ! -name 'mmproj.*' ! -name 'ggml-vocab-*' 2>/dev/null | sort || true
    fi
}

# --- preset section -> llama-server argv ------------------------------------
# Single-model mode that reuses a [section] from $LLAMA_PRESET, so the INI stays
# the one place per machine where tuning lives (and the one file worth backing
# up). The router does this translation internally; --models-preset is
# router-only, so for a single model we redo it here.
#
# Whether a key is a bare switch, a --no- pair or a value flag is derived from
# the INSTALLED build's --help, never from a list in this script: a release that
# changes a flag's arity is then picked up without an edit. Help format relied
# on (llama.cpp b11146):
#   --jinja, --no-jinja            -> bool  (--jinja / --no-jinja)
#   -fa, --flash-attn [on|off|auto]-> value (--flash-attn on)
#   --temp, --temperature N        -> value (--temp is a valid spelling)
HELP_CACHE=""
SECTION_DRY_RUN=0

load_help() {
    [[ -n "$HELP_CACHE" ]] && return 0
    HELP_CACHE="$(mktemp)"
    trap 'rm -f "$HELP_CACHE"' EXIT
    "$BIN" --help >"$HELP_CACHE" 2>&1 || true
}

# flag_kind KEY -> bool | value | bare | "" (flag unknown to this build)
flag_kind() {
    load_help
    awk -v k="$1" '
        index($0, "--" k) == 0 { next }
        {
            # Flag list and description are separated by a run of 2+ spaces,
            # but short flags are padded so --long starts at column 8 -- that
            # padding must not be mistaken for the separator. When the flag list
            # itself runs long the description sits on the next line and the
            # whole line is the spec (e.g. --spec-draft-type-k, -ctkd, ...).
            spec = $0
            cut = 0
            for (i = 8; i < length(spec); i++)
                if (substr(spec, i, 2) == "  ") { cut = i; break }
            if (cut) spec = substr(spec, 1, cut - 1)
            if (spec !~ ("(^|[ ,])--" k "([ ,]|$)")) next
            if (spec ~ ("--no-" k "([ ,]|$)")) { print "bool"; exit }
            rest = spec
            gsub(/-[^ ,]+,?/, " ", rest)      # drop every flag spelling
            gsub(/^[ \t]+|[ \t]+$/, "", rest) # what remains is the placeholder
            print (rest == "" ? "bare" : "value")
            exit
        }
    ' "$HELP_CACHE"
}

# read_section FILE NAME -> "key<TAB>value" lines
read_section() {
    awk -v want="$2" '
        { sub(/\r$/, "") }                    # both preset files see CRLF hosts
        /^[ \t]*\[/ {
            sec = $0; sub(/^[ \t]*\[/, "", sec); sub(/\].*$/, "", sec)
            inside = (sec == want); next
        }
        !inside { next }
        /^[ \t]*[#;]/ { next }                # whole-line and continuation comments
        /=/ {
            line = $0
            sub(/[ \t]+[#;].*$/, "", line)    # inline comment needs leading space
            key = line; sub(/=.*$/, "", key)
            val = line; sub(/^[^=]*=/, "", val)
            gsub(/^[ \t]+|[ \t]+$/, "", key)
            gsub(/^[ \t]+|[ \t]+$/, "", val)
            if (key != "") printf "%s\t%s\n", key, val
        }
    ' "$1"
}

run_section() {
    local name="${1:-}"; shift || true
    [[ -n "$name" ]] || { printf 'Usage: server.sh --section <NAME> [extra llama-server args]\n' >&2; exit 1; }
    local preset="$SCRIPT_DIR/$LLAMA_PRESET"
    if [[ ! -f "$preset" ]]; then
        printf 'Preset not found: %s\n' "$preset" >&2
        exit 1
    fi
    maybe_auto_update
    resolve_bin
    # Must happen HERE, not lazily inside flag_kind: that runs in a command
    # substitution, so the cache path it sets would be lost with the subshell
    # and every key would re-run `llama-server --help` (backend init each time).
    load_help

    local -a args=(--host "$LLAMA_HOST" --port "$LLAMA_PORT")
    local found=0 key val kind
    while IFS=$'\t' read -r key val; do
        [[ -n "$key" ]] || continue
        found=1
        kind="$(flag_kind "$key")"
        case "$kind" in
            bool)
                case "${val,,}" in
                    true|on|1|yes) args+=("--$key") ;;
                    *)             args+=("--no-$key") ;;
                esac ;;
            bare)
                case "${val,,}" in
                    true|on|1|yes) args+=("--$key") ;;
                esac ;;
            value)
                [[ "$val" == /* && -e "$val" ]] && val="$(host_path "$val")"
                args+=("--$key" "$val") ;;
            *)
                # Unknown to this build. Passed through anyway so the failure is
                # the same one the router would give, instead of a silent drop.
                printf 'warning: --%s is not in this build'"'"'s --help; passing it through\n' "$key" >&2
                [[ "$val" == /* && -e "$val" ]] && val="$(host_path "$val")"
                args+=("--$key" "$val") ;;
        esac
    done < <(read_section "$preset" "$name")

    if (( ! found )); then
        printf 'Section [%s] not found in %s\n' "$name" "$LLAMA_PRESET" >&2
        printf 'Available sections: %s\n' \
            "$(grep -o '^\[[^]]*\]' "$preset" | tr -d '[]' | tr '\n' ' ')" >&2
        exit 1
    fi

    args+=("$@")
    if (( SECTION_DRY_RUN )); then
        printf '%s\n' "$BIN"
        printf '  %s\n' "${args[@]}"
        return 0
    fi
    printf 'Single model @ http://%s:%s  (section: [%s] from %s)\n' \
        "$LLAMA_HOST" "$LLAMA_PORT" "$name" "$LLAMA_PRESET"
    exec "$BIN" "${args[@]}"
}

run_router() {
    local preset="$SCRIPT_DIR/$LLAMA_PRESET"
    if [[ ! -f "$preset" ]]; then
        printf 'Preset not found: %s\n' "$preset" >&2
        printf 'Copy presets/models.example.ini to %s and edit the paths.\n' "$LLAMA_PRESET" >&2
        exit 1
    fi
    maybe_auto_update
    resolve_bin
    printf 'Router mode @ http://%s:%s  (preset: %s, max: %s)\n' \
        "$LLAMA_HOST" "$LLAMA_PORT" "$LLAMA_PRESET" "$LLAMA_MODELS_MAX"
    exec "$BIN" \
        --host "$LLAMA_HOST" \
        --port "$LLAMA_PORT" \
        --models-dir "$(host_path "$LLAMA_MODELS_DIR")" \
        --models-preset "$(host_path "$preset")" \
        --models-max "$LLAMA_MODELS_MAX"
}

run_single() {
    local model="$1"; shift || true
    [[ -f "$model" ]] || { printf 'Model not found: %s\n' "$model" >&2; exit 1; }
    maybe_auto_update
    resolve_bin
    local threads; threads="$(physical_cores)"
    local -a args=(
        --host "$LLAMA_HOST"
        --port "$LLAMA_PORT"
        --model "$(host_path "$model")"
        --alias "$(basename "$model")"
        --threads "$threads"
        --n-gpu-layers "$LLAMA_NGL"
        --ctx-size "$LLAMA_CTX"
        --cache-type-k "$LLAMA_KV"
        --cache-type-v "$LLAMA_KV"
    )
    # mmproj autodetect (multimodal projector next to the model file)
    local mmproj
    mmproj="$(find "$(dirname "$model")" -maxdepth 1 -type f -name 'mmproj.*' 2>/dev/null | head -n1)"
    [[ -n "$mmproj" ]] && args+=(--mmproj "$mmproj")
    # passthrough of any extra llama-server flags
    args+=("$@")
    printf 'Single model @ http://%s:%s  (%s, threads=%s)\n' \
        "$LLAMA_HOST" "$LLAMA_PORT" "$(basename "$model")" "$threads"
    exec "$BIN" "${args[@]}"
}

case "${1:-}" in
    -h|--help)
        cat <<EOF
Usage:
  server.sh                       Router mode (multi-model) via \$LLAMA_PRESET
  server.sh <model.gguf> [args]   Single model; extra args pass through to llama-server
  server.sh --section <NAME>      Single model using [NAME] from \$LLAMA_PRESET
                                  (same tuning as router mode, no router)
  server.sh --print-section <NAME> Show the argv that --section would run
  server.sh --list                List GGUF files under \$LLAMA_MODELS_DIR

Auto-update (config.env): LLAMA_AUTO_UPDATE=0 disables the update check;
LLAMA_UPDATE_CHECK_INTERVAL (seconds, default 3600) throttles how often
serving re-checks GitHub for a newer LLAMA_VERSION build.
EOF
        ;;
    --list) list_models ;;
    --section) shift; run_section "$@" ;;
    --print-section) shift; SECTION_DRY_RUN=1; run_section "$@" ;;
    "")     run_router ;;
    *)      run_single "$@" ;;
esac
