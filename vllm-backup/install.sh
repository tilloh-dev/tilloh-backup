#!/usr/bin/env bash
# Creates the venv (gitignored) and downloads the model. Idempotent.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.env
python3 -m venv venv
./venv/bin/pip install --upgrade pip -q
./venv/bin/pip install vllm huggingface_hub nvidia-cuda-nvcc-cu12 nvidia-cuda-runtime-cu12 -q
mkdir -p "$VLLM_MODELS_DIR"
./venv/bin/hf download "$VLLM_MODEL" --local-dir "$VLLM_MODELS_DIR/$(basename "$VLLM_MODEL")"
echo "install done"
