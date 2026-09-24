#!/usr/bin/env bash
#
# download-models.sh — pull the files listed in models.list into ComfyUI's
# model tree. Mirrors llama.cpp/download-model.sh in shape and arguments.
#
set -euo pipefail
cd "$(dirname "$0")"

CFG="config.env"
[[ -f "$CFG" ]] || { printf 'config.env not found — copy config.env.example first.\n' >&2; exit 1; }
# shellcheck disable=SC1090
source "./$CFG"
COMFY_DIR="${COMFY_DIR:?COMFY_DIR not set}"
VENV="$COMFY_DIR/venv"
MANIFEST="models.list"

usage() {
    cat <<EOF
Usage:
  download-models.sh --all                       Download every manifest entry
  download-models.sh <repo_id> <file> <subdir>   Download one file
  download-models.sh --list                      Show manifest entries
EOF
}

hf() {
    if [[ -x "$VENV/bin/hf" ]]; then "$VENV/bin/hf" "$@"
    elif command -v hf >/dev/null 2>&1; then hf "$@"
    else printf 'hf CLI not found — run install.sh first.\n' >&2; exit 1
    fi
}

fetch() {
    local repo="$1" file="$2" sub="$3"
    local dest="$COMFY_DIR/models/$sub"
    mkdir -p "$dest"
    if [[ -s "$dest/$(basename "$file")" ]]; then
        printf '  SKIP %s (already present)\n' "$(basename "$file")"
        return 0
    fi
    printf '  GET  %s :: %s -> models/%s\n' "$repo" "$file" "$sub"
    [[ -n "${HF_TOKEN:-}" ]] && export HF_TOKEN
    hf download "$repo" "$file" --local-dir "$dest"
}

read_manifest() {
    [[ -f "$MANIFEST" ]] || { printf '%s not found — copy models.example.list to it.\n' "$MANIFEST" >&2; exit 1; }
    sed -e 's/\r$//' "$MANIFEST" | awk -F'|' '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        NF >= 3 {
            gsub(/^[ \t]+|[ \t]+$/, "", $1)
            gsub(/^[ \t]+|[ \t]+$/, "", $2)
            gsub(/^[ \t]+|[ \t]+$/, "", $3)
            printf "%s\t%s\t%s\n", $1, $2, $3
        }'
}

case "${1:-}" in
    -h|--help) usage ;;
    --list)    read_manifest | awk -F'\t' '{printf "  %-34s %-40s -> models/%s\n", $1, $2, $3}' ;;
    --all)
        printf 'Downloading into %s/models\n' "$COMFY_DIR"
        while IFS=$'\t' read -r repo file sub; do fetch "$repo" "$file" "$sub"; done < <(read_manifest)
        printf 'done\n' ;;
    "")        usage; exit 1 ;;
    *)
        [[ $# -eq 3 ]] || { usage; exit 1; }
        fetch "$1" "$2" "$3" ;;
esac
