# FreeToken operations — hermine setup, Gate-0 findings, measurements

Companion to `../freetoken/`. Records what was verified vs. computed, the reasons
the tooling diverges from `llama.cpp/`, and per-machine numbers. Update this file
when something is measured; the README stays short.

## Why FreeToken is not a llama.cpp preset

FreeToken (`github.com/FlashML-org/FreeToken`) is a **separate MoE serving
engine**, not a llama.cpp backend or GGUF preset. It installs as a Python package
(`ft` CLI), serves OpenAI **and** Anthropic APIs on port 1919, keeps MoE experts
in host RAM with an LRU expert cache on the GPU (`offload`), or splits work
CPU/PCIe (`hybrid`). It loads HF safetensors checkpoints directly (GGUF only for
Gemma-4). None of that fits the llama.cpp/GGUF/router tooling, hence the sibling
`freetoken/` dir instead of a `models.ini` section.

## Gate 0 — runtime feasibility (verified 2026-08-25 on hermine/WSL2)

The decision that shaped the whole layout: **FreeToken is Linux-only, so on
hermine it runs in WSL2, never native Windows.** Evidence, all from the package
metadata and docs, not assumption:

- PyPI `freetoken` 0.1.2 ships **only** `manylinux_2_27_x86_64` wheels (cp310–313);
  classifier `Operating System :: POSIX :: Linux`; dependency `triton==3.6.0;
  platform_system == "Linux"`; accel extra pulls `flashinfer-python[cu13]` +
  `sglang-kernel` (Linux CUDA only).
- `docs/install.md` requirements: **Linux x86_64, NVIDIA driver r580+ (CUDA 13)**.
  "CUDA kernels are JIT-compiled on first use, need a CUDA 13 toolkit with `nvcc`
  on PATH."

Consequence: the user's preference for the native-Windows `.ps1` path (as
llama.cpp uses) is **not possible**. `freetoken/` is bash-only; there is no
`.ps1` half to write. This was chosen against the stated preference because the
evidence is unambiguous — noted here so it is not "corrected" later.

### hermine live values (read-only, 2026-08-25)

| Resource | Value | Note |
|----------|-------|------|
| Host RAM | **48 GB** physical | WSL saw 39 GB under `memory=40GB` in `.wslconfig` |
| VRAM | 23 GB (RTX 4090) | ~1 GB idle; driver **610.88** ≥ r580 ✓ |
| CPU | 32 threads | |
| Disk `C:` free | **233 GB** | 1.9 TB, 88 % used |
| `nvcc` in WSL | **absent** | CUDA toolkit not installed — bootstrap gates on it |
| `.wslconfig` | `memory=40GB, swap=8GB` | raise to `memory=44GB` for gpt-oss-120b |
| uv / Python | 0.9.17 / 3.10.12 | ✓ |

## Model fit on hermine — computed, not yet measured

Sizes are **computed** from parameter count × bits-per-weight; none measured on
this box yet. Confirm with a real `ft serve` + `ft ctl stats` and record below.

| Model | Quant | ~Size | Verdict |
|-------|-------|-------|---------|
| `Qwen/Qwen3.6-35B-A3B-FP8` | FP8 | ~35 GB | fits host RAM comfortably → `offload`, all experts resident. **Safe first pick.** |
| `openai/gpt-oss-120b` | MXFP4 | ~63 GB | **marginal.** Experts (~58 GB of 63) must sit in host RAM; 48 GB physical is short even with `memory=44GB`. Expect spill/OOM unless a large GPU expert cache covers the gap. Measure before trusting. |
| `deepseek-ai/DeepSeek-V4-Flash-0731` | FP8 | ~300 GB | **impossible** on 48 GB RAM / 233 GB disk. This is why the DeepSeek-via-FreeToken idea was dropped. |

Note the unsloth `DeepSeek-V4-Flash-0731-GGUF` (deepseek4 arch, IQ1_S 82.5 GB …
Q8 162 GB) is a **llama.cpp** path, not FreeToken (FreeToken takes GGUF only for
Gemma-4). It was considered and also dropped; kept here so the option is not
re-discovered from scratch.

## Tooling divergences from llama.cpp/ (by design)

- **No `vendor/` tarball** — install is a uv venv (`freetoken/.venv`, gitignored);
  `bootstrap.sh` = venv + `uv pip install "freetoken[accel]"` + CUDA gate + `ft bench bw`.
- **No router / INI preset** — one `ft serve` per model per port. `presets/*.env`
  are per-model flag sets sourced by `server.sh`, not a live multi-model preset.
- **Model = directory** — `download-model.sh` snapshots a whole HF repo into
  `$FT_MODELS_DIR/<subdir>`, not a single `.gguf`.
- **`ft bench bw`** — a per-GPU calibration step llama.cpp has no analogue for;
  writes `~/.cache/freetoken/benchbw/<gpu-uuid>.json`, read by `--moe-backend auto`.
- **config-load.sh** drops the `config.ps1` branch (no Windows runtime) but keeps
  the CRLF strip, since the file may be edited on the Windows side of the checkout.

## OpenCode wiring

Manual `freetoken` provider in `opencode-backup/opencode.jsonc`
(`baseURL http://hermine:1919/v1`, models `Qwen3.6-35B-A3B`, `gpt-oss-120b`), added
to `enabled_providers`. `ft launch opencode` is deliberately **not** used — it
rewrites the live `~/.config/opencode` config instead of the repo-managed backup.

## Live run — measured 2026-08-25 (hermine/WSL2)

Ran everything reachable without sudo. Findings, in order:

- **Install works without a CUDA toolkit.** `uv pip install "freetoken[accel]"`
  succeeded; uv built the venv on **CPython 3.12.12** (not the system 3.10).
  `ft --version` → **freetoken 0.1.2**. The install pulls its own
  `nvidia-cuda-*` wheels (nvrtc, cudart, cublas, …) + torch 2.11 + flashinfer +
  sglang-kernel + triton.
- **Download trap: `openai/gpt-oss-120b` ships the weights three times.** A full
  snapshot pulled root transformers safetensors (~61 GB, what FreeToken loads) **+**
  `original/` (raw MXFP4, ~61 GB) **+** `metal/model.bin` (Apple, ~61 GB) = 183 GB.
  Fixed by adding `--exclude` support to `download-model.sh` and an `exclude_globs`
  column to `models.list` (`original/* metal/*`); removed the two extra copies,
  reclaimed 122 GB. Qwen3.6-35B-A3B-FP8 was a clean 35 GB.
- **`ft bench bw` on the 4090** (profile `~/.cache/freetoken/benchbw.json`):
  CPU STREAM read **86.3 GB/s**, PCIe linear **H2D 24.0 / D2H 26.2 GB/s**. CPU-MoE
  kernels compiled and ran (bf16 80.6, nvfp4 67.3, mxfp4 33.2, ds_fp4 51.8 GB/s).
  **PCIe-gather failed for every dtype:** "Could not find CUDA installation.
  Please set CUDA_HOME" — the GPU gather kernel needs the CUDA 13 toolkit. fp8 also
  flagged "CPU MoE has no fp8_block weight path; hybrid unavailable".
- **`ft serve` (Qwen3.6-35B-A3B-FP8) initialises fine without nvcc** — this is the
  important one. It parsed the checkpoint, started the API on 1919, and auto-picked:
  attention **`fi`** (flashinfer), MoE **`offload`**, cache **`hybrid_radix`**,
  tool-call parser **`qwen3_coder`**, reasoning **`qwen3`**, sampling from the
  checkpoint (**temp 1.0, top_k 20, top_p 0.95**), 20.94 GiB VRAM free. So the CUDA
  *runtime* works; the missing toolkit is not what blocks serving.
- **Hard blocker at weight load: `cudaHostRegister failed for 0.2 GiB`.** The
  offload backend pins the FP8 expert banks (`moe/host_banks.py` pin-after-fill).
  WSL's **memlock limit is 64 MB (soft AND hard)**, so pinning 0.2 GiB banks fails
  and the backend worker dies. There is **no pageable fallback** — the enum exists
  but `moe/offload_cache.py:281` says "platform-specific residency policies are not
  implemented", and the gather kernel reads host memory zero-copy so pinning is
  mandatory. No FreeToken flag/env avoids it.

### Two sudo-gated prerequisites remain (cannot be done without the user's password)

1. **Raise memlock** (the blocker that killed the load):
   ```
   echo '* soft memlock unlimited' | sudo tee -a /etc/security/limits.conf
   echo '* hard memlock unlimited' | sudo tee -a /etc/security/limits.conf
   ```
   then a NEW WSL shell (or `wsl --shutdown` + reopen); confirm `ulimit -l` = `unlimited`.
2. **CUDA 13 toolkit** for the PCIe-gather kernel (bench proved it missing; decode
   will need it):
   ```
   wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
   sudo dpkg -i cuda-keyring_1.1-1_all.deb
   sudo apt-get update && sudo apt-get install -y cuda-toolkit-13-0
   echo 'export CUDA_HOME=/usr/local/cuda-13.0' >> ~/.bashrc
   echo 'export PATH=$CUDA_HOME/bin:$PATH' >> ~/.bashrc && source ~/.bashrc
   ```

`bootstrap.sh` now checks both and prints these as warnings (no longer a hard nvcc
gate, since install + serve-init work without it).

## Still to measure (after the two sudo fixes)

- Qwen3.6-35B-A3B-FP8: does it fully load + serve a token once memlock is raised and
  CUDA_HOME is set? `offload` t/s, and A/B vs the llama.cpp `Qwen3.6-35B-A3B` (q8_0)
  router entry.
- gpt-oss-120b: whether ~61 GB experts hold in RAM at `.wslconfig memory=44GB`
  (host 48 GB) without SSD paging, or OOM. Watch `ft ctl stats`.
- Does `auto` upgrade `offload` → `hybrid` once the PCIe-gather bench can run with a
  real CUDA_HOME?
