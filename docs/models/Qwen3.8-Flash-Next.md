# Qwen3.8-Flash-Next

Qwen3.8-Flash-Next (Qwen team, arch `qwen4exp`, 49 layers) is the first open-weight release of
the architecture behind Qwen4: a **125B-parameter multimodal MoE with 6B active per token**
(512 experts, 10 routed + 1 shared) plus **51B additional n-gram embeddings** that llama.cpp
keeps host-side, and an embedded 1-layer MTP head. Native ctx 262144 (1M via YaRN, not
configured here). Hybrid attention (Gated DeltaNet + Qwen Sparse Attention) → KV is nearly
VRAM-free, same family behaviour as Qwen3.8-27B / Ornith-1.5. Quant: **unsloth UD-IQ3_XXS**
(82 GB, 3-way split GGUF) + `mmproj-F16.gguf`. The surviving numbers were measured on **hermine**
(RTX 4090) alone, llama.cpp build **10786**; the earlier RPC-pooled figures were removed, see below.

## RPC-era measurements (2026-09-03/04) — removed 2026-09-22

Everything this model was originally documented with came from pooling hermine's 4090 with the
7900 XTX over RPC while that card sat in `lieselotte` (i9-14900K host): the fit-params split
(`-ngl 49 -ts 19,30` plus the `override-tensor` regex), the `device`-key collapse 8.4 → 2.9 t/s,
the `load-mode = mlock` prefill A/B, the 2026-09-03 lever list, the RPC graph-reuse and
PLE-gather code findings, and the RPC-era throughput (pp 176–237, tg 8.5 t/s). The card has
moved into `Gertrude` (i9-9900K, 31 GB RAM), lieselotte has no GPU any more, and the host RAM,
CPU topology and LAN path those numbers depended on no longer exist in that combination — so
they were deleted rather than carried forward. The preset itself was already removed 2026-09-21
(76 GiB against 24.5 GB VRAM + 31 GB RAM on Gertrude, ~1.2 t/s).

**What still stands is the no-RPC retune below** (2026-09-07, hermine-local): that config was
measured without the second machine and is unaffected by the move.

## Sampling and reasoning

Card publishes two whole sets; **thinking set adopted whole** (`temp 1.0, top-p 0.95, top-k 20,
min-p 0.0, presence-penalty 0.0`), same reasoning as Qwen3.8-27B (`docs/models/Qwen3.8-27B.md`).
Template scan: thinking on by default, template consumes `reasoning_content` from history →
`reasoning-preserve = true` (build 10766 auto-enables it for this template and logs that; the
key documents intent). `cache_reuse` is disabled at runtime by multimodal, same as Qwen3.8-27B.
`reasoning-format = auto` separation verified live (reasoning_content populated, content clean).

**Vision verified live** (2026-09-03, router on b10784): a 128×128 half-red/half-blue test PNG
sent as OpenAI `image_url` was described correctly and precisely. `mmproj-offload = false`
keeps the encoder on CPU (no VRAM cost; encode time untested for large images). The throughput
figure from that run was RPC-era and has been dropped.

## Not adopted / open

- **MTP drafter: blocked upstream, tested 2026-09-03.** Both unsloth drafter variants are on
  disk (`MTP/mtp-...-shared-Q8_0.gguf` 2.6 GB, `MTP/mtp-...-Q8_0.gguf` 3.9 GB) and both fail to
  load on b10766: the shared one with `tensor 'token_embd.weight' not found` (embedding
  borrowing unsupported), the self-contained one with `tensor 'output_hc_norm.weight' not
  found`. Cause: qwen4exp MTP support is **not merged** — open PRs #27836 (draft head),
  #28097 (unsloth draft-head-only layout + draft-load regression), #28243. Official-builds-only
  policy → wait for the merge, re-pin the build, then measure `-md <shared-Q8_0>
  --spec-type draft-mtp,ngram-mod --spec-draft-n-max 2` (unsloth's recommendation). The family
  "MTP is slower" precedent does **not** transfer here: those targets were fast and
  GPU-resident, while this one pays ~2 LAN hops + CPU-expert reads per token — exactly the
  fixed cost a verified draft batch amortizes, so the card's 1.3–1.7× claim is plausible or
  conservative for this setup. Also relevant once it works: #28286 (draft-mtp + `parallel > 1`
  cross-slot contamination; this section runs `parallel = 1`).
- **ngram-mod measured and removed** (2026-09-03): four-field A/B (with/without ngram-mod ×
  prose/verbatim-repetition prompt) showed no gain on prose (8.4–8.7 vs 8.6 t/s) and a *loss*
  on the ngram-ideal repetitive prompt (8.2 vs 8.9 t/s) with **draft acceptance 8/192 = 4 %**.
  Plausible mechanism: the card's `temp = 1.0` sampling makes speculative acceptance collapse,
  and the thinking preamble is never repetitive. The section carries **no `spec-type`** — the
  usual "lossless, keep on mechanism" default is measured harmful here. Re-check acceptance if
  the sampling set ever changes. DFlash (`draft-dflash`) is supported by the build but no
  DFlash drafter exists for this model on HF — nothing to wire.
- **Upstream to watch**: PR #28136 (lazy PLE direct reads, >2× prefill claim), #28244/#28213
  (sparse-attention decode), issue #28266 (multi-turn collapse on HIP/gfx1100 — the XTX runs
  Vulkan, not observed here, untested long-run).
- **OpenCode providers**: not yet added to `opencode.jsonc` — hermine-only ID would break the
  "both providers list the same IDs" convention; user decision pending.

## No-RPC retune (2026-09-07, build 10786): RPC dissolved, tg doubled, hermine-only

**User decision 2026-09-07 supersedes the 2026-09-03 "RPC setup is fixed" decision**: the RPC
pooling is dissolved and the section now runs on hermine alone. Trigger was a community video
(RTX 3060 12GB / 6-core Ryzen / 61 GB DDR4) reaching 24.4 t/s on this model class with two
levers: threads = one per *physical* core (12-thread SMT run spent 65 % in spin-waits), and
letting mmap leave the 51B n-gram table on the SSD. Both transfer to hermine (i9-13900KF:
8P+16E, 24 cores/32 threads; 63.8 GB RAM; E: NVMe).

Measured ladder (same probe suite as the rest of the repo; prose = short 400-tok tg,
deep = 19.3k-prompt):

| Config (all: fit=on 1024,1024, ctx 261888, mmap, no RPC) | prose tg | pp @19.3k | tg @19.3k |
|---|---|---|---|
| RPC section (old, for reference) | 8.5–10.4 | ~236 (mlock) | 7.6 |
| local, threads default (24) | 18.5–21.6 | 219–236 | 20.6–20.7 |
| local, `-t 8 -tb 24` (P-cores only) | 20.3–24.7 | 233–239 | 22.7–22.8 |
| `-t 12` / `-t 16` | 18.5–19.6 / 19.8–21.4 | — | — |
| `-t 8` + `--prio 2` | 22.0–24.6 | — | — (neutral, not adopted) |
| `-t 8` + `-ub/-b 2048` | 14.6–16.2 | **496–512** | 15.5–15.8 |
| **`-t 8 -tb 24 -ub/-b 1024` (adopted)** | **20.0–23.1** | **366–377** | **22.4–22.7** |

Readings: (1) **dropping RPC alone doubled tg** — the pipeline-parallel idle + sync tax was
half the token time, as the 2026-09-03 analysis predicted ("RPC is a capacity play"). The
capacity problem RPC solved is covered by mmap: the n-gram table stays on NVMe (lazy), experts
page-cache into host RAM (Windows free RAM drops to ~3 GB under load — evictable page cache,
but the box has no RAM headroom for other big jobs while this model is hot). **No `load-mode`
key**: mlock would fight the 82-GB file on 64 GB RAM. (2) **threads = 8** (P-cores) beats 12/16/24
— the video's spin-wait lesson holds on hybrid Intel exactly as the 2026-09-03 lever list
suspected. (3) **ubatch/batch 1024** is the pp sweet spot: +56 % pp at zero tg cost; 2048
doubles pp but costs a third of tg because fit re-places experts around the larger compute
buffers. (4) `fit = on` stays load-bearing. (5) No build pin needed anymore — the pin existed
only for RPC build-pairing with the second machine. VRAM at load: 21.5–21.8 GB used (~1.2–1.4 GiB free);
router-verified (spawn, clean reasoning separation, 16.2 t/s on the cold first request).

Standing verdict vs the daily driver (`[Qwen3.8-27B]` GSQ @262k, 72–82 t/s): Flash-Next is now
**usable** (>20 t/s bar) at 3–4× fewer tokens/s but a 177B-class model at full 262k — the
challenger role is quality-per-token, not speed. MTP for qwen4exp remains an unmerged draft PR
(#27836, checked 2026-09-07) — the biggest known future lever; re-check upstream periodically.
The old RPC recipe above stays documented in case the capacity play is ever needed again
(e.g. a bigger quant).

## MTP tested via PR build (2026-09-08): loses on the CPU-expert topology despite 0.7–0.99 acceptance

User-requested one-off test of the unmerged qwen4exp-MTP support, **without touching vendor/**:
unsloth's prebuilt **b10830-mix** (upstream b10830 + their PR #144 "MTP for Qwen3.8-Flash-Next",
self-contained Windows-CUDA-12 zip) extracted to `E:/Llama.cpp/test-builds/b10830-mix/` — a
fork build used for measurement only, never wired into presets (official-builds policy intact).
Shared-Q8_0 sidecar drafter from disk; the standing tuned local config as base
(`-t 8 -tb 24 -ub/-b 1024`, fit=on, ctx 261888).

| Run (same probes as the 09-07 retune) | prose tg | tg @19.3k | notes |
|---|---|---|---|
| A: mix build, no MTP (control) | 19.9–22.1 | 22.7–22.9 | b10830 ≈ b10786, no drift |
| B: draft-mtp n-max 2, fit-target 1024 | 1.3–17.9 (wild) | 12.9–14.1 | fit could not pre-measure the shared drafter ("fitting without it") → only ~570 MiB free → sysmem spill |
| B′: same + fit-target 4096 | 10.6–22.5 (unstable) | 7.0–19.1 | ~920 MiB free; acceptance 0.56–0.99 |
| C: PR recipe — n-max 3, p-min 0.7, `--spec-draft-backend-sampling`, env `LLAMA_STATE_SEQ_FLAGS_ON_DEVICE=1` | 15.6–17.7 | 13.9–15.5 | ~1.1 GiB free; acceptance 0.70–0.99, mean len up to 3.98; only verbatim rewrite2 (27.6) beat baseline. Whether the env flag reached the Windows process is unverified (no log echo) |

**Verdict: net loss vs the 22.8 t/s no-spec baseline in every configuration**, with *excellent*
acceptance — the drafts are good, the verify step is what costs. Mechanism (consistent with the
3060 community video: "bought less than one token — the bottleneck is the CPU side, and a draft
head doesn't change that"): on a **RAM-bandwidth-bound CPU-expert MoE, a verify batch of n
tokens reads ~n× the expert weights** (each token routes to different experts), so speculative
decoding amortizes nothing here — unlike dense GPU-resident targets, it only adds draft
overhead. The 2026-09-03 prognosis in this file ("plausible or conservative for this setup")
was written for the *RPC* topology (fixed per-token sync cost to amortize) and does **not**
transfer to the local CPU-MoE topology. Consequence: **when qwen4exp-MTP merges upstream, do
not adopt it for this section** — it stays interesting only for GPU-resident qwen4exp targets
(or a future config where the experts live in VRAM). The test build stays in
`E:/Llama.cpp/test-builds/` (delete freely; ~700 MB unpacked).

### Addendum (2026-09-08, same day): the PR's on-device-state fix does NOT rescue MTP here

The PR discussion contains a 6-line fix (JayToltTech/llama.cpp#1: OR `LLAMA_STATE_SEQ_FLAGS_ON_DEVICE`
into the spec-checkpoint update/load calls in `server-context.cpp`) that took a 3090 + `--n-cpu-moe 40`
rig from 11.0 → 17.7 t/s (+61 %, break-even vs its 17.0 baseline). Note: runs B/C above used it as an
*env var* — it is a **code change**, so run C never actually tested it. Tested properly on user request:
VS 2022 Build Tools + CMake/Ninja installed on hermine (winget; the box now has a full Windows-CUDA
build toolchain — MSVC 19.44 + CUDA 13.2, `CMAKE_CUDA_ARCHITECTURES=89` builds llama-server in ~15 min),
b10840-mix source + patch built to `E:/Llama.cpp/test-builds/src/build/bin/`.

Result (same-hour control, creep baseline ~2.1 GB): **no-MTP control 19.4–21.7 prose vs MTP+fix
14.2–15.0 prose / 11.9–18.8 @19.3k** — acceptance again 0.74–0.99. The fix does not close the gap on
this box: after removing the checkpoint cost, a large verify-side cost remains, consistent with the
n×-expert-reads mechanism above (and with the PR comment "per-round checkpoint alone cannot explain
the remaining gap"). The PR's recommended pairing — this fix **plus** a hot/cold expert-residency
split (timadinorth/llama.cpp#1) for 24–26 t/s on the 3090 — is a fork-only expert cache, closed by the
official-builds policy. **Verdict unchanged: do not adopt qwen4exp-MTP for this section when it merges**;
revisit only if an expert-residency mechanism lands upstream. Patched test build kept in
`E:/Llama.cpp/test-builds/src/` (source + build dir, deletable).

## Chat template: `chat-template-file` override since 2026-09-14

The embedded template raises `System message must be at the beginning.` for any
system message that is not `messages[0]`, which Claude Code trips on every turn
(it appends a trailing system message with the agent-type list). The preset
therefore points `chat-template-file` at the patched copy under
`llama.cpp/presets/templates/`; rendering is byte-identical for all other
message shapes. Capture, affected-model table and the verification run:
`docs/llama-operations.md`.
