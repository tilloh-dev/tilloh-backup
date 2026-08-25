# FreeToken on hermine (WSL2)

Config-driven setup to run frontier **MoE** models with
[FreeToken](https://github.com/FlashML-org/FreeToken) — an edge-native MoE
serving engine that keeps experts in host RAM and streams them to the GPU, so a
24 GB card can serve models that do not fit in VRAM. Sibling of `../llama.cpp/`,
same ergonomics; the differences all come from FreeToken not being llama.cpp.

## Why this is WSL-only (no `.ps1`)

FreeToken ships **Linux-only wheels** (`manylinux`, `triton` gated to
`platform_system=="Linux"`); its docs require *Linux x86_64, NVIDIA driver r580+,
CUDA 13*. There is **no native-Windows path** — on hermine it runs in **WSL2**.
That is the one hard reason the layout drops the Windows/CUDA `.ps1` half that
`llama.cpp/` carries.

| Aspect | `llama.cpp/` | `freetoken/` |
|--------|--------------|--------------|
| Install | prebuilt release tarball → `vendor/` | Python venv, `uv pip install "freetoken[accel]"` |
| GPU backend | Vulkan (.sh) / CUDA (.ps1) | CUDA-only, WSL2 (RTX 30/40/50) |
| Models | single `*.gguf` | full HF checkpoint **directory** (safetensors) |
| Multi-model | router + INI preset | **none** — one `ft serve` = one model / port |
| API | OpenAI | OpenAI **+ Anthropic** |
| Extra step | — | `ft bench bw` (per-GPU MoE calibration) |

## Layout

```
freetoken/
├── bootstrap.sh        # venv + freetoken[accel] + CUDA gate + ft bench bw
├── download-model.sh   # snapshot HF checkpoint repos into $FT_MODELS_DIR
├── server.sh           # ft serve for one preset/model
├── config-load.sh      # env > config.env > config.env.example (CRLF-safe)
├── config.env.example  # copy to config.env and edit         [committed]
├── config.env          # your real values                    [gitignored]
├── models.list         # repo_id | dest_subdir               [committed]
├── presets/            # one <name>.env per model            [committed]
│   ├── qwen3.6-35B-A3B.env
│   └── gpt-oss-120b.env
└── .venv/              # the FreeToken install                [gitignored]
```

Models live under `$FT_MODELS_DIR` (default `~/.local/share/freetoken/models`),
**outside** this repo, never committed.

## Prerequisites (hermine / WSL2)

- NVIDIA driver r580+ visible in WSL (`nvidia-smi`). hermine: 610.88 ✓
- **memlock limit `unlimited`** (root, one-time). WSL defaults to 64 MB, which is
  too small to pin the offload expert banks — serving dies with `cudaHostRegister
  failed`. Fix: append `* soft memlock unlimited` and `* hard memlock unlimited`
  to `/etc/security/limits.conf`, then reopen WSL. `bootstrap.sh` warns if unset.
- **CUDA 13 toolkit with `nvcc` / `CUDA_HOME`** — install + `ft serve` init work
  without it, but the offload PCIe-gather kernel needs it at decode. `bootstrap.sh`
  prints the install commands if missing.
- `uv` and Python ≥ 3.10 (uv provisions its own 3.12 for the venv).
- For **gpt-oss-120b** raise WSL RAM first: set `memory=44GB` in
  `C:\Users\<you>\.wslconfig`, then `wsl --shutdown` and reopen. See that preset's
  header — it is a tight fit on a 48 GB host and may still spill.

## Quick start

```sh
cd ~/tooling/freetoken
cp config.env.example config.env         # set port / paths / default preset
bash bootstrap.sh                        # venv + install + calibrate

bash download-model.sh --all             # or: download-model.sh <repo> [subdir]
bash server.sh                           # serves $FT_PRESET (default: Qwen3.6-35B-A3B)
# or a specific model:
bash server.sh gpt-oss-120b
```

Verify (second terminal):

```sh
curl http://127.0.0.1:1919/v1/models
.venv/bin/ft ctl stats                   # throughput, VRAM, pool occupancy
```

## OpenCode

A `freetoken` provider is wired in `../opencode-backup/opencode.jsonc`
(`baseURL http://hermine:1919/v1`). Model ids there are the `--served-model-name`
values (`Qwen3.6-35B-A3B`, `gpt-oss-120b`). `ft launch opencode` is **not** used —
it would rewrite the live config instead of the repo-managed backup.

## Notes

- One `ft serve` per model. To run both at once, give them different ports
  (`FT_PORT=1920 bash server.sh gpt-oss-120b`).
- `--moe-backend auto` resolves to `offload` for MoE and to `hybrid` when the
  `ft bench bw` profile (`~/.cache/freetoken/benchbw/<gpu-uuid>.json`) recommends it.
- Measured throughput / fit numbers belong in `../docs/freetoken-operations.md`,
  not here.
