#!/usr/bin/env bash
#
# download-model.sh — snapshot HuggingFace checkpoint repos into $FT_MODELS_DIR
# (outside this repo; never committed).
#
# FreeToken loads a whole checkpoint DIRECTORY (safetensors + config), so unlike
# llama.cpp/download-model.sh this pulls the full repo, not a single .gguf file.
# Prefers the 'hf' / 'huggingface-cli' tool (resume, auth).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=config-load.sh
source "$SCRIPT_DIR/config-load.sh"
_ft_load_config "$SCRIPT_DIR"

FT_MODELS_DIR="${FT_MODELS_DIR:-$HOME/.local/share/freetoken/models}"
MANIFEST="$SCRIPT_DIR/models.list"

usage() {
    cat <<EOF
Usage:
  download-model.sh <repo_id> [dest_subdir] [exclude_globs]   Snapshot one repo
  download-model.sh --all                                     Snapshot every entry in models.list
  download-model.sh --list                                    Show manifest entries
  download-model.sh --help

subdir defaults to the repo basename. exclude_globs is a space-separated glob list
passed to 'hf download --exclude' (quote it), e.g. "original/* metal/*" to skip the
non-transformers weight copies some repos ship (gpt-oss-120b carries three).

Target dir: \$FT_MODELS_DIR = $FT_MODELS_DIR
Gated models: set HF_TOKEN in config.env or run 'hf auth login'.
EOF
}

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

download_one() {
    local repo="$1" dest="${2:-}" exclude="${3:-}"
    [[ -n "$dest" ]] || dest="$(basename "$repo")"
    local target_dir="$FT_MODELS_DIR/$dest"
    mkdir -p "$target_dir"

    # Space-separated globs -> repeated --exclude args (skip redundant weight copies).
    local -a excl=()
    if [[ -n "$exclude" ]]; then
        local g
        for g in $exclude; do excl+=(--exclude "$g"); done
        printf '  GET %s -> %s   (exclude: %s)\n' "$repo" "$target_dir" "$exclude"
    else
        printf '  GET %s -> %s\n' "$repo" "$target_dir"
    fi

    local -a auth=()
    if command -v hf >/dev/null 2>&1; then
        [[ -n "${HF_TOKEN:-}" ]] && auth=(--token "$HF_TOKEN")
        hf download "$repo" --local-dir "$target_dir" "${auth[@]}" "${excl[@]}"
    elif command -v huggingface-cli >/dev/null 2>&1; then
        [[ -n "${HF_TOKEN:-}" ]] && auth=(--token "$HF_TOKEN")
        huggingface-cli download "$repo" --local-dir "$target_dir" "${auth[@]}" "${excl[@]}"
    else
        printf 'ERROR: need the huggingface CLI for a full-repo snapshot.\n' >&2
        printf '       Install it with:  uv pip install huggingface_hub   (or pip install)\n' >&2
        exit 1
    fi
}

download_all() {
    [[ -f "$MANIFEST" ]] || { printf 'No manifest: %s\n' "$MANIFEST" >&2; exit 1; }
    printf 'Downloading all entries from %s\n' "$MANIFEST"
    local line repo dest exclude
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line//[[:space:]]/}" ]] && continue
        IFS='|' read -r repo dest exclude <<< "$line"
        repo="$(trim "$repo")"; dest="$(trim "${dest:-}")"; exclude="$(trim "${exclude:-}")"
        if [[ -z "$repo" ]]; then
            printf '  WARN: skipping malformed line: %s\n' "$line" >&2
            continue
        fi
        download_one "$repo" "$dest" "$exclude"
    done < "$MANIFEST"
}

case "${1:-}" in
    ""|-h|--help) usage ;;
    --list)
        [[ -f "$MANIFEST" ]] || { printf 'No manifest: %s\n' "$MANIFEST" >&2; exit 1; }
        grep -vE '^[[:space:]]*(#|$)' "$MANIFEST" || true
        ;;
    --all) download_all ;;
    --*)   printf 'Unknown option: %s\n' "$1" >&2; usage; exit 1 ;;
    *)     download_one "$1" "${2:-}" "${3:-}" ;;
esac
