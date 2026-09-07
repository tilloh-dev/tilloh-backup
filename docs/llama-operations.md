# llama.cpp operations — cross-model measurements and hermine hardware
> Extracted verbatim from AGENTS.md on 2026-08-15. "Above/below" references may point
> to sibling files in this directory or back to AGENTS.md.

## config-load.sh precedence and the CRLF fall-through

Config in `config.env` (gitignored; copy from `config.env.example`). On the Windows host there is no `config.env` — it configures itself in `config.ps1` (also gitignored, and it holds a plaintext `HF_TOKEN`). All four bash entry points therefore load their settings through `config-load.sh`, which resolves env var > `config.env` > `config.ps1` > `config.env.example`. Before that existed, `server.sh`, `download-model.sh` and `bootstrap.sh` were **completely broken on hermine** (verified 2026-08-05): they fell through to `config.env.example`, which carries CRLF, and `source` then fails on every line with `$'\r': command not found`. Falling through was wrong twice over — that file also assigns a Linux models path and `LLAMA_BACKEND=vulkan`, so a working `source` would have pointed at a nonexistent directory and fetched a Vulkan build for a CUDA box. `recommend.sh` keeps its own copy of this logic on purpose: it must run standalone from the skill directory.

## server.sh on hermine: the two defects

`server.sh` could not actually **serve** on hermine until 2026-08-05, only `--list`. Two separate defects, both found by running it: `resolve_bin` searched for `llama-server` and not `llama-server.exe`, and once that was fixed the Windows binary got the POSIX `/mnt/c/...` models dir and died with `does not exist or is not a directory`. Paths handed to an `.exe` now go through `host_path()` (`wslpath -m`) while bash keeps the POSIX form for its own `find`/`-f` tests. Verified end-to-end: the router logs `Loaded 8 custom model presets` and `/v1/models` lists all eight (plus one entry from llama.cpp's own HF cache, which is not ours).

## fit = off survey

`fit = off` is set in **all twelve** sections of both preset files, but it is only *load-bearing* in `Ornith-1.0-35B`, where `fit = on` silently moves MoE experts to CPU and costs ~30 %. Measured elsewhere it is a no-op: gemma-4-31B and Qwen-AgentWorld show no `tensor overrides to CPU` either way. It is set uniformly so a VRAM shortfall fails loudly instead of silently switching to a slower configuration — before 2026-08-05 it was present in 4 of 8 sections purely by accident of which ones had been touched.

## WSL-on-Windows traps

Two WSL-on-Windows traps when testing a server by hand on hermine, both cost a wasted run: `--host 127.0.0.1` binds the *Windows* loopback and is unreachable from WSL (use `0.0.0.0` plus the gateway IP from `ip route`; the name `hermine` does **not** resolve from inside WSL on hermine itself, only from the LAN). And `nohup ./llama-server.exe &` returns the *bash* PID — `taskkill /PID` on it leaves the Windows process alive holding VRAM, which then makes the next start fail with `failed to load draft model`. Kill by image name (`taskkill /F /IM llama-server.exe`) and wait for `nvidia-smi` to drop — but **only when no other llama-server is meant to stay alive**: killing by image name also takes down the user's router. When one is running, get the PIDs from `tasklist.exe` before starting a test instance and kill only your own.

## GT 610 display GPU and the legacy-driver conflict

**hermine drives its display from a GT 610 since 2026-08-15; the 4090 idles at ~22–44 MiB.** Every VRAM figure in this file measured before that date sat on a 394–1172 MiB desktop baseline, so old "free VRAM" numbers understate what fits today — re-measure before trusting them at the margin. The install itself broke the machine first, and the fix is worth recording because Windows Update *will* try to reproduce the breakage: the GT 610 is Fermi, its last driver line is 388/391, and WU auto-installed `nv_ref_pubwu.inf` (388.13) on detection. Windows cannot load two NVIDIA KMDs, so the 4090 went to Code 31 (later 39) and `llama-server --list-devices` reported *no devices at all* — while `device = CUDA0` in the presets was never the problem and still names the 4090 (the GT 610 has no CUDA support and is invisible to llama.cpp; there is nothing to pin). Fix, verified: `pnputil /delete-driver oemXX.inf /uninstall` on the legacy package (it was `oem118.inf`; re-enumerate with `pnputil /enum-drivers`, the giveaway is `nv_ref_pubwu.inf` + version 23.21.13.8813), reboot; if the 4090 then shows Code 39, `pnputil /remove-device "<instance-id>"` + `pnputil /scan-devices` rebinds it to the store's modern driver (`nv_dispi.inf`) without any download. Target state in Device Manager: 4090 = NVIDIA driver OK, GT 610 = **Microsoft Basic Display Adapter** — never install an NVIDIA driver for the GT 610. If the 4090 dies again after a WU cycle, it is this, same fix.

## CUDA KV-cache pairing rule

On CUDA (hermine), `cache-type-v` MUST equal `cache-type-k`. Measured 2026-08-04 with gemma-4-31B @ 65536 + MTP: matched `q8_0`/`q8_0` yields 2391 t/s prompt / 86 t/s generation, the mixed `q8_0`/`q4_0` pair collapses to 32 t/s / 9 t/s because it falls off the fused FlashAttention kernel. Untested on Vulkan (lieselotte), whose presets still use the skill's `q8_0`/`q4_0` floor — so the llama-preset skill's V-floor is not safe to apply blindly on the CUDA box.

## spec-type / ngram-mod / cache-ram

`spec-type` carries `ngram-mod` in **every** section of both `presets/models.ini` and `presets/models.example.ini` (12 each) — as `draft-mtp,ngram-mod` where an MTP drafter exists, as `draft-dflash,ngram-mod` for Muse-Glimmer, as bare `ngram-mod` where none does (both Ornith, Qwen-AgentWorld, Laguna) or where one exists but measured slower (Nemotron-3.5-Lightning). It needs no draft model and no VRAM, and speculative decoding is lossless, so a bad fit costs speed and never output quality. The gain is **unmeasured on both machines** — adopted from countzero's 24 GB preset on mechanism. Expect it to pay off on file-rewrite-heavy agent turns and to do nothing on novel prose, where the 48-token minimum chain length suppresses the draft entirely. `cache-ram = 16384` is set on hermine's four agentic-coding sections (both Qwen3.6, Laguna, Muse-Glimmer) and nowhere else: the default is 8192, the box has 39 GB, and the value applies **per loaded model**, so raising `models-max` above 1 multiplies it.

**First measured counterexample to the ngram-mod default (2026-09-03):** on Qwen3.8-Flash-Next
(RPC + CPU experts, card sampling `temp = 1.0`) ngram-mod drafted 192 / accepted 8 (4 %) and
made even a verbatim-repetition prompt slower (8.2 vs 8.9 t/s), so its section carries no
`spec-type` at all. High-temperature sampling collapses speculative acceptance — check
`draft_n_accepted/draft_n` in the response timings before crediting any speculator on a
temp-1.0 model. Details: `docs/models/Qwen3.8-Flash-Next.md`.

## cache-reuse is inert

`cache-reuse` is **inert on this llama.cpp build (10243) — everywhere, not per model.** Every load logs `cache_reuse is not supported by this context, it will be disabled`. Measured 2026-08-05 across four architectures (gemma4 dense 31B, gemma4 MoE 26B-A4B, qwen35 dense 9B, Qwen3.6-27B) and, on the 9B, across five flag combinations: with speculative decoding, without it, `-fa off`, KV `f16` instead of `q8_0`, and `--kv-unified`. All disabled. So it is neither the hybrid-attention architecture nor speculative decoding nor FlashAttention, as was assumed twice before this was tested properly. The key is still written into every section because it costs nothing and would start working on a build that supports it — but do not credit it with anything, and do not let the llama-preset skill's description of it ("reuses cached KV for repeated prefixes across turns") be read as a statement about this machine.

## models.ini comment policy — discovery

**`presets/models.ini` is kept comment-free — the user deletes `#` comments from it on sight** (global AGENTS.md register rule: a comment must say something the keys cannot; a machine-local working file is not documentation). Any rationale a section needs goes into `models.example.ini` (tracked, comment-friendly) and the model's bullet in this file. Discovered 2026-08-15 when freshly written NOTEs vanished from `models.ini` and a server-rewrite hypothesis was disproven by the user simply saying they had deleted them; the same mechanism explains the Nemotron NOTEs that this file once claimed existed.

## `latest` tag resolution — the v0.3.0 break

Both bootstrap scripts resolved `LLAMA_VERSION=latest` via `GET /repos/ggml-org/llama.cpp/releases/latest` and used the returned `tag_name` directly. That broke on **2026-08-30**: `.\bootstrap.ps1` died with `curl exit 22` / HTTP 404 on `llama-v0.3.0-bin-win-cuda-12.4-x64.zip`. Cause is upstream, not local — ggml-org now publishes the per-commit build tags (`b<number>`) that carry the binaries as **prereleases**, so `/releases/latest` returns a semver release (`v0.3.0`) whose **only** asset is `nightly-tag.txt`, a one-line pointer to the blessed build tag (contents at discovery: `b10621`). The asset naming itself is unchanged.

Fixed in both `bootstrap.ps1` (`Resolve-Tag`) and `bootstrap.sh` (`resolve_tag`), same three-step ladder: use `tag_name` if it matches `^b[0-9]+$`; otherwise read the release's `nightly-tag.txt`; otherwise take the newest tag matching `^b[0-9]+$` from `/releases?per_page=20`. The pointer is preferred over the newest prerelease deliberately — it is upstream's own choice of a stable nightly, and `/releases?per_page=20` moves roughly every 20 minutes (ten builds published within 3 h on the day of the fix). Verified 2026-08-30: resolves to `b10621`, and `llama-b10621-bin-win-cuda-12.4-x64.zip`, `cudart-llama-bin-win-cuda-12.4-x64.zip` and `llama-b10621-bin-ubuntu-vulkan-x64.tar.gz` all return HTTP 200. The download+extract path was not re-run end to end on hermine.

## The nightly pointer can lag behind an arch merge — pin, or auto-update downgrades you

Consequence of the pointer preference above, hit **2026-09-03**: Qwen3.8-Flash-Next needs arch
`qwen4exp` (merged 2026-08-27, follow-up fixes 2026-09-01), but `nightly-tag.txt` still pointed
at **b10621 (2026-08-25)** — a build from *before* the merge, failing with
`unknown model architecture: 'qwen4exp'` while builds up to b10766 were already published.
Two implications: (1) to run a freshly merged arch, pin `LLAMA_VERSION="b<number>"` in
`config.ps1`/`config.env`; (2) the pin is **load-bearing against downgrade** — the server
scripts' auto-update check resolves `latest` through the pointer, so an unpinned restart would
reinstall the older blessed build and silently break the model. Un-pin once the pointer moves
past the needed build. Same day, `config-load.sh` and `bootstrap.ps1` gained env-var precedence
for `LLAMA_VERSION` (previously only `LLAMA_MODELS_DIR`/`LLAMA_PRESET` survived config
sourcing), so a one-shot `LLAMA_VERSION=b10766 bash bootstrap.sh --force` now works as the
documented env > config precedence always claimed. Note: `bootstrap.ps1` must be run with
**pwsh** (PowerShell 7) — Windows PowerShell 5.1 misparses the file's UTF-8 em-dashes without a
BOM and dies with parser errors.

## RPC: pooling lieselotte's 7900 XTX into hermine's server

First multi-machine load (Qwen3.8-Flash-Next, 2026-09-03, both ends b10766): official prebuilts
ship `ggml-rpc-server(.exe)` + `libggml-rpc`/`ggml-rpc.dll` (verified in both the win-cuda and
ubuntu-vulkan b10621/b10766 archives). lieselotte runs
`vendor/llama.cpp/ggml-rpc-server -H 0.0.0.0 -p 50052 -d Vulkan0 -c`; hermine's section carries
`rpc = 192.168.1.39:50052` and sees the card as `RPC0` (use the IP — `hermine`-style hostnames
are unreliable across the WSL/Windows resolver split). Findings:

- `-d <GPU>` on the rpc-server keeps the remote CPU out of the pool (experts belong in the
  *host's* RAM, not behind the LAN); `-c` caches shipped tensors on the remote disk — without
  it every model load re-transfers ~19 GB.
- `llama-fit-params` and `llama-server` both accept `--rpc` (env `LLAMA_ARG_RPC`); fit-params
  emits a ready `-ngl/-ts/-ot` combination for the pooled devices. `recommend.sh` predates RPC:
  its device table only shows local devices and it misreads split GGUFs (sees the 10 MiB first
  shard, calls a 125B MoE "dense", derives the section name from the quant subdir) — for RPC
  models, run fit-params by hand and use the script only as checklist.
- **Do not set a `device` key for an RPC-split model** unless the split values were computed
  under that explicit order: `device = CUDA0,RPC0` alone collapsed generation 8.4 → 2.9 t/s
  against the identical implicit-enumeration config (isolated single-flag A/B; details and the
  full ladder in `docs/models/Qwen3.8-Flash-Next.md`).
- RPC protocol: no auth, no encryption, version-matched builds on both ends. LAN only.
- **The RPC pipeline has a measurable fixed sync cost per token, and speculative decoding is
  how you buy it back** (Qwen3.8-27B UD-Q8_K_XL, 2026-09-04, b10786): a 3-point `-ts` sweep
  solves to XTX ≈ 0.87 ms/block + 4090 ≈ 0.55 ms/block + **~10 ms/token fixed** (the #22850
  sync tax; rebalancing layers is a ±0.3 t/s dead end). Speculation at the twins' defaults
  (n-max 3, p-min 0) measures at or *below* no-spec — each verify round pays the LAN hops
  regardless of batch size — but **confidence-gated long drafts invert it**: sidecar drafter
  pinned via `device-draft = CUDA0` (mandatory — embedded MTP re-serializes the RPC graph and
  stays slower) with `spec-draft-n-max = 6` + `spec-draft-p-min = 0.5` lifts prose 17.4 →
  27–32 and rewrites 26.7 → 44–48 t/s (/completion probes; chat endpoint with thinking:
  20.5–22.9 / 36.9, tg@14k 16.2 → 27.6). Both knobs isolated as individually insufficient.
  ngram-mod also measured its first win here (0.92 acceptance on verbatim rewrites). Also
  measured: asymmetric `fit-target` and `-ub 2048` each collapse tg ~40 % (fit placement is
  config-sensitive). Details: `docs/models/Qwen3.8-27B.md`.
- Router mode passes INI keys through to spawned instances verbatim, including an
  `override-tensor` regex containing `=` and `,` — no quoting issues (verified via spawn log).

## Windows RAM notes (hermine, 2026-09-03)

`Win32_ComputerSystem.TotalPhysicalMemory` reports 63.8 GiB. During the mlock'd
Qwen3.8-Flash-Next run Windows still showed 34.3 GiB free although the nominal host share is
~45 GB — consistent with lazy n-gram-table reads (upstream #28256) rather than full residency.
The Windows shell's 4090 baseline has grown again: 977 MiB used at idle (was ~241 MiB after the
GT-610 swap) — re-check `nvidia-smi` before margin-critical loads.

## hermine host hardware (measured 2026-09-07, first time on record)

CPU: i9-13900KF — 8 P-cores + 16 E-cores, 24 cores / 32 threads. RAM: 2× 32 GB G.Skill
DDR5-6000, XMP active (ConfiguredClockSpeed = 6000). Dual-channel DDR5-6000 ≈ ~96 GB/s
theoretical, ~70–80 real. Relevant because Flash-Next-class CPU-MoE decode is host-RAM-bound
(~2–2.5 GB expert reads/token → ~30 t/s physical ceiling on this box) and because ggml's
spin barriers make E-cores gate P-cores: `threads = 8` (P-only) measured fastest for CPU-MoE,
12/16/24 all slower (see docs/models/Qwen3.8-Flash-Next.md, 2026-09-07 retune).

## Router auto-discovery: where the `unsloth/gemma-4-E4B-it-GGUF:Q4_K_XL` entry comes from (2026-09-07)

The router lists models from **three** sources, not just `models.ini`: custom presets (INI),
local presets (`--models-dir` scan), and **"cached model presets"** — auto-discovered entries
from llama.cpp's HF model cache (`LLAMA_CACHE`, default `~/.cache/llama.cpp` / Mac
`~/Library/Caches/llama.cpp` / Windows `%LOCALAPPDATA%\llama.cpp`). The gemma-4-E4B entry is
such a cache remnant (someone once ran `-hf unsloth/gemma-4-E4B-it-GGUF:Q4_K_XL`); the
router's `/models` endpoint confirms it: `"source": "cache"`, `"can_remove": true`, status
`unloaded` — it is **inert** until explicitly requested, at which point the router would
(re-)download it from HF. RESOLVED same day (user found the path via WebUI after loading the entry): the cache is the
**standard HuggingFace hub cache** `C:\Users\Anwender\.cache\huggingface\hub\models--unsloth--gemma-4-E4B-it-GGUF`
(12 GB, full snapshot layout) — newer llama.cpp builds share the HF hub cache instead of a
llama.cpp-own directory; the hub cache also holds unrelated FLUX image models, so never clear it
wholesale. Deleting the one `models--…` directory removes the router entry (after router
restart). Historical note, superseded: the actual cache file could not initially be located
(`%LOCALAPPDATA%\llama.cpp` holds only `models/`, Windows-home `.cache` does not exist,
`LLAMA_CACHE` is unset in the configs) — possibly a metadata-only manifest somewhere not
searched, or reconstructed from a source b10786 does not surface. The remove API apparently
does not exist yet on b10786 (`DELETE /models/<id>`, `DELETE /v1/models/<id>`,
`POST /models/remove` all 404) despite `can_remove: true` — likely WebUI/newer-build
functionality. Options if the entry should go: check the router WebUI for a delete control,
retry the API after the next build update, or pin `LLAMA_CACHE` to an empty gitignored dir in
`server.sh`/`server.ps1` so cache discovery is deterministic (models would then be managed by
`models.ini` only — not done, user decision).

