# Inference engines beyond llama.cpp — assessment for hermine (2026-09-09)

Question: for the user's workload — single-user agentic work with Claude Code on real
software, long contexts, one RTX 4090 (24 GB) on Windows/WSL2, i9-13900KF, 64 GB DDR5-6000 —
can vLLM or another engine beat llama.cpp? Measured where possible, reasoned where not.

## vLLM — measured (stock 0.28.0, WSL2, `vllm-backup/`)

Test: daily-driver model class (Qwen3.8-27B) as `dbirks/Qwen3.8-27B-W4A16-AutoRound`
(19 GB — the standard vLLM-ecosystem quant; GSQ-RCO GGUF is llama.cpp-only), served via the
repo-style `vllm-backup/` scripts, probed with the same prompts as the llama.cpp presets
(streaming, usage-based token counts).

| Axis | vLLM stock | llama.cpp `[Qwen3.8-27B]` (GSQ) |
|---|---|---|
| prose decode | 46.1 t/s (±0.1 — remarkably stable) | 72–82 t/s |
| verbatim rewrites | 46 t/s (no ngram speculation wired) | 243–453 t/s |
| max context that loads | **3,584** | **262,144** |
| TTFT (short prompt) | ~0.1 s | comparable |

The context collapse decomposes into four measured factors: (1) W4A16 weights are 19 GB vs
GSQ's 11.3; (2) WSL exposes only 22.49 of the card's 23.03 GiB, and Windows shell creep eats
into that between restarts; (3) vLLM keeps attention-KV in bf16 (llama.cpp preset: q4_0 —
4× smaller); (4) vLLM reserves a DeltaNet/Mamba state block per potential sequence with
`max_num_seqs` defaulting to 256 — batch-serving DNA; `--max-num-seqs 1` (the `parallel = 1`
analogue) is now in `serve.sh`. fp8-KV would roughly double the window but the FlashInfer JIT
is broken in this WSL setup (pip-nvcc 13.3 vs torch-CUDA 13.0 header mismatch; worked around
via `VLLM_ATTENTION_BACKEND=FLASH_ATTN` + sampler fallback). Even fully fixed, the ceiling is
~7–11k — two orders of magnitude below the llama.cpp preset.

The 114–126 t/s community references for this model (syv-ai 3090, Alpha-Leader 4090) are
**patched vLLM pipelines**: custom requant scripts (int8 GEMMs, calibrated int4 lm_head),
MTP patches that must be re-applied after every vLLM upgrade, vLLM pinned to 0.27.1. That is
the same maintenance category as llama.cpp vendor forks, which this repo excludes by policy.

**Verdict: for this workload on this machine, stock vLLM loses on every axis that matters
(context catastrophically, decode clearly, rewrites by 5–10×).** Its real strength is batched
multi-user throughput (PagedAttention; the syv-ai rig reports ~1,000 t/s aggregate at 64
concurrent on a 3090) — a use case this box does not have. Revisit if: the box ever serves
many parallel clients, moves to native Linux (full VRAM, working FlashInfer, fp8-KV), or a
maintained upstream vLLM gains the MTP/requant work.

Also relevant for the agentic stack: llama-server speaks the Anthropic-compatible endpoint
that `claudelocal` uses; vLLM is OpenAI-only and would need a proxy (LiteLLM etc.) in front —
one more moving part.

## Other engines — assessed, not measured

- **ExLlamaV2/V3 (TabbyAPI)**: the single-user-throughput specialist on consumer NVIDIA, and
  EXL3 quants are excellent per bit. Disqualifier here: no support for the hybrid
  Gated-DeltaNet architectures this repo's fleet lives on (Qwen3.8-27B, Ornith-1.5,
  Flash-Next) — it targets classic transformer archs. Worth re-checking if the fleet ever
  includes a dense classic-arch model as daily driver.
- **SGLang**: same batch-serving category as vLLM, same WSL/Linux story, faster structured
  output; nothing that changes the single-user verdict.
- **TensorRT-LLM**: per-model engine builds, heavyweight toolchain, Windows support exists
  but the build/maintenance cost dwarfs the llama.cpp workflow; batch-oriented.
- **ik_llama.cpp and other llama.cpp forks**: often genuinely faster (SOTA quants, expert
  caches — see the Flash-Next MTP story), but excluded by the official-builds policy;
  the Ternary-Bonsai precedent stands.
- **Ollama / LM Studio**: llama.cpp wrappers — same engine underneath, less control than the
  router presets this repo maintains.

## Bottom line

llama.cpp is not the compromise here — it is the best-fit engine for this hardware and
workload: GGUF gives the best quant-per-bit ecosystem (GSQ-RCO), q4_0/q8_0-KV and hybrid-attention
awareness buy the 262k window, mmap/CPU-MoE unlocks the 125B class, ngram speculation buys the
rewrite speed agentic loops live on, and the Anthropic endpoint plugs directly into Claude Code.
The `vllm-backup/` folder stays as a working, documented second engine for the day the batch
use case (or native Linux) arrives.
