# Qwen3.8-27B
> Extracted verbatim from AGENTS.md on 2026-08-15. "Above/below" references may point
> to sibling files in this directory or back to AGENTS.md.

Qwen3.8-27B (Qwen/unsloth, Apache-2.0, dense VLM, arch `qwen35`): dense 27B, 64 layers per the card (66 in the GGUF), hybrid layout `16 × (3 × Gated-DeltaNet → FFN → 1 × Gated-Attention → FFN)` — only 16 layers carry a growing KV cache (4 KV heads, head dim 256), native 262144 ctx (extensible to 1M via static YaRN, not set: the card itself warns it degrades short texts). `IQ4_XS` is 14978 MiB, plus `mmproj-F16.gguf` (927 MB) wired with `mmproj-offload = false` (host RAM) — genuinely multimodal, unlike the two gemma sections.

**The MTP head is embedded in the main GGUF although the repo name carries no `-MTP-`** — `qwen35.nextn_predict_layers` sits in the GGUF metadata (verified 2026-08-15 by strings on the header). `recommend.sh` missed it and proposed bare `ngram-mod`: its detection keys on the HF repo name or a sibling `mtp-*.gguf`, and neither exists here. Known script gap; the measurement below is why `draft-mtp` stays.

**MTP is a 1.85× win here — the opposite of Nemotron, because the target is dense.** Measured 2026-08-15 on hermine, build 10424, ctx 131072, KV `q8_0`/`q8_0`, `fit = off`, same short-prompt/400-token probe throughout: `draft-mtp,ngram-mod` with `spec-draft-n-max = 3` generates **78.1 / 76.5 t/s** (two runs, acceptance 0.57–0.59, mean draft length 2.71–2.77 — the budget of 3 is nearly saturated); **`spec-draft-n-max = 4` measured 62.0 t/s** (acceptance collapses to 0.347), so the inherited 3 stays and 4 is measured-worse, unlike gemma-4-26B-A4B where 4 saturates; bare `ngram-mod` gives **42.3 t/s**. A dense 27B target forward is expensive, so speculation pays — the Nemotron A3B logic inverts cleanly.

**`ctx-size = 147456` with KV `q8_0`/`q8_0` — the final state after a same-day detour through q4_0@229376, settled by measurement on build 10437 (user decision 2026-08-15).** After the GT 610 install freed the 4090 (see the display-GPU bullet under llama.cpp config notes), the first brief was "highest context with q4_0 KV": fit-params at `q4_0`/`q4_0` reports 196608 → 18677, 229376 → 19413, 262144 → 20149 MiB (excluding MTP), and real loads gave **262144 fails** (`cudaMalloc failed: out of memory` on a 1360 MiB compute buffer), **229376 loads at 22018–22243 MiB** (~785–1010 MiB free). Then the q8_0 counter-test on the same build erased the expected throughput difference — **q8_0@131072 and q4_0@229376 both measure ~58 t/s at 26.6k depth and 60–67 t/s on short probes** (acceptance ~0.35–0.50 in 8+ runs across both) — so the decision reduced to quality+margin vs. window, and q8_0 won on the user's quality weighting. The q8_0 ladder at the freed baseline: 131072 → 21497 MiB (1531 free), **147456 → 22141–22257 MiB (771–887 free)**, 163840 → **fails** (880 MiB MTP compute buffer OOM, so the open question from the earlier baseline is now closed — it does not load even with the card fully free). 147456 was chosen over 131072 after measuring that **an image request costs only ~70 MiB of VRAM** (22185 → 22257 MiB while processing a 896×896 PNG → ~800 visual tokens): with the mmproj on the CPU the margin is static — KV and compute are preallocated — so the Muse-Glimmer request-time-allocation risk does not apply to this section and the thin margin is text-and-vision-safe. Long-prompt at 147456: 2308 t/s prompt / 58.3 t/s generation.

**The embedded MTP context scales with ctx-size**: real-load overhead above the fit-params lower bound was ~1.85 GiB at 131072 and ~2.6 GiB at 229376, and it is what kills 262144 (q4_0) and 163840 (q8_0). **A suspected MTP regression or plain n=2 luck taints the older numbers**: on build 10424, q8_0@131072 measured 78.1 / 76.5 t/s with acceptance 0.57–0.59 (two runs); on 10437 the same configuration lands at 52–67 t/s with acceptance 0.27–0.49 (six runs), hardware ruled out (PCIe Gen4 x16, 2865 MHz SM, 327 W during generation). Nobody has re-run 10424 to separate the two explanations — do that before citing the 78 t/s anywhere. Short-prompt prompt-throughput figures (33–318 t/s) are noise; ignore them. The section pre-dating all this carried `ctx-size = 200000` at `q4_0` from the outside session. The server also prints `Qwen-VL models require at minimum 1024 image tokens … try --image-min-tokens 1024` — not set (the card does not mention it), but it is the first lever if vision grounding ever disappoints.

Sampling: the card publishes exactly **two** whole sets — thinking (`temp 1.0`, `top-p 0.95`, `top-k 20`, `min-p 0.0`, `presence-penalty 0.0`, `repetition-penalty 1.0`) and instruct (`0.7`/`0.80`/`1.5`). **No precise-coding set exists, unlike Qwen3.6** — do not import the 0.6 from the neighbouring section. The thinking set is adopted whole; the card's own agentic benchmarks (SWE-bench Pro, DeepSWE, QwenSWEBench) all ran `temp=1.0, top_p=0.95`.

**First section to set `reasoning-preserve = true`, and the Ornith precedent is satisfied rather than broken**: the card states "`preserve_thinking` is enabled by default for all workloads" and the embedded template was read directly — `enable_thinking is undefined or ... is true` → thinking on by default (no `reasoning = on` needed), and `{%- if preserve_thinking is undefined or preserve_thinking is true ...%}` renders thinking blocks for **all** history messages by default. The server accepted the flag with no warning. `reasoning_effort` (xhigh default) is a client-side template kwarg, not a preset key.

`cache-reuse = 256` is inert here with a **new** message on build 10424: `cache_reuse is not supported by multimodal, it will be disabled` — the blocker named on this model is the mmproj, not the context type as in the build-10243 findings below. Key kept, consistent with everywhere else. `load-mode = dio` and `kv-unified = true` arrived with the from-outside section and are carried as unmanaged keys.

## ubatch testing and the no-MTP full-context option (2026-08-15, build 10437)

**`ubatch-size` does not unlock anything here.** The community lever (leewsimpson: compute buffers scale with ubatch, ~370 MB per step) is real but has a context-driven floor on this model: the failing pp compute buffer at 262144/q4_0 + MTP shrinks only 1360 (ub 512) → 1192 (ub 256) → 1108 MiB (ub 128), so the load still OOMs at every ubatch. 163840/q8_0 + MTP at ub 256 fails even earlier (2394 MiB alloc) — conditions for that run were also worse than the day's earlier tests because Windows shell components (explorer.exe, TextInputHost) had claimed ~241 MiB on the 4090 by then (see the GT-610 bullet in AGENTS.md). Both OOM candidates stay dead.

**Full native 262144 loads only without MTP** (`spec-type = ngram-mod`, ub 512, q4_0/q4_0): 21241–21269 MiB, ~1.5–1.8 GiB free, VRAM static across a 102853-token prompt. Measured: short-probe generation **43.2 t/s** (matches the 42.3 no-MTP figure from build 10424 — the 10437 regression suspicion is MTP-specific), long prompt **1988.8 t/s** prompt eval and **32.9 t/s** generation at 103k depth. The trade against the standing 147456/q8_0+MTP preset: full native window and headroom, for −26 % short-context generation and q4_0-KV quality (post-Hadamard community evals call it near-FP — Lirezh, r/LocalAIStack; no local eval yet, llama-perplexity KLD would settle it).

## KV-cache KLD measurement (2026-08-15, build 10437)

llama-perplexity against an f16/f16-KV base (ground truth), wikitext-2 test, 2 chunks x 16384 tokens (32768 total), IQ4_XS weights, -fa on, all on hermine:

| KV pair | Mean KLD vs f16 | Top-1 agreement | RMS dp | PPL ratio |
|---------|-----------------|-----------------|--------|-----------|
| q8_0/q8_0 | 0.00387 +/- 0.00142 | 98.74 % | 1.65 % | 1.0009 |
| q4_1/q4_1 | 0.00737 +/- 0.00143 | 97.66 % | 2.11 % | 1.0017 |
| q4_0/q4_0 | 0.00993 +/- 0.00200 | 97.33 % | 2.75 % | 1.0014 |

Reading: the q8->q4 KV delta (+0.006 KLD, -1.4 pp top-1) is real but second-order against what the IQ4_XS weight quant itself costs (unsloth's published KLD tables for comparable quants sit at 0.016-0.058 = "92-97 % recovery"). The community claim "q4_0 KV is near-FP post-Hadamard" (Lirezh) is directionally confirmed at this depth; his other claim "q4_0 beats q4_1" is **contradicted on this model/build** - q4_1 measures better on every metric and costs ~0.5 GiB more at 262144 (5.0 vs 4.5 bpw). Two honest limits: measured at <=16384-token depth (KV-quant error compounds with context; the 100k+ regime that a 262144 preset exists for is unmeasured - a single-chunk deep run needs a ~30 GB logits base and was skipped), and wikitext prose, not code. If a q4_1 pair is ever adopted, speed-probe it first: the matched-pair FA-kernel support per type is not established on CUDA (only q8_0/q8_0 and q4_0/q4_0 are throughput-verified in this repo).

## Two-preset A/B state (2026-08-15) and the q4_1 collapse

The section now has a deliberate twin for real-scenario A/B testing instead of a single winner: **`[Qwen3.8-27B]`** (147456 / q8_0/q8_0 / `draft-mtp,ngram-mod` - the quality/throughput pick, 58 t/s @26.6k) and **`[Qwen3.8-27B-maxctx]`** (262144 / q4_0/q4_0 / `ngram-mod` only - the full-native-window pick, 43.2 t/s short / 32.9 t/s @103k, pp 1989 t/s, 21241-21269 MiB). Both live in `models.ini`/`models.example.ini` and in the hermine OpenCode provider (`Qwen3.8-27B-maxctx` is hermine-only; lieselotte's GGUF was never verified). Sampling, reasoning-preserve, mmproj-on-CPU and the ngram-mod chain are identical across both, so an A/B result is attributable to window/KV/MTP and not to incidental config drift.

**q4_1 KV is disqualified on CUDA despite winning the KLD ladder.** It measured KLD 0.0074 (between q8_0's 0.0039 and q4_0's 0.0099) but generation drops to 30.5 t/s short (q4_0: 43.2) and prompt processing collapses to ~30 t/s vs q4_0's 1989 t/s (~65x) - a 103k prompt was 22 % done after 13 minutes and hit the client timeout. VRAM also lands oddly lower (20618 vs 21241 MiB), consistent with a different, non-fused kernel path. Sharpened rule: **matching K and V is necessary but not sufficient on CUDA - only pairs with a fused FA path are usable, and on this build/model that is q8_0/q8_0 and q4_0/q4_0 (throughput-verified); every other pair needs its own probe before use.**

**Renamed 2026-08-15 (same day):** the twins are now `[Qwen3.8-27B-small]` (ex `[Qwen3.8-27B]`) and `[Qwen3.8-27B-large]` (ex `[Qwen3.8-27B-maxctx]`) in both preset files and in the hermine OpenCode provider (models map + whitelist, live and backup). lieselotte keeps the plain `Qwen3.8-27B` ID - its GGUF and preset were never verified on that box, and renaming the OpenCode entry without touching that machine's models.ini would have broken the ID linkage. This doc file keeps the base-model name.

(Note 2026-09-04: the live `models.ini` meanwhile carries the twins as `[Qwen3.8-27B-UD-Q4_K_M-200ctx-q4_0]` / `[Qwen3.8-27B-UD-Q4_K_M-150ctx-q8_0]` with `alias` keys — renamed outside any recorded session. `/v1/models` lists **section names**, not aliases, so the hermine OpenCode provider IDs `Qwen3.8-27B-small`/`-large` no longer match what the router serves — not fixed here, flagged to the user.)

## RPC quality preset `[Qwen3.8-27B-UD-Q8_K_XL-260ctx-q8_0-rpc]` (2026-09-04, build 10786)

Third preset, hermine-only: **UD-Q8_K_XL weights (29.3 GiB — the largest quant below BF16,
which at 50.9 GiB exceeds the pool)** at **full native ctx 262144** with q8_0/q8_0 KV, pooled
over RPC with lieselotte's 7900 XTX (`rpc = 192.168.1.39:50052`, both ends build 10786,
rpc-server with `-c` — second load 31–58 s vs 2:38 cold). Devices at load: CUDA0 21506 MiB
free, RPC0 23270 MiB free; the winning config leaves ~3.4 GiB free on CUDA0 (18674 MiB used
incl. 671 idle baseline) and ~3.6 GiB estimated on RPC0. fit-params ladder (q8_0/q8_0, no
drafter, MiB model+ctx+compute): 131072 → RPC0 16967 / CUDA0 17552; 196608 → 18311 / 19152;
262144 → 19655 / 20752.

**Adopted: `fit = on` + `fit-target = 1024,1024`, `spec-type = ngram-mod`, no `device` key,
no MTP.** Measured (short 400-token probes via /completion, temp 1.0 card set, warm):

| Config (all ctx 262144) | tg t/s | notes |
|---|---|---|
| **ngram-mod only, fit 1024,1024** | **17.4–17.5** | adopted; pp 395–407 t/s @14k prompt, tg@14k-depth 16.2 |
| embedded draft-mtp,ngram-mod n-max 3 | 14.6–16.8 | acceptance 0.42–0.52, still net loss |
| sidecar `MTP/mtp-Qwen3.8-27B-Q4_0.gguf` + `-devd CUDA0` | 16.2–17.2 | acceptance 0.48–0.53, neutral at best |
| fit-target 4096,1024 (CUDA0-heavy split) | 10.5–10.8 | pp 465; split breaks RPC0 range contiguity |
| ubatch/batch 2048 | 9.9 | pp 471 (+18 %); fit placement is ubatch-sensitive, tg collapses |

**MTP at default draft settings does not survive RPC — but see the same-day speed retune
below, which inverts this again.** At `spec-draft-n-max = 3`, `p-min` 0 (the twins' settings)
both variants (embedded head, and the sidecar drafter pinned local exactly as the Flash-Next
code-finding prescribes) measure at or below the 17.4 no-spec baseline despite ~0.5
acceptance. **ngram-mod is now measured on this hardware** (first section where it is not
just mechanism-adopted): 3/64 accepted on novel prose (harmless), **821/896 = 0.92 acceptance
and 26.7 t/s (+53 %) on a verbatim script-rewrite probe** — the agentic file-rewrite case it
exists for. The Flash-Next temp-1.0 acceptance collapse does not transfer here.

## Speed retune (2026-09-04, same day): amortize the RPC sync tax with confidence-gated drafts

User verdict on the first cut: <20 t/s is unusable for agentic work. Diagnosis by measuring
three explicit splits (`fit = off`, `-ngl 65`; fit-params emits `-ts 35,30`):

| -ts (RPC0,CUDA0) | tg t/s | CUDA0 used |
|---|---|---|
| 40,25 | 16.9 | 17443 |
| 35,30 (= fit's choice, tg identical to `fit = on`) | 17.4 | 19997 |
| 32,33 | 17.5 | 21769 |

Solving the three points: **XTX ≈ 0.87 ms/block, 4090 ≈ 0.55 ms/block, plus ~10 ms/token
fixed RPC sync cost** (18 % of the 57.5 ms token — the #22850 sync tax; TCP_NODELAY already
set, topology-fixed). Rebalancing is therefore a dead end (±0.3 t/s), and the single-token
decode ceiling on this pool is ~18 t/s. The lever is amortizing the fixed cost over
multi-token verify rounds — long drafts, but only *confident* ones.

**Adopted: sidecar drafter + `spec-draft-n-max = 6` + `spec-draft-p-min = 0.5`** (both are
load-bearing, isolated same-day: n-max 6 with p-min 0 → 23.1–25.2; n-max 3 with p-min 0.5 →
24.0–26.7; together → **26.8–32.5 prose**). n-max 10 pushes rewrites to 53 but drops prose to
23–27 (per-draft acceptance falls); n-max 8 + p-min 0.6 drafts too rarely (22.7–25.1). p-min
0.4 ≈ 0.5 on prose, worse on rewrites. `device-draft = CUDA0` stays mandatory (embedded MTP:
14.6–16.8). All /completion short probes, temp-1.0 card set, warm.

**`tensor-split = 38,27` instead of 35,30 buys the margin**: with the drafter aboard, 35,30
leaves CUDA0 at 22510–22545 MiB (~500 MiB free — under the documented Windows-shell creep of
up to ~977 MiB, a mid-session OOM risk); 38,27 lands at 21892 MiB (~1.1 GiB free) for ~8 %
rewrite speed (44.3 vs 48.1) and unchanged prose. 36,29 rounds to the same layer boundary as
35,30 and moves nothing.

**Final numbers, router-verified (build 10786):** /completion probes prose 26.7–30.1,
verbatim rewrite 44.3; via chat endpoint with thinking (end-to-end, comparable to the
pre-retune 16.1–17.4 / 26.7): **prose 20.5–22.9, rewrite 36.9, tg@14k-depth 27.6 (was 16.2),
pp 460 t/s @14k**. Thinking-phase tokens draft worse (flatter temp-1.0 distribution → p-min
gate closes), so chat prose sits below raw-completion prose — inherent to the workload, not a
config defect. Section carries `n-gpu-layers = 65`, `tensor-split = 38,27`, `fit = off`
(explicit split, loud failure; `fit = on` + `fit-target = 1024,1024` measured identical tg at
n-max 3 and remains the fallback if VRAM conditions shift).

Router-verified end to end: `/v1/models` lists the section, spawn works, reasoning_content
separates cleanly, warm tg 16.1–17.4 t/s over the router (first request after spawn ~14 t/s,
not representative). `load-mode`/`kv-unified` deliberately absent: untested here, and the
tested config ran without them (mmap default loaded 29.3 GiB in ~31 s warm). The mmproj stays
on CPU (`mmproj-offload = false`), same reasoning as the twins. RPC has no auth — LAN only;
if lieselotte's rpc-server is down the load fails loudly (intended, same as Flash-Next).

## DFlash2 speculation section (added 2026-09-05; measured same day — loses the A/B)

`[Qwen3.8-27B-UD-Q4_K_M-200ctx-q4_0-dflash2]` is an **experimental** twin of the 200ctx MTP section: same target GGUF, ctx 200000, q4_0/q4_0 KV, thinking sampling, mmproj on CPU — but `spec-type = draft-dflash` with the external block-diffusion drafter `incoai/Qwen3.8-27B-DFlash2-GGUF` (Q4_K_M, 1.1 GB, added to `models.list`) instead of the embedded MTP head. `spec-draft-n-max = 7` and the Q4_K_M drafter follow the drafter's HF card (incoai/Qwen3.8-27B-DFlash2-GGUF); draft KV q4_0/q4_0 follows the only other dflash section in this file (Muse-Glimmer-30B).

Upstream status: dflash support landed in stock llama.cpp via PR #27816 (merged 2026-08-27), so the prebuilt bootstrap build picks it up; the "build from PR #27342" instructions on the HF card are stale.

**A/B measured 2026-09-05 (build 10786, direct `llama-server.exe` runs with each section's exact flag set, test port, idle GPU baseline ~450 MiB; /completion probes, temp-1.0 card set, warm, `cache_prompt: false`). Verdict: the MTP twin stays the primary — dflash2 wins only near-verbatim rewrites.** The drafter GGUF was downloaded to `E:/Llama.cpp/models/Qwen3.8-27B/` next to the target (note: `download-model.sh` drops it under `$LLAMA_MODELS_DIR` = `C:/Users/Anwender/AppData/Local/llama.cpp/models`; it was moved to E: to match the live `models.ini` paths).

| Probe (identical prompts both sides) | MTP (`draft-mtp`, n-max 3) | DFlash2 (`draft-dflash`, n-max 7) |
|---|---|---|
| VRAM at 200k load (`nvidia-smi`) | 22086 MiB (~940 MiB free) | **22563 MiB (~465 MiB free)** |
| prose 400-tok ×3 | **65.9–69.4 t/s** (acc 0.44–0.49, len 2.3–2.5) | 54.4–61.7 t/s (acc 0.20–0.38, len 2.4–3.6) |
| verbatim script rewrite ×2 | 111.6–112.1 t/s (acc 1.00, len 4.00 — n-max cap saturated) | **154.9–155.0 t/s** (acc 0.94, len 7.56) |
| pp @19.3k-token prompt | **2473–2569 t/s** | 1762–1781 t/s (drafter prefills the context too) |
| tg @19.3k depth ×2 | **78.8–79.1 t/s** | 65.7–69.3 t/s |

So: **both fit at 200k**, but dflash2 costs ~480 MiB more and leaves the margin under the documented Windows-shell creep (~977 MiB) — a mid-session OOM risk the MTP twin doesn't have. On throughput dflash2 is 10–17 % slower on prose (short and at depth) and ~30 % slower on long-prompt processing; its one win is +38 % on near-verbatim file rewrites, where its n-max 7 saturates at 0.94 acceptance while MTP is pinned at its n-max 3 ceiling (acceptance 1.00, mean len 4.00 — the cap, not the head, is the limiter there). Untested: raising MTP's n-max with a p-min gate à la the RPC section might close that rewrite gap without dflash2's costs (n-max 4 *without* a gate measured worse on 10424, see above); chat-endpoint/thinking and vision behaviour of dflash2 were not probed. The HF card's GSM8K acceptance ~5.4 did not reproduce on this workload mix (3.6–3.8 at depth, 2.4–3.6 on prose). Section left in `models.example.ini` only — **not** merged into the live `models.ini` and not wired into any OpenCode provider.

### Drafter retest with `HermiHg/Qwen3.8-27B-DFlash2-Q2_K_S-MIX-GGUF` (2026-09-06, build 10786)

Community drafter quants surveyed for a better fit: the official repo carries Q4_K_M 1.1 GB (card acceptance-length 5.39 — its own best), Q8_0 2.0 GB (5.13) and BF16 3.8 GB (5.28) — the two larger ones are disqualified by VRAM at 200k. Two smaller community quants exist: `analogalok/…-Q2_K-GGUF` (~700 MB, card: acceptance parity on a 4090) and **`HermiHg/…-Q2_K_S-MIX-GGUF` (561 MB, iq2_xxs FFN / q5_k+iq2_s selector / q3_k projection / f32 norms; card: 97 % of reference acceptance, throughput parity)**. The MIX was adopted into the dflash2 section (`models.list` + `model-draft` swapped; old Q4_K_M drafter file left on disk) and re-measured with the same method, plus a same-day MTP control run:

| Probe | MTP control (same day) | DFlash2 MIX (n-max 7) | DFlash2 Q4_K_M (2026-09-05) |
|---|---|---|---|
| VRAM at 200k (`nvidia-smi`) | 22175 MiB (~850 free) | 22444 MiB (~585 free) | 22563 MiB (~465 free) |
| prose 400-tok ×3 | **65.5–73.6 t/s** | 60.3–65.4 t/s (acc 0.16–0.23, len 2.1–2.6) | 54.4–61.7 t/s |
| verbatim rewrite ×2 | 110.8–111.1 t/s | **176.2–182.3 t/s** (acc 0.94, len 7.56 — same as Q4_K_M, drafts just cost less) | 154.9–155.0 t/s |
| pp @19.3k prompt | **2550–2574 t/s** | 2314–2437 t/s | 1762–1781 t/s |
| tg @19.3k ×4–6 | 60.8–83.6 (median ~70) | 49.9–87.3 (median ~57) | 65.7–69.3 |

Notes on data quality: this day's depth-tg probes were noisy **for both configs** (MTP itself spread 61–84 where the previous day gave a tight 78.8–79.1), so depth medians, not single runs, carry the comparison; prose/rewrite reproduced the previous day's MTP numbers closely. The expected ~540 MiB VRAM saving from the smaller drafter did **not** fully materialize: only ~120 MiB more free at load (585 vs 465), and net of the day's idle-baseline drift the footprints are near-identical — unexplained, treat the free-margin readings as the operative numbers.

**Verdict: the MIX drafter strictly improves the dflash2 section over the Q4_K_M drafter** (prose +6–10 %, rewrites +15 %, pp@depth +35 %, slightly more VRAM margin — the Q4_K_M drafter has no remaining advantage), **but the overall A/B verdict vs the MTP twin stands**: MTP remains faster on prose (~8 %), long-prompt pp (~5 %) and depth-tg median, with ~265 MiB more margin. dflash2+MIX's one dominant win is near-verbatim rewrites (+60 % over MTP). Keep MTP as the primary; the dflash2 section is now worth keeping as the rewrite-heavy special case, still `models.example.ini`-only.

## Triangle retune → new section `[Qwen3.8-27B-UD-Q4_K_S-131ctx-q8_0]` (2026-09-06, build 10786)

Brief: best speed/quality/context balance from the existing measurement points, open to any unsloth Q4 quant. Three findings drove the result, all measured same-day with the established probe set (/completion, temp-1.0 card set, warm; prose 400-tok ×3, verbatim rewrite ×2, 19.3k-prompt depth probes):

1. **Sub-~600-MiB VRAM margins put the Windows driver into overcommit and collapse throughput.** Reproduced repeatedly: the 150ctx-q8_0 twin (UD-Q4_K_M @131000, ~500 MiB free under the day's shell creep — baseline breathed between ~420 and 1017 MiB) measured pp 608–1686 (unstable) and depth-tg 46–62; the identical config at ctx 114688 (~940 free) recovered to pp ~2550, depth-tg 60–81, prose 59–73. The 147456/q8_0 point (~594 free with UD-Q4_K_M) is dead the same way (pp ~1420, depth-tg 25–29). **The twins' weights moved from IQ4_XS to UD-Q4_K_M (+~1 GiB) outside any recorded session, which silently ate the margin the August ladder was built on — the 131k q8_0 twin is in the overcommit zone whenever shell creep is high.**
2. **The RPC speed recipe does not transfer to local decode.** `spec-draft-n-max = 6` + `spec-draft-p-min = 0.5` (the Q8_K_XL-RPC winner): prose drops to 44–57 (vs 65–74 at n-max 3) — without the ~10 ms/token RPC sync tax there is nothing to amortize and the discarded long drafts just cost MTP forwards. p-min 0.5 on n-max 3 is also a no-gain (54–67 prose). **n-max 3, ungated, stays.**
3. **Rewrite speed comes from chained ngram-mod, not from the MTP draft budget**: n-max 3 + ngram-mod hits 226–440 t/s on verbatim rewrites (same level as the gated-6 config, without its prose loss). The 200ctx twin, which lacks ngram-mod, sits at 109–111 there — wiring `ngram-mod` into it is a free ~2× rewrite win (not done here, separate retune).

**Resolution of the margin problem: buy the ~1 GiB back in weight bits, not context or KV bits.** unsloth Q4-class ladder: UD-IQ4_XS 13.27 / UD-Q4_K_S 14.30 / UD-Q4_K_M 15.33 / UD-Q4_K_XL 16.35 GiB (plus legacy Q4_0/Q4_1, dominated by the UD series). UD-Q4_K_S (−1.03 GiB) keeps ctx 131072 and q8_0/q8_0 KV with a healthy margin; UD-IQ4_XS @163840+ was rejected because the 200ctx twin already owns the context corner and −2 GiB of weight bits likely costs more quality than q4_0→q8_0 KV buys (not measured, reasoned). Measured result for the new section (UD-Q4_K_S, ctx 131072, q8_0/q8_0, draft-mtp,ngram-mod n-max 3, draft KV q4_0/q4_0):

| Same-day comparison | **UD-Q4_K_S-131ctx-q8_0 (new)** | 200ctx-q4_0 twin | 150ctx-q8_0 twin |
|---|---|---|---|
| VRAM at load | 21472 MiB (**~1.55 GiB free**) | 22050 (~0.98 free) | 22530 (~0.5 free) |
| prose 400-tok ×3 | 63.5–69.1 t/s | **69.2–71.2** | 53.8–61.5 |
| verbatim rewrite ×2 | **233–385 t/s** | 109–111 (no ngram) | 154–241 |
| pp @19.3k prompt | **2611–2622 t/s** | 2579–2586 | 608–1686 (unstable) |
| tg @19.3k ×2–4 | 59–82 (median ~66) | 62–76 | 46–62 |
| context / KV | 131072 / q8_0 | 200000 / q4_0 | 131000 / q8_0 |

**Verdict: the new section strictly dominates the 150ctx-q8_0 twin** (same context, same KV quality, faster on everything, 3× the margin; only unmeasured delta is UD-Q4_K_M→UD-Q4_K_S weight quality — no local KLD run). Against the 200ctx twin it trades ~70 k context and ~7 % prose speed for q8_0 KV quality (KLD 0.0039 vs 0.0099), ~2–3× rewrite speed and ~0.6 GiB more margin. Recommended roles: **UD-Q4_K_S-131ctx-q8_0 as the daily agentic primary, 200ctx-q4_0 for genuinely long sessions, 150ctx-q8_0 twin retired** (dominated). Caveats: depth-tg spread 46–84 across all configs this day (single-run depth numbers are noise — medians carry); the section was probed via direct llama-server runs, not router-verified; day's data taken while baseline crept 420–1017 MiB.

(Note 2026-09-06, user decision: sections renamed and pruned — the new UD-Q4_K_S section is now **`[Qwen3.8-27B]`**, the 200ctx-q4_0 section is **`[Qwen3.8-27B-lang]`**, and the dominated `[Qwen3.8-27B-UD-Q4_K_M-150ctx-q8_0]` was **removed** from both preset files (its UD-Q4_K_M GGUF stays — `-lang` and the dflash2 example still use it). This supersedes the 2026-09-04 naming note above. The hermine OpenCode provider IDs `Qwen3.8-27B-small`/`-large` remain stale and now point at nothing; the provider would need `Qwen3.8-27B` and `Qwen3.8-27B-lang` instead — and note the hermine `Qwen3.8-27B` ID now collides by name with lieselotte's plain ID, which points at that machine's own (unverified-there) preset. Not fixed here.)

## `-lang` retune: UD-Q4_K_S, ctx 229376, ngram-mod (2026-09-06, build 10786)

Question: can `-lang` reach the native 262144 window by switching its weights UD-Q4_K_M → UD-Q4_K_S too? Measured ladder (all UD-Q4_K_S, q4_0/q4_0 KV, `draft-mtp,ngram-mod` n-max 3, mmproj on CPU; fit-params lower bounds excl. MTP: 200000 → 18505, 229376 → 19161, 262144 → 19897 MiB; idle baseline ~400 MiB during all loads):

| ctx | used / free (`nvidia-smi`) | prose ×3 | rewrite ×2 | pp @19.3k | tg @19.3k |
|---|---|---|---|---|---|
| 262144 | 22450 / ~578 | 50.3–52.2 | 189–403 | 1995–2010 | 50–59 |
| 245760 | 22428 / ~600 | 63.5–65.7 | 236–445 | 2602–2605 | 76–87 |
| **229376 (adopted)** | 21936 / **~1090** | **66.3–75.9** | **241–446** | **2593–2595** | 61–63 |

**262144 loads but throttles** — and the comparison of 262144 vs 245760 sharpens the overcommit finding: both show ~580–600 MiB "free" in `nvidia-smi`, yet only 262144 collapses. The margin number alone is not the mechanism; what matters is whether a large allocation (here the 1360-MiB pp compute buffer, per fit-params) spills into Windows shared memory. `nvidia-smi` "used" looks near-identical in both cases because it only counts dedicated VRAM — **a healthy-looking margin does not prove a healthy load; probe pp before trusting any near-full configuration.** 245760 is fast today but leaves no headroom for the documented same-day baseline swing (396 → 1017 MiB), so 229376 is the robust point: +15 % window over the old 200000 at full speed, ~1.1 GiB free, and (via the section's new `ngram-mod`) ~4× the old rewrite throughput (241–446 vs 109–111 t/s on the old UD-Q4_K_M section).

`[Qwen3.8-27B-lang]` therefore now runs UD-Q4_K_S / 229376 / q4_0 / `draft-mtp,ngram-mod` (alias `Qwen3.8-27B-UD-Q4_K_S-lang`); the old UD-Q4_K_M@200000 config is retired. Same open trade as the primary: the UD-Q4_K_M → UD-Q4_K_S weight-quality delta is unmeasured (no KLD run). Router-verified same day (`LLAMA_AUTO_UPDATE=0 bash server.sh`): `/v1/models` lists it, spawn works with clean `reasoning_content` separation, and the 19.3k-prompt /completion probe over the router measures pp 2502–2608 / tg 64–78 — matching the direct-run numbers. Note the router's /completion endpoint requires the `model` field in the payload (a direct single-model server does not); a 400 there is the probe's fault, not the preset's.

(Note 2026-09-06, later same day: **the DFlash2 experiment was closed and deleted on user decision** — the `[…-dflash2]` section was removed from `models.example.ini`, the drafter entry from `models.list`, and both drafter GGUFs (incoai Q4_K_M, HermiHg Q2_K_S-MIX) from disk. The measurement sections above stay as the record of why: dflash2 lost the general-agentic A/B against the embedded MTP head twice, and its one win — verbatim rewrites — is since covered for free by `ngram-mod` in both standing presets, which reach 233–446 t/s there vs dflash2's 155–182. Muse-Glimmer-30B's own dflash drafter is unaffected.)

## Community-lever sweep (2026-09-06, build 10786, one lever per load on `[Qwen3.8-27B]`)

All five levers from the 2026-09-06 research pass measured against a fresh same-day baseline (prose 65–79, rewrite 231–267, tg@19.3k 60–75, pp ~2610). Verdicts:

| Lever (source) | Measured | Verdict |
|---|---|---|
| `spec-draft-n-max = 2` (sudoingX 4090 sweet spot) | prose 65–76, deep 60–70, rewrites 213–447 | **no gain** over n-max 3 within day noise — stays 3 |
| `ngram-map-k4v` n16/m24/min-hits1 (Lirezh) instead of ngram-mod | prose/deep ≈ baseline, **rewrites 191–200** (acc 0.88–0.93 but len ~10 vs ngram-mod's up-to-50 blocks) | **worse on the verbatim-rewrite case** — ngram-mod stays. Caveat: Lirezh's 6× claim was for *paraphrase*, not verbatim; untested here |
| `ctx-checkpoints = 32` (+ `checkpoint-min-step`) (countzero/Lirezh) | **already the build default (32)** — countzero's key is a no-op. History-edit test (edit ~600 tok before end of a 19.3k prompt, `cache_prompt: true`): default checkpoints reprocess **510 tok / 0.36 s**; `--ctx-checkpoints 0` control reprocesses **19315 tok / 7.3 s** | **~20× agent-loop latency win, active without any preset key.** Reprocessing starts at the exact divergence point, so a finer `checkpoint-min-step` has nothing left to buy — neither key is written |
| `cache-ram = 51200` (countzero) | A/B/A alternation of two ~14k-token sessions at `cache-ram = 16384`: third request `prompt_n = 4` — the evicted session survived in the host cache | **16384 already covers the measured case** — not adopted; would only matter at ~20+ parallel large sessions |
| `image-min-tokens = 1024` (countzero + our own server-log hint) | no speed/VRAM regression (prose 64–70, rewrites 231–448, 21537 MiB) | **adopted** into `[Qwen3.8-27B]` and `[Qwen3.8-27B-lang]` — vision-grounding quality fix, effect on vision quality itself unmeasured (no vision benchmark run). The RPC section also carries the mmproj but was not touched/tested |

Net result of the sweep: the standing presets were already at the measured local optimum for speed; the one adopted change is quality-motivated (`image-min-tokens`). The checkpoint control run is the sweep's real yield — it documents that agent-loop history edits are already ~20× cheaper than a naive full reprocess, which had never been verified on this machine.

## HF finetune/variant survey for speed and full-context (2026-09-06, research only — nothing tested)

Two-track survey of the ~100 Qwen3.8-27B derivatives on HuggingFace. Track 1 (speed finetunes): **no credible candidate beats the embedded MTP head on stock llama.cpp.** The field is dominated by uncensored/abliterated merges (behaviour changes, not speed), vLLM-stack quants (AWQ/GPTQ/W4A16, NVFP4 = Blackwell-only), and external drafters of the class that already lost our A/Bs — `RadixArk/Qwen3.8-27B-DSpark` (1.86B drafter, SGLang-trained; our build lists `draft-dspark` but no llama.cpp-verified GGUF path, and the DFlash2 result argues against the whole class locally). No trained EAGLE3 head for this model exists on HF; llama.cpp's eagle3 support itself is still the WIP-PR stage for chained use. `logic65/Qwen3.8-Whittle-MoE-27B-A17.8B` (post-hoc MoE-fication, ~8.9B active) would be genuinely faster but its own card documents quality regressions (exact-counting 8/36 → 2/36) — not at `-lang` quality.

Track 2 (full 262144 ctx at ~`-lang` quality): **one real candidate — `ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF`.** Gumbel-Softmax quantization + Riemannian-constrained per-tensor type assignment; standard GGUF, runs on stock llama.cpp; `IQ3_S-mtp` is **11.29 GiB with the MTP head included** (3.0 GiB below our UD-Q4_K_S) plus a BF16 mmproj. Card claims "task-lossless" at 3.5 bpw (AIME25 100.00 = BF16 base, LiveCodeBench 85.71, beats unsloth IQ3_S by 3.3 AIME points at smaller size). Napkin fit (do not trust — measure): our K_S@262144+MTP sat at 22450 MiB throttled; −3.0 GiB weights ≈ ~19450 → ~3 GiB free → full native window with healthy margin, possibly even q8_0 KV. **Untested locally**: no KLD run (card benchmarks are coarser than KLD; a local ladder against UD-Q8_K_XL as reference would settle it), no throughput probe, and "task-lossless at 3.5 bpw" is a strong claim to verify before trusting. This was measured the same day — see below.

### GSQ-RCO IQ3_S-mtp measured (2026-09-06, build 10786): quality holds, full 262144 fits fast

Downloaded `Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf` (11.29 GiB) to E: (deliberately **not** in `models.list` yet). Three-part test:

**Fit @262144** (q4_0/q4_0, `draft-mtp,ngram-mod` n-max 3, mmproj-F16 from the unsloth repo — loads cleanly with ISTA's weights): 20414 MiB used at a 916-MiB creep baseline → **~2.6 GiB free at full native context**, comfortably clear of the sysmem-fallback zone.

**Speed @262144** (same probe suite): prose 72.1–82.2 t/s, rewrites 243–453, tg@19.3k 69.9–83.9, pp 2559–2563 — the best prose/depth numbers of the whole session (smaller weights = less memory traffic); the GSQ-quantized MTP head drafts normally (acceptance 0.40–0.68, mean len 2.5–3.1).

**Quality vs UD-Q4_K_S** (identical settings per pair; per user decision UD-Q8_K_XL was not used as reference — it is not the daily driver until its RPC speed problem is solved):

| Metric (llama-perplexity, -fa on, -ngl 999) | GSQ-RCO IQ3_S-mtp (11.29 GiB) | UD-Q4_K_S (14.30 GiB) |
|---|---|---|
| wikitext-2 test PPL, ctx 16384 | **5.9706 ± 0.0375** | 6.0815 ± 0.0394 |
| HellaSwag 400 tasks, acc | 82.00 % [77.9, 85.5] | 82.75 % [78.7, 86.1] |

Verdict: **yes, it keeps up** — PPL is actually *better* than UD-Q4_K_S (non-overlapping at ±1σ), HellaSwag is a 3-task difference inside heavily overlapping CIs. Honest limits: both metrics are prose/commonsense; coding/agentic behaviour was not measured locally (ISTA's LiveCodeBench 85.71 claim covers it, but that is their number). GSQ is calibration-trained, so some affinity to wikitext-like text is conceivable — HellaSwag as the second axis mitigates but does not eliminate that. Vision path untested beyond a clean load. If adopted for a preset, add the GGUF to `models.list` and decide which section it replaces.

(Note 2026-09-07, user decision: **GSQ-RCO adopted as the default.** `[Qwen3.8-27B]` now runs the GSQ-RCO IQ3_S-mtp weights at full native ctx 262144 / q4_0 KV / `draft-mtp,ngram-mod` n-max 3 (exactly the measured config above; router-verified: spawn at 20607 MiB ≈ 2.4 GiB free, clean reasoning separation). The previous default moved to **`[Qwen3.8-27B-UD]`** (UD-Q4_K_S, 131072 / q8_0 — unchanged otherwise), and **`[Qwen3.8-27B-lang]` was removed** — its full-context role is covered by the new default. GSQ GGUF added to `models.list`. Adoption happened with the aider-polyglot coding A/B still open (run A / UD-Q4_K_S: 73.5 % pass_rate_2; run B on GSQ pending) — if run B lands clearly below run A, revisit this decision.)

## Aider-polyglot coding A/B: GSQ-RCO loses to UD-Q4_K_S (2026-09-07, build 10786)

The industry-standard agentic probe promised alongside the GSQ adoption. Setup: aider polyglot benchmark, **Python subset (34 exercism tasks)**, `--edit-format whole`, threads 1, both models served identically (direct llama-server, ctx 131072, q8_0/q8_0 KV, draft KV q4_0, `draft-mtp,ngram-mod` n-max 3, `--chat-template-kwargs '{"reasoning_effort": "low"}'` — without the cap the model thinks ~22k tokens per task and the bench is infeasible; aider sends temp 0). Harness gotchas recorded for reruns: `AIDER_DOCKER=1` bypasses the docker gate, `pytest` must be on PATH, `--exercises-dir` resolves relative to `tmp.benchmarks`. Artifacts: `E:/Llama.cpp/eval/aider-bench/`.

| Run (34 tasks) | pass_rate_1 | pass_rate_2 | notes |
|---|---|---|---|
| A: UD-Q4_K_S (14.30 GiB) | 26.5 % (9) | **73.5 % (25)** | 0 malformed, 50.4 s/case |
| B: GSQ-RCO IQ3_S-mtp (11.29 GiB) | 11.8 % (4) | **61.8 % (21)** | 0 malformed, 1 test timeout, 51.3 s/case |

**Reading: the coding-agentic axis contradicts the prose metrics.** PPL (5.97 vs 6.08, GSQ better) and HellaSwag (82.00 vs 82.75, tie) said "equal"; the agentic coding test says **−11.7 pp pass_rate_2 and less than half the first-try rate**. With n=34 the gap is ~1.4σ on pass_rate_2 alone — not ironclad — but both metrics point the same way and aider runs near-greedy, so a rerun would land close. ISTA's "task-lossless" LiveCodeBench claim did not reproduce on this workload. Lesson for the doc: **calibration-trained low-bpw quants can hold prose/commonsense metrics while losing coding precision — benchmark the axis you actually use before adopting.**

Consequence for the 2026-09-07 adoption (which was made under exactly this proviso): **the "revisit" condition is met.** Options: (a) revert the default `[Qwen3.8-27B]` to UD-Q4_K_S weights (giving up 262k-at-full-speed), (b) keep GSQ as default for its context/speed and route coding-heavy work to `[Qwen3.8-27B-UD]`, (c) test the GSQ IQ3_S at a mixed operating point first (e.g. more tasks, or the full polyglot set) before deciding. Decision left to the user — not changed here.
