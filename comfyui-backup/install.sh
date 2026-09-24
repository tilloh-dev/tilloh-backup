#!/usr/bin/env bash
#
# install.sh — check out ComfyUI, build its venv, add the GGUF loader node.
# Idempotent: re-running updates the checkouts and leaves models alone.
#
set -euo pipefail
cd "$(dirname "$0")"

CFG="config.env"
[[ -f "$CFG" ]] || { printf 'config.env not found — copy config.env.example and adjust.\n' >&2; exit 1; }
# shellcheck disable=SC1090
source "./$CFG"

COMFY_DIR="${COMFY_DIR:?COMFY_DIR not set}"
COMFY_TORCH_INDEX="${COMFY_TORCH_INDEX:-https://download.pytorch.org/whl/cu126}"
COMFY_TORCH_VERSION="${COMFY_TORCH_VERSION:-2.7.1}"

# --- ComfyUI itself ---------------------------------------------------------
if [[ -d "$COMFY_DIR/.git" ]]; then
    printf 'Updating ComfyUI in %s\n' "$COMFY_DIR"
    git -C "$COMFY_DIR" pull --ff-only
else
    printf 'Cloning ComfyUI into %s\n' "$COMFY_DIR"
    mkdir -p "$(dirname "$COMFY_DIR")"
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
fi

# --- GGUF loader ------------------------------------------------------------
# Without this node ComfyUI cannot read a .gguf diffusion model at all; the
# quantised Qwen-Image build is the only one that fits 12 GB.
NODE_DIR="$COMFY_DIR/custom_nodes/ComfyUI-GGUF"
if [[ -d "$NODE_DIR/.git" ]]; then
    git -C "$NODE_DIR" pull --ff-only
else
    git clone https://github.com/city96/ComfyUI-GGUF.git "$NODE_DIR"
fi

# --- venv -------------------------------------------------------------------
VENV="$COMFY_DIR/venv"
if [[ ! -x "$VENV/bin/python" ]]; then
    printf 'Creating venv in %s\n' "$VENV"
    python3 -m venv "$VENV"
fi
"$VENV/bin/pip" install --upgrade pip -q

# torch first and from the CUDA index, so the generic requirements.txt cannot
# pull a CPU-only wheel over it afterwards. The version is pinned on purpose —
# see config.env.example for why the working window is only one minor release
# wide on this driver.
printf 'Installing torch %s from %s\n' "$COMFY_TORCH_VERSION" "$COMFY_TORCH_INDEX"
"$VENV/bin/pip" install -q --index-url "$COMFY_TORCH_INDEX" \
    "torch==$COMFY_TORCH_VERSION" torchvision torchaudio

printf 'Installing ComfyUI requirements\n'
"$VENV/bin/pip" install -q -r "$COMFY_DIR/requirements.txt"
"$VENV/bin/pip" install -q -r "$NODE_DIR/requirements.txt"
"$VENV/bin/pip" install -q huggingface_hub

# --- verify the GPU is actually reachable -----------------------------------
printf '\nCUDA check: '
"$VENV/bin/python" - <<'PY'
import torch
if not torch.cuda.is_available():
    raise SystemExit("torch reports no CUDA device — driver or wheel mismatch")
print("%s, %.1f GiB, torch %s" % (
    torch.cuda.get_device_name(0),
    torch.cuda.get_device_properties(0).total_memory / 1024**3,
    torch.__version__))
PY

# Second half of the version window: a too-old torch passes the CUDA check above
# and then dies at first import on comfy_kitchen's `list[int]` op annotation,
# which only shows when the server actually starts. Fail here instead.
printf 'comfy_kitchen check: '
"$VENV/bin/python" -c 'import comfy_kitchen; print("OK")'

printf '\ninstall done. Next: bash download-models.sh\n'
