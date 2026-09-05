# Qwen3.8-Flash-Next

Qwen3.8-Flash-Next (Qwen team, arch `qwen4exp`, 49 layers) is the first open-weight release of
the architecture behind Qwen4: a **125B-parameter multimodal MoE with 6B active per token**
(512 experts, 10 routed + 1 shared) plus **51B additional n-gram embeddings** that llama.cpp
keeps host-side, and an embedded 1-layer MTP head. Native ctx 262144 (1M via YaRN, not
configured here). Hybrid attention (Gated DeltaNet + Qwen Sparse Attention) → KV is nearly
VRAM-free, same family behaviour as Qwen3.8-27B / Ornith-1.5. Quant: **unsloth UD-IQ3_XXS**
(82 GB, 3-way split GGUF) + `mmproj-F16.gguf`. All numbers measured 2026-09-03 on **hermine**
(RTX 4090) + **lieselotte** (RX 7900 XTX over RPC), llama.cpp build **10766**.

## This model exists on this rig only because of RPC

The smallest quant (UD-IQ1_S, 72.5 GB) exceeds any single card here, and UD-Q2_K_XL (78.9 GB)
exceeds hermine's 24 GB VRAM + 64 GB RAM combined budget once Windows overhead is counted.
The section therefore pools VRAM over llama.cpp RPC: lieselotte runs
`vendor/llama.cpp/ggml-rpc-server -H 0.0.0.0 -p 50052 -d Vulkan0 -c` (the `-c` tensor cache
matters: without it every load re-ships ~19 GB over the LAN), hermine's section carries
`rpc = 192.168.1.39:50052`. Devices seen: CUDA0 21506 MiB free, RPC0 23577 MiB free.
RPC has no auth/encryption — LAN only. Both ends must run the same llama.cpp build.

**Build trap:** `qwen4exp` support was merged 2026-08-27 (base PR #27742) with follow-up fixes
2026-09-01 (#27941), but the `nightly-tag.txt` pointer that `bootstrap.*` follows still pointed
at b10621 (2026-08-25) — *older than the merge*. Both machines are pinned to `b10766` in their
configs until the pointer catches up; an unpinned auto-update would **downgrade** and break the
model with `unknown model architecture: 'qwen4exp'`. See `docs/llama-operations.md`.

## Fit: computed by llama-fit-params, not by n-cpu-moe

`n-cpu-moe` alone cannot make this fit: it strips experts from the *first* N layers, which all
sit on the first device, while the second device's share stays put (measured: CUDA0 pinned at
27.3 GB > 23 GB for every ncmoe 16–22). `llama-fit-params --rpc ... -c 262144` instead emitted
the adopted combination: `-ngl 49 -ts 19,30` plus an `override-tensor` regex pinning
`blk.18.ffn*` to CUDA0, `blk.31.ffn_down` and all expert tensors of blocks 32–48 to CPU.
Verified balance at ctx 262144: RPC0 22240/23577 MiB, CUDA0 20107/21506 MiB (~1.3–1.4 GiB
margin each), host ~44 GiB weights (+0.9 mmproj). ctx is a non-issue on this arch: KV+compute
totals 1.8 / 3.3 / 6.4 GB at 65k/131k/262k, so native 262144 was taken.

## The `device` key collapses throughput — deliberately absent (mechanism now understood)

Adding `device = CUDA0,RPC0` to the section dropped generation **8.4 → 2.9 t/s** (isolated A/B;
with `cache-ram = 16384` on top: 2.7 — cache-ram is noise, `--device` is the culprit).
Mechanism (source-verified 2026-09-03, research pass): llama.cpp's *default* device order puts
**RPC devices first** ("add RPC servers at the front of the list to minimize network transfers",
`src/llama.cpp:274`; rationale + measurements in upstream PR #9296 — last layers, output norm
and `lm_head` stay local, logits (~600 KB/token at this vocab) never cross the LAN). Under the
default order, `-ts 19,30` therefore means **RPC0 = blocks 0–18, CUDA0 = blocks 19–48**, and
the `-ot` CPU-pinned experts (blocks 32–48) are *inside CUDA0's local range* — exactly right:
one contiguous remote segment, ~2 LAN crossings/token. An explicit `--device CUDA0,RPC0` is
honored verbatim and flips the ranges: the CPU-pinned expert blocks land in the *remote* range,
giving 2 LAN crossings per mixed layer per token **plus** a per-device graph-cache
(`last_graph_uid`) that never hits, so full graph metadata is re-serialized per split per token
(the #22850 "metadata storm"). ~34 crossings × ~7 ms ≈ the measured collapse. The section
therefore has **no `device` key**. Corollary: `--n-cpu-moe` (first-N semantics) is always wrong
with RPC-first ordering — it pins the *remote* layers' experts to the host CPU; explicit tail
`-ot` is required. Side effect of no device key: if lieselotte's rpc-server is down, the load
fails loudly — intended.

The three `spec-ngram-mod-n-*` tuning keys were also tested and are innocent (removing them
changed nothing); they were dropped anyway since their values were never measured on this model.

## load-mode = mlock: prefill win, generation neutral

A/B at otherwise identical config (mmap vs `-lm mlock`):

| load-mode | pp t/s (2442-tok prompt) | tg t/s (600 gen) |
|-----------|--------------------------|-------------------|
| mmap (default) | 175.8 | 8.4 |
| mlock | 237.2 (216.5 @ 11929-tok prompt) | 8.5–8.7 |

Adopted `load-mode = mlock` (+25–35 % prefill). Note: Windows reported 34.3 GiB free *during*
mlock'd operation — less resident than the nominal 45 GB host share suggests, consistent with
the n-gram table being read lazily (upstream #28256 "Pathological reads on N-gram embedding
model"). Drop the key if the machine needs RAM elsewhere.

## Speed research 2026-09-03 — where the 113 ms/token go, and the lever list

Community reference points for this model (HF speed thread, unsloth discussions): single
RTX 3090 + DDR4 with heavy CPU-MoE → 15–19 t/s; single 4090 + 96 GB DDR5-5600 + `--fit on`
(whole IQ3_XXS mmap-resident) → ~30 t/s @6k; 2 local 16-GB GPUs → 23.3 t/s; the only other
published *RPC* datapoint for this model (BC250 Vulkan workers) → ~9.5 t/s, right next to ours.
Decode is host-RAM-bandwidth-bound (6B active ≈ ~0.9–2 GB reads/token depending on split); the
network in our topology costs only ~4–10 ms/token (2 crossings, RTT-bound — TG does not care
about 1GbE vs 10GbE bandwidth, only latency). The RPC layer split is pipeline-parallel: each
machine idles while the other computes, so pooling never beats a single machine that fits the
working set — RPC is a capacity play, not a speed play.

**User decision 2026-09-03: the RPC setup is fixed for this model — a single-machine (no-RPC)
comparison run was explicitly ruled out**, so the community's ~30 t/s single-4090 reference
stays a reference, not a plan item.

**Measured tuning series (2026-09-03, router-free window, same tg/pp probes as above):**

| Config | tg t/s | pp 2.4k / 12k t/s |
|---|---|---|
| manual `-ngl 49 -ts 19,30 -ot <regex>` (old section) | 8.5–8.9 | 176–237 / 217 |
| **`fit = on`, `fit-target = 1024,1024`, ctx 261888** | **10.2–10.4** | 236 / — |
| fit on, ctx 131072 | 8.2 | 213 / — |
| fit on + `-ub/-b 2048` | 8.8–9.1 | 276 / 302 |
| fit on + `-ub/-b 1024` | 8.0–8.3 | 223 / 235 |

Adopted: **`fit = on` + `fit-target = 1024,1024`** (router-verified 10.2 t/s) — a deliberate
exception to the repo-wide `fit = off` habit, +~20 % generation over the best hand placement.
The auto-fit's decisions are config-sensitive and non-monotonic (smaller ctx measured *slower*;
bigger ubatch trades ~1.3 t/s tg for +17–28 % pp — rejected, generation dominates agentic use).
The manual `-ngl/-ts/-ot` keys are gone from the section; fit re-derives placement each load,
which also adapts automatically when VRAM conditions change (Windows shell creep etc.).

**Second research pass (2026-09-03, comparable setups + lossless levers):** No public report
matches this exact combo; the closest regime matches are a MiniMax-M2.1 multi-node rig at
12.8–18 t/s over 2.5GbE (more total VRAM) and a GLM-4.6 CPU-expert+RPC rig that *collapsed*
5→2 t/s — 10.2–10.4 sits inside the normal band for "MoE + partial CPU experts + RPC". The
silicon-class ceiling is 20–30 t/s (single box, ryan4yin's 4090/96GB), unreachable over RPC
(sync tax measured at 28–55 % tg in issue #22850, no fix; TCP_NODELAY already set both ends,
no OS-level knobs left; 1GbE→10GbE moves loading/prefill, not decode — decode wire traffic is
20–60 Mbit/s, latency-bound). Realistic target: ~12–15 t/s. Untested lossless levers, ranked:
(1) **thread sweep `-t {8,12,16,24}` with `-tb 24`** — ggml's per-op spin barriers let the 16
E-cores gate the 8 P-cores; P-core-only measured 2.4–3× on full-CPU rigs (scale down: only ~17
expert blocks are on CPU); plus `--prio 2` A/B. (2) **lieselotte: `RADV_PERFTEST=nogttspill`
env on the rpc-server + verify ReBAR** (GTT spill / ReBAR-off measured up to 4× silent loss).
(3) **asymmetric `fit-target` (small CUDA0 margin, large RPC0)** to shift expert blocks onto
the local GPU. Rejected after research: ROCm on the XTX (Vulkan is 25–45 % *faster* at tg on
gfx1100 AND issue #28266 multi-turn collapse on HIP is unfixed), `kv-unified` (no effect at
`parallel = 1`), `--device` reorder (paid off only on a 40Gbps link, #16625; on 1GbE the
logits transfer costs ~5 ms/token and our measured 2.9-t/s collapse stands), Windows TCP
registry tuning (no published measurement).
5. **PLE/n-gram table**: leave it lazy/mmap'd — community evidence (M1 test, 2×3080-on-NVMe)
   says 16 row-lookups/token are cheap and forcing residency buys nothing for decode
   (`--lazy-mode off` exists on b10784 and would cost ~27 GB RAM; `mlock` does NOT cover the
   table, which explains the 34 GiB-free observation). Issue #28256 (pathological small reads)
   and PR #28136 (`on-direct`, unmerged) are prefill/cold-start topics.
6. **Upstream watch**: #28213/#28244 (sparse-attention decode, +8–50 % at ≥50k ctx, unmerged);
   MTP PRs #27836/#28097 (still drafts; M3 Max +36–42 % at n-max 2–3 with 86–89 % acceptance —
   MTP drafts from the model's own distribution and survives temp 1.0, unlike ngram-mod; PR
   itself warns discrete-GPU rigs may regress); **issue #27939: Vulkan assert crash
   (`ggml-vulkan.cpp` push_constant_size) mid-generation with exactly this model over RPC —
   our stack, open, watch for it**.
7. **ctx 262144 → 261888**: upstream notes a CUDA `gridDim.y` overflow abort at the full native
   window (ceiling 261,888) — [claim, not reproduced here]; adopted in the preset as cheap
   insurance.

## Code-level findings (2026-09-04, read from master ≈ b10784 sources; code-derived, not measured)

- **RPC graph reuse is uid-based and works per token** (`RPC_CMD_GRAPH_RECOMPUTE`, 16 bytes)
  — but only while the remote device's layer slice is **one contiguous split**. If CPU-expert
  layers sit inside RPC0's range, the RPC0 splits alternate uids and the client re-serializes
  the full graph metadata (~296 B/tensor, high hundreds of KB) **every token**. Same trap when
  two graphs share the RPC device — target + MTP drafter — so **when MTP lands, the drafter
  must be pinned to local devices (`-devd CUDA0` or CPU)** or spec-decode-over-RPC will pay
  full serialization both ways per round. (`ggml-rpc.cpp:1015`, one `last_graph_uid` per device.)
- **The PLE/n-gram gather runs on CPU serially BEFORE the first RPC segment** (deliberate
  same-split constraint, `qwen4exp.cpp:366`), and its F32 result is uploaded to each consuming
  device per token — including RPC0 over the LAN. With `lazy-mode auto` the row reads page from
  NVMe (hash-random into the table → mostly cold); `--lazy-mode off` would make it resident
  (~27 GB; Windows showed 34.3 GiB free under load, so it fits) — small but strictly-serial
  critical-path cost, worth one A/B.
- **QSA decode on master is strictly more work than dense attention** (full-window masked FA
  plus indexer/top-k overhead; the sparse path is `// TODO` pending #28213). Deep-context tg
  relief only comes from that merge.
- **`--fit` optimizes memory feasibility only** (`common/fit.cpp`): back-to-front dense fill,
  experts→CPU first, then front-to-back expert restore + one partial layer. It has no notion of
  network cost, and nothing stops CPU-expert layers from landing inside RPC0's slice. A hybrid
  config — fit-derived budgets, hand-written topology-aware `-ot` (partial layers only in
  CUDA0's slice), `fit = off` — could beat plain `fit = on`; audit fit's actual placement first.
- DeltaNet recurrent state: fully on-device per token, no host sync (checkpoint slots only with
  speculative n_rs_seq > 0) — nothing to tune there.

## Final measured throughput (router-spawned, warm)

**pp ~176–237 t/s (load-mode-dependent), tg 8.5 t/s** at short ctx; tg 7.6 t/s at ~12k prompt
depth. That is the price of 17 layers' experts on CPU plus 2 LAN hops per token — usable for
chat, slow for agentic loops. E: is NVMe (Kingston Fury Renegade); disk ruled out as the main
bottleneck. First cold request after a spawn reports ~2.6 t/s and is not representative.

## Sampling and reasoning

Card publishes two whole sets; **thinking set adopted whole** (`temp 1.0, top-p 0.95, top-k 20,
min-p 0.0, presence-penalty 0.0`), same reasoning as Qwen3.8-27B (`docs/models/Qwen3.8-27B.md`).
Template scan: thinking on by default, template consumes `reasoning_content` from history →
`reasoning-preserve = true` (build 10766 auto-enables it for this template and logs that; the
key documents intent). `cache_reuse` is disabled at runtime by multimodal, same as Qwen3.8-27B.
`reasoning-format = auto` separation verified live (reasoning_content populated, content clean).

**Vision verified live** (2026-09-03, router on b10784 ↔ lieselotte rpc-server b10766 — those two
builds are RPC-compatible): a 128×128 half-red/half-blue test PNG sent as OpenAI `image_url`
was described correctly and precisely; generation stayed at 8.8 t/s. `mmproj-offload = false`
keeps the encoder on CPU (no VRAM cost; encode time untested for large images). Caveat while
the rpc-server handles connections serially: a second client probing `--rpc` (even just
`--list-devices`) *hangs* while an instance is loading — looks like a version mismatch but is
just queueing.

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
  (sparse-attention decode), issue #28266 (multi-turn collapse on HIP/gfx1100 — lieselotte is
  Vulkan, not observed here, untested long-run).
- **OpenCode providers**: not yet added to `opencode.jsonc` — hermine-only ID would break the
  "both providers list the same IDs" convention; user decision pending.
