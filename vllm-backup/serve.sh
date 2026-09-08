#!/usr/bin/env bash
# Starts the vLLM OpenAI-compatible server. Ctrl+C stops it.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.env
# WSL has no system CUDA toolkit; vLLM's warmup JIT needs nvcc — use the pip-provided one
export CUDA_HOME="$(pwd)/venv/lib/python3.10/site-packages/nvidia/cu13"
export PATH="$CUDA_HOME/bin:$PATH"
# FlashInfer JIT breaks on nvcc/torch CUDA minor mismatch (13.3 vs 13.0) — bypass it
export VLLM_ATTENTION_BACKEND=FLASH_ATTN
export VLLM_USE_FLASHINFER_SAMPLER=0
exec ./venv/bin/vllm serve "$VLLM_MODELS_DIR/$(basename "$VLLM_MODEL")" \
  --served-model-name "$VLLM_SERVED_NAME" \
  --host "$VLLM_HOST" --port "$VLLM_PORT" \
  --max-model-len "$VLLM_MAX_MODEL_LEN" \
  --gpu-memory-utilization "$VLLM_GPU_MEM_UTIL" \
  --kv-cache-dtype "$VLLM_KV_CACHE_DTYPE" \
  --max-num-seqs "${VLLM_MAX_NUM_SEQS:-1}"
