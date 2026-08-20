# Ornith-1.5-35B-A3B

Ornith-1.5-35B-A3B (ornith-ai, MIT, `qwen35moe`, 42 layers, 256 experts, ~3B active per token,
native 262144 ctx) is the mid-size MoE of the Ornith-1.5 family — an agentic coding model built
on the Ornith self-improvement loop, continued from Qwen3.5/Gemma4. The card leads on long-horizon
agentic coding (Terminal-Bench 2.1, SWE-bench Verified 79, SWE-bench Pro 59.6) and claims it beats
Qwen3.6-35B-A3B across all coding/agentic benchmarks. All settings below measured on **hermine**
(RTX 4090, 23028 MiB total per `nvidia-smi`), llama.cpp build **10502**, `Q4_K_M` (20707 MiB),
2026-08-20.

## The download-manifest typo that started this

`models.list` shipped the repo as `ornith-ai/Ornith-1.5-35B-A3B-A3B-GGUF` — a doubled `-A3B`, so
`download-model.sh` 404'd. Real repo (HF API verified): `ornith-ai/Ornith-1.5-35B-A3B-GGUF`, file
`Ornith-1.5-35B-Q4_K_M.gguf`, dest `Ornith-1.5-35B-A3B`. Fixed 2026-08-20. An empty
`Ornith-1.5-35B/` dir under the models root is a leftover of the failed first attempt.

## Context is VRAM-free here — hybrid attention, not a fit constraint

`llama-fit-params` overestimates KV badly on this arch because it does not model the hybrid
attention. The load log shows a **Gated Delta Net** component (`resolve_fused_ops ... Gated Delta
Net (chunked) not supported, set to disabled`) — i.e. most layers use linear/delta attention and
carry no growing KV cache, like the qwen35 (Qwen3.8-27B) and Laguna families. Consequence: real
allocation is nearly flat across the whole ctx range, and every point from 131072 to the full
native 262144 loads with ~1.6 GiB free on the 23 GB card.

Measured real load (ngram-mod, q8_0/q8_0, `nvidia-smi` used / free):

| ctx    | fit-params est. total | real used | real free |
|--------|-----------------------|-----------|-----------|
| 131072 | 21817                 | ~20690*   | ~2338*    |
| 163840 | 22196                 | 21007     | 1602      |
| 196608 | 22632                 | 20928     | 1681      |
| 262144 | 23504 (> card total)  | 21014     | 1595      |

\*131072 real not measured directly with ngram (draft-mtp@131072 was 20356 used); estimate.
Note fit-params said 262144 does **not** fit (23504 > 23028) — wrong: it loads with 1595 MiB free.
So ctx is a **pure speed choice, not a fit choice** on this model.

## ctx-size = 163840 — a measured speed decision (user, 2026-08-20)

Since VRAM does not constrain ctx, generation speed does. Gen-speed sweep, hermine, build 10502,
short prompt (~36 tok, shallow depth), ngram-mod, q8_0/q8_0, 2 runs each:

| ctx    | gen t/s (run1 / run2) | mean  |
|--------|-----------------------|-------|
| 131072 | 82.1 / 85.0           | ~83.5 |
| 163840 | 77.5 / 80.6           | ~79.0 |
| 196608 | 73.0 / 77.4           | ~75.2 |
| 262144 | 63.6 / 67.2           | ~65.4 |

A **gradual** decline with allocated ctx-size (not a sharp cliff like Ornith-1.0-35B's dense
collapse at 131072, but the same family flavour: bigger preallocated KV taxes per-token speed even
at shallow depth). **163840 chosen**: 95 % of peak throughput, 160K window (matches the Laguna-XS
sibling), safe 1.6 GiB margin. The user picked it over the offered alternatives (262144 full window
at −22 % gen speed; 131072 at max speed; a `-small`/`-large` twin pair). 262144 remains a
drop-in if the full native window is ever worth the speed. **All sweep numbers are shallow-depth**
— relative penalties at real 100k+ depth are unmeasured.

## spec-type = ngram-mod, NOT draft-mtp — the embedded MTP head measured slower

The GGUF **embeds an MTP/NextN head** (`blk.40.nextn.eh_proj/enorm/hnorm/shared_head_norm` seen
in the load log as "unused tensor ... ignoring"), although the HF repo name carries no `-MTP-` —
exactly the detection gap `recommend.sh` has on Qwen3.8-27B, so it proposed bare `ngram-mod`.
Unlike Qwen3.8-27B (dense, where MTP is a 1.85× win), enabling it here is a **loss**:

A/B at ctx 131072, q8_0/q8_0, short prompts, `spec-draft-n-max 3`:

| spec-type            | gen t/s (2 runs) | draft acceptance |
|----------------------|------------------|------------------|
| ngram-mod            | 82.1 / 85.0      | —                |
| draft-mtp,ngram-mod  | 73.1 / 65.3      | 0.38 / 0.30      |

draft-mtp is **~15–20 % slower**. Mechanism: an A3B activates only ~3B params, so the target
forward is cheap and the MTP draft+verify overhead is not repaid at 0.30–0.38 acceptance — the
same inversion documented for Nemotron (A3B) vs Qwen3.8-27B (dense). draft-mtp *does* load fine
(`creating MTP draft context against the target model`) and its context is cheap (draft-mtp@131072
= 20356 MiB used, 2253 free), so this is purely a speed decision, not a VRAM one. Speculative
decoding is lossless, so nothing was traded on quality. **Do not re-add draft-mtp without
re-measuring** — if a future build improves MTP acceptance on A3B it could flip.

## reasoning: preserve on, no reasoning=on needed

Card: "a reasoning model — by default the assistant turn opens with `<think>…</think>`." Confirmed
measured: with `reasoning-format = auto` and **no** `reasoning = on`, a generation returned a
populated `reasoning_content` (2205 chars) and clean `content` — thinking is on by default, so
unlike Laguna this section does **not** set `reasoning = on`. `reasoning-preserve = true` is set:
the template consumes prior `reasoning_content` from history, and llama.cpp logs it directly at
load — `srv init: chat template supports preserving reasoning, consider enabling it via
--reasoning-preserve`. The flag loaded with no warning (final verify: 21139 MiB used, 1470 free,
76.3 t/s, reasoning_content separated). A client that drops thinking blocks across turns will
degrade it (same contract as Qwen3.8-27B / Laguna).

## Sampling (vendor card)

Card publishes one general set + a benchmark temp: **general** `temperature=0.6, top_p=0.95,
top_k=20`; **benchmarks** `temperature=1.0` (ClawEval used 0.6). No separate coding set. Adopted
the general set whole for agentic use (the lower, more deterministic option). `min-p` /
penalties: not published, not set.

## KV cache

CUDA (hermine): `q8_0`/`q8_0` matched pair — the repo's fused-FlashAttention rule (a mixed pair
collapses ~9× on CUDA). `models.example.ini` (Vulkan / RX 7900 XTX box) uses `q8_0`/`q4_0`, the
Vulkan V floor, matching the Ornith-1.0 siblings there. No KV-KLD run done on this model.

## Unmeasured / open

- All speed numbers are shallow-depth; 100k+ real-depth throughput and the ctx→speed penalty at
  depth are untested.
- ngram-mod speedup vs no speculative decoding at all is unmeasured (adopted on mechanism:
  lossless, no VRAM).
- Wired into both OpenCode providers (`opencode.jsonc` models map + whitelist, lieselotte +
  hermine, backup + live synced 2026-08-20) with text-only modalities. The HF repo ships an
  `mmproj-Ornith-1.5-35B-BF16.gguf` (Qwen-derived vision scaffolding is in the template), but it
  was not downloaded and image capability was not verified, so the provider advertises text only —
  same stance as gemma-4-26B-A4B/gemma-4-31B.
- lieselotte: GGUF not downloaded/verified there; the example values are the untested Vulkan
  translation of the hermine measurements.
