---
name: llama-4090-community
description: Community-Presets und Tuning-Hebel für RTX-4090/24-GB-CUDA-Karten aus der llama.cpp-Szene (countzero, Lirezh/r-LocalAIStack, leewsimpson). Wird von der llama-preset-Skill nachgeladen, wenn das Zielgerät eine RTX 4090 ist (hermine); auch direkt nutzbar bei "was machen andere 4090-Nutzer", "Community-Preset vergleichen", "24GB-VRAM-Tuning", "vollen Kontext auf 24GB fahren". Enthält die Quellenliste, die Recherche-Methode und den Stand 2026-08-15: q4_0-KV nach Hadamard-Rotation, ubatch-Skalierung der Compute-Buffer, ctx-checkpoints für Hybrid-Modelle, ngram-map-k4v, image-min-tokens, reasoning-budget.
---

# llama-4090-community — what other 24 GB owners run, and how to check

Community knowledge for tuning llama.cpp presets on an RTX 4090 / 24-GB-class
CUDA card. The llama-preset skill measures *this* machine; this skill answers
the neighbouring question — *what do other people with the same card get away
with, and which of their levers survive contact with our build?* It exists
because two of its findings (ubatch-scaled compute buffers, post-Hadamard
q4_0 KV quality) were invisible from local measurement alone: the first looks
like a hard OOM wall, the second like a fixed quality floor.

**Invocation contract:** the llama-preset skill reads this file whenever
`--list-devices` reports an RTX 4090 (currently: hermine). Treat everything
here as *hypotheses with provenance*, never as settings to copy — each lever
still goes through the measure-first loop of llama-preset before it lands in
`models.ini`. Community numbers are claims; our numbers live in
`docs/models/<ID>.md` and win on conflict.

## Sources worth re-checking (ranked)

| Source | What it is | Where |
|--------|-----------|-------|
| countzero/windows_llama.cpp presets | The upstream of this repo's preset format; maintains `models_24GB_VRAM.ini` with battle-tested sections | `https://raw.githubusercontent.com/countzero/windows_llama.cpp/main/presets/models_24GB_VRAM.ini` (also check the latest tag — pinned tags lag `main` by weeks) |
| Lirezh on r/LocalAIStack | The 4090/5090 Qwen-coding reference post; ran eval-backed KV-quant comparisons and publishes full llama-server command lines | `https://old.reddit.com/r/LocalAIStack/comments/1udk2vp/` (old.reddit fetches cleanly; www.reddit blocks) |
| leewsimpson/local-llm-4090 | 4090-specific repo derived from Lirezh's post; documents VRAM budgets and the ubatch lever | `https://github.com/leewsimpson/local-llm-4090` (README + `docs/vram-planning.md`) |
| unsloth model docs | Per-family "how to run locally" pages; sampling sets, quant sizes, MTP notes | `https://unsloth.ai/docs/models/<family>` (append `.md` for raw markdown) |
| llama.cpp PRs/discussions | Feature timeline (what our auto-updated build gained since the last preset pass) | search `github.com/ggml-org/llama.cpp` PRs |

Research method when re-running this: fetch countzero `main` first (same key
vocabulary as our presets, diffs are directly readable), then Lirezh for the
*why* behind values, then verify every candidate flag against the installed
build (`llama-server --help`) before proposing it. Date-stamp what you adopt.

## Findings snapshot (researched 2026-08-15, build 10437 on hermine)

Each entry: claim, source, and its status against our own measurements.

1. **q4_0/q4_0 KV at full native ctx is the standard 24-GB trade.**
   countzero runs Qwen3.6-27B and 35B-A3B at `ctx-size = 262144` with
   `q4_0`/`q4_0` and MTP kept. The quality cost shrank materially when
   llama.cpp merged Hadamard/attn-rot KV rotation (PR #21038; fast WHT kernels
   CPU #22631, CUDA #23615, Vulkan #23687 — all predate build 10437, so our
   build has them). Lirezh, with eval follow-ups: q4_0 KV on the 27B is
   "almost identical to FP in evaluation results" and "q4_0 beats q4_1
   surprisingly". **Our status: measured 2026-08-15 on Qwen3.8-27B
   (llama-perplexity KLD vs f16 base, 32k wikitext tokens, ≤16k depth):
   q8_0 0.0039 / q4_1 0.0074 / q4_0 0.0099 mean KLD, top-1 agreement
   98.7 / 97.7 / 97.3 %.** "Near-FP" directionally confirmed at that depth;
   "q4_0 beats q4_1" **contradicted** — q4_1 wins on every metric here.
   Deep-context (100k+) error growth unmeasured. Numbers:
   `docs/models/Qwen3.8-27B.md`.
2. **Compute/MTP prompt buffers scale with `ubatch-size` (default 512).**
   leewsimpson: dropping ubatch frees ~370 MB per step "with no measurable
   cost" on their 27B setup. Directly relevant here because Qwen3.8-27B's
   262144/q4_0 and 163840/q8_0 loads both died on a *pp compute buffer*
   cudaMalloc (1360 / 880 MiB) —    the buffer, not the KV, is the wall at the
   margin. Price: prompt throughput. **Our status: measured 2026-08-15 — the
   lever is real but has a ~1 GiB context-driven floor on Qwen3.8-27B@262144
   (1360 → 1192 → 1108 MiB at ub 512/256/128) and unlocked neither OOM case;
   details in `docs/models/Qwen3.8-27B.md`.**
3. **MTP path costs +1–2 GB VRAM headroom** (Lirezh's planning rule). Our
   Qwen3.8 measurements bracket it ctx-dependently at ~1.85 GiB (131072) to
   ~2.6 GiB (229376) — consistent, ours is the sharper number.
4. **`ctx-checkpoints` + `checkpoint-min-step` matter for Qwen hybrids.**
   The DeltaNet/SSM recurrent state cannot be rewound; without checkpoints any
   history edit (agent loops do this constantly) forces a full reprocess.
   This is the same mechanism that makes `cache-reuse` log "not supported by
   this context" on these models — checkpoints are the supported alternative.
   Cost: ~160 MB *host* RAM per checkpoint (Lirezh), zero VRAM. countzero
   sets `ctx-checkpoints = 32`, Lirezh 64 with min-step 1024. Our build has
   both flags (`-ctxcp`, `-cms`, default min-step 8192). **Our status:
   unmeasured, mechanism verified via --help; candidate for the four
   agentic-coding sections.**
5. **`image-min-tokens = 1024` on Qwen VLMs.** countzero sets it on every
   Qwen vision section; our server log actively suggests it
   (`Qwen-VL models require at minimum 1024 image tokens`). VRAM-neutral with
   the mmproj on CPU. **Our status: not set on Qwen3.8-27B — cheap quality
   fix, adopt on next preset touch.**
6. **`ngram-map-k4v` (min-hits 1, n 16, m 24) as the aggressive ngram
   drafter.** Lirezh chains `draft-mtp` + `ngram-map-k4v` and reports up to
   6× on code-paraphrase turns; our sections use the conservative `ngram-mod`
   (48-token minimum chain). Build 10437 lists both. **Our status: unmeasured;
   worth an A/B on a file-rewrite-heavy benchmark, especially anywhere MTP is
   absent or was dropped.**
7. **`reasoning-budget = 16000` as an anti-loop guard** for long agent
   sessions (Lirezh; countzero does not set it). Build 10437 supports it plus
   `reasoning-budget-message`. **Our status: unmeasured, behavioural — decide
   per model, not per card.**
8. **Quality sweet spots, not just fit limits:** Lirezh runs the 27B "as high
   as it fits" but calls it *strongest below ~150k*, and caps 35B-A3B at
   ~110k because reasoning-loop probability rises with context (gut feeling,
   explicitly not benchmarked). Our 147456 pick for Qwen3.8-27B happens to
   sit exactly in that band — cite this only as corroboration, not proof.
9. **Contradiction on file: mixed KV pairs on CUDA.** countzero's
   `main` carries a Qwen3.6 variant at `q5_0`/`q4_1` on a 24-GB CUDA card —
   our measured rule says mixed pairs fall off the fused FA kernel (86→9 t/s,
   gemma-4-31B, 2026-08-04, q8_0/q4_0). Either only *some* pairs collapse, or
   countzero ships a slow section. **Partially resolved 2026-08-15, in our
   rule's favour and beyond it: even the *matched* q4_1/q4_1 pair collapses
   on CUDA (pp ~30 t/s vs q4_0/q4_0's 1989 on Qwen3.8-27B) — matching is
   necessary but not sufficient; only q8_0/q8_0 and q4_0/q4_0 are
   throughput-verified fused pairs here. Any other pair, matched or not,
   needs its own probe first.**
10. **Not transferable:** FP8 KV calibration (NVFP4/Blackwell-only), vLLM/
    SGLang speculative configs, TurboQuant vendor forks (official-builds
    policy, see AGENTS.md), and countzero's `fit = on` + `fit-target`
    DeepSeek pattern (we set `fit = off` deliberately; see
    `docs/llama-operations.md`).

## Rules

- Never write a community value into a preset without a local measurement or
  an explicit "adopted unmeasured from <source>, <date>" note in the model's
  `docs/models/<ID>.md` file.
- Anything adopted here still respects the llama-preset ownership classes —
  community input is vendor-class at best; hardware/agentic-owned keys keep
  winning.
- When a community claim contradicts a measured rule in this repo, that is a
  finding, not an error: record both, re-measure, update whichever was wrong.
- Update the snapshot section (and its date) when re-researching; stale
  community claims are worse than none because they carry false authority.
