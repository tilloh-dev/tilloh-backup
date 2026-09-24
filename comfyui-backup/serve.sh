#!/usr/bin/env bash
#
# serve.sh — start the ComfyUI server. Used directly and by the systemd unit.
#
set -euo pipefail
cd "$(dirname "$0")"

CFG="config.env"
[[ -f "$CFG" ]] || { printf 'config.env not found — copy config.env.example first.\n' >&2; exit 1; }
# shellcheck disable=SC1090
source "./$CFG"

COMFY_DIR="${COMFY_DIR:?COMFY_DIR not set}"
COMFY_HOST="${COMFY_HOST:-0.0.0.0}"
COMFY_PORT="${COMFY_PORT:-8188}"
COMFY_CUDA_DEVICE="${COMFY_CUDA_DEVICE:-0}"
COMFY_EXTRA_ARGS="${COMFY_EXTRA_ARGS:-}"

VENV="$COMFY_DIR/venv"
[[ -x "$VENV/bin/python" ]] || { printf 'venv missing — run install.sh first.\n' >&2; exit 1; }

# Pin the CUDA device explicitly. It is index 0 today because the AMD card is
# not a CUDA device at all, but a second NVIDIA card would silently shift it.
export CUDA_VISIBLE_DEVICES="$COMFY_CUDA_DEVICE"

printf 'ComfyUI @ http://%s:%s  (device %s, args: %s)\n' \
    "$COMFY_HOST" "$COMFY_PORT" "$COMFY_CUDA_DEVICE" "${COMFY_EXTRA_ARGS:-none}"

# shellcheck disable=SC2086
exec "$VENV/bin/python" "$COMFY_DIR/main.py" \
    --listen "$COMFY_HOST" \
    --port "$COMFY_PORT" \
    $COMFY_EXTRA_ARGS
