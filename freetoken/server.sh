#!/usr/bin/env bash
#
# server.sh — start FreeToken's `ft serve` for one model.
#
# FreeToken has no multi-model router (unlike llama.cpp's --models-preset): one
# `ft serve` process serves one model on one port. A "preset" here is a small
# presets/<name>.env that names the checkpoint and its FT_* overrides.
#
#   server.sh                    Serve the default preset ($FT_PRESET)
#   server.sh <preset-name>      Serve presets/<preset-name>.env
#   server.sh --model <id|dir>   Serve an ad-hoc HF repo id or local dir
#   server.sh --list             List downloaded checkpoint dirs
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=config-load.sh
source "$SCRIPT_DIR/config-load.sh"
_ft_load_config "$SCRIPT_DIR"

FT_MODELS_DIR="${FT_MODELS_DIR:-$HOME/.local/share/freetoken/models}"
FT_HOST="${FT_HOST:-127.0.0.1}"
FT_PORT="${FT_PORT:-1919}"
FT_PRESET="${FT_PRESET:-qwen3.6-35B-A3B}"
FT_MOE_BACKEND="${FT_MOE_BACKEND:-auto}"
FT_MEMORY_RATIO="${FT_MEMORY_RATIO:-0.9}"
FT_MAX_OUTPUT_TOKENS="${FT_MAX_OUTPUT_TOKENS:-32768}"
FT_EXTRA_ARGS="${FT_EXTRA_ARGS:-}"

FT="$SCRIPT_DIR/.venv/bin/ft"

list_models() {
    printf 'Checkpoint dirs under %s:\n' "$FT_MODELS_DIR"
    if [[ -d "$FT_MODELS_DIR" ]]; then
        find "$FT_MODELS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort || true
    fi
}

resolve_ft() {
    [[ -x "$FT" ]] || { printf 'ft not found: %s\nRun ./bootstrap.sh first.\n' "$FT" >&2; exit 1; }
}

# Prefer a downloaded local dir; fall back to the HF repo id (ft can pull it).
resolve_model() {
    local repo="$1" dir="$2" path
    if [[ -n "$dir" && -d "$FT_MODELS_DIR/$dir" ]]; then
        printf '%s' "$FT_MODELS_DIR/$dir"
    else
        printf '%s' "$repo"
    fi
}

serve() {
    local model="$1" served="${2:-}"
    resolve_ft
    local -a args=(
        serve
        --model "$model"
        --host "$FT_HOST"
        --port "$FT_PORT"
        --moe-backend "$FT_MOE_BACKEND"
        --memory-ratio "$FT_MEMORY_RATIO"
        --max-output-tokens "$FT_MAX_OUTPUT_TOKENS"
    )
    [[ -n "$served" ]] && args+=(--served-model-name "$served")
    # shellcheck disable=SC2206
    [[ -n "$FT_EXTRA_ARGS" ]] && args+=($FT_EXTRA_ARGS)
    printf 'FreeToken serve @ http://%s:%s  (model: %s, moe: %s)\n' \
        "$FT_HOST" "$FT_PORT" "$model" "$FT_MOE_BACKEND"
    exec "$FT" "${args[@]}"
}

serve_preset() {
    local name="$1" preset="$SCRIPT_DIR/presets/$1.env"
    [[ -f "$preset" ]] || { printf 'Preset not found: %s\n' "$preset" >&2; exit 1; }
    # Preset overrides config.env for this model only.
    # shellcheck disable=SC1090
    source "$preset"
    local model; model="$(resolve_model "${FT_MODEL_REPO:-}" "${FT_MODEL_DIR:-}")"
    [[ -n "$model" ]] || { printf 'Preset %s sets no FT_MODEL_REPO.\n' "$name" >&2; exit 1; }
    serve "$model" "${FT_SERVED_NAME:-}"
}

case "${1:-}" in
    -h|--help)
        sed -n '3,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        ;;
    --list) list_models ;;
    --model)
        [[ $# -ge 2 ]] || { printf 'Usage: server.sh --model <id|dir>\n' >&2; exit 1; }
        serve "$2" ;;
    "")     serve_preset "$FT_PRESET" ;;
    --*)    printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
    *)      serve_preset "$1" ;;
esac
