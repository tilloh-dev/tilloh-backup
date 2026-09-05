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
