# llama.cpp operations — cross-model measurements and hermine hardware
> Extracted verbatim from AGENTS.md on 2026-08-15. "Above/below" references may point
> to sibling files in this directory or back to AGENTS.md.

## config-load.sh precedence and the CRLF fall-through

Config in `config.env` (gitignored; copy from `config.env.example`). On the Windows host there is no `config.env` — it configures itself in `config.ps1` (also gitignored, and it holds a plaintext `HF_TOKEN`). All four bash entry points therefore load their settings through `config-load.sh`, which resolves `config.env` > `config.ps1` > `config.env.example`. **Until 2026-09-24 that chain was documented as starting with the environment, and the code implemented it for exactly three keys** (`LLAMA_MODELS_DIR`, `LLAMA_PRESET`, `LLAMA_VERSION`, restored after sourcing) while silently clobbering every other `LLAMA_*`. The gap was found by `LLAMA_PORT=8099 ./server.sh` binding 8081; the same defect meant `LLAMA_AUTO_UPDATE=0` never disabled the update check, which had been used in that belief several times the same day. Per user decision the file is now authoritative outright — no environment override at all, including `LLAMA_VERSION`, so a build is pinned for RPC work by editing `config.env`. Before that existed, `server.sh`, `download-model.sh` and `bootstrap.sh` were **completely broken on hermine** (verified 2026-08-05): they fell through to `config.env.example`, which carries CRLF, and `source` then fails on every line with `$'\r': command not found`. Falling through was wrong twice over — that file also assigns a Linux models path and `LLAMA_BACKEND=vulkan`, so a working `source` would have pointed at a nonexistent directory and fetched a Vulkan build for a CUDA box. `recommend.sh` keeps its own copy of this logic on purpose: it must run standalone from the skill directory.

## server.sh on hermine: the two defects

`server.sh` could not actually **serve** on hermine until 2026-08-05, only `--list`. Two separate defects, both found by running it: `resolve_bin` searched for `llama-server` and not `llama-server.exe`, and once that was fixed the Windows binary got the POSIX `/mnt/c/...` models dir and died with `does not exist or is not a directory`. Paths handed to an `.exe` now go through `host_path()` (`wslpath -m`) while bash keeps the POSIX form for its own `find`/`-f` tests. Verified end-to-end: the router logs `Loaded 8 custom model presets` and `/v1/models` lists all eight (plus one entry from llama.cpp's own HF cache, which is not ours).

## fit = off survey

`fit = off` is set in **all twelve** sections of both preset files, but it is only *load-bearing* in `Ornith-1.0-35B`, where `fit = on` silently moves MoE experts to CPU and costs ~30 %. Measured elsewhere it is a no-op: gemma-4-31B and Qwen-AgentWorld show no `tensor overrides to CPU` either way. It is set uniformly so a VRAM shortfall fails loudly instead of silently switching to a slower configuration — before 2026-08-05 it was present in 4 of 8 sections purely by accident of which ones had been touched.

## WSL-on-Windows traps

Two WSL-on-Windows traps when testing a server by hand on hermine, both cost a wasted run: `--host 127.0.0.1` binds the *Windows* loopback and is unreachable from WSL (use `0.0.0.0` plus the gateway IP from `ip route`; the name `hermine` does **not** resolve from inside WSL on hermine itself, only from the LAN). And `nohup ./llama-server.exe &` returns the *bash* PID — `taskkill /PID` on it leaves the Windows process alive holding VRAM, which then makes the next start fail with `failed to load draft model`. Kill by image name (`taskkill /F /IM llama-server.exe`) and wait for `nvidia-smi` to drop — but **only when no other llama-server is meant to stay alive**: killing by image name also takes down the user's router. When one is running, get the PIDs from `tasklist.exe` before starting a test instance and kill only your own.

## GT 610 display GPU and the legacy-driver conflict

**hermine drives its display from a GT 610 since 2026-08-15; the 4090 idles at ~22–44 MiB.** Every VRAM figure in this file measured before that date sat on a 394–1172 MiB desktop baseline, so old "free VRAM" numbers understate what fits today — re-measure before trusting them at the margin. The install itself broke the machine first, and the fix is worth recording because Windows Update *will* try to reproduce the breakage: the GT 610 is Fermi, its last driver line is 388/391, and WU auto-installed `nv_ref_pubwu.inf` (388.13) on detection. Windows cannot load two NVIDIA KMDs, so the 4090 went to Code 31 (later 39) and `llama-server --list-devices` reported *no devices at all* — while `device = CUDA0` in the presets was never the problem and still names the 4090 (the GT 610 has no CUDA support and is invisible to llama.cpp; there is nothing to pin). Fix, verified: `pnputil /delete-driver oemXX.inf /uninstall` on the legacy package (it was `oem118.inf`; re-enumerate with `pnputil /enum-drivers`, the giveaway is `nv_ref_pubwu.inf` + version 23.21.13.8813), reboot; if the 4090 then shows Code 39, `pnputil /remove-device "<instance-id>"` + `pnputil /scan-devices` rebinds it to the store's modern driver (`nv_dispi.inf`) without any download. Target state in Device Manager: 4090 = NVIDIA driver OK, GT 610 = **Microsoft Basic Display Adapter** — never install an NVIDIA driver for the GT 610. If the 4090 dies again after a WU cycle, it is this, same fix.

## CUDA KV-cache pairing rule

On CUDA (hermine), `cache-type-v` MUST equal `cache-type-k`. Measured 2026-08-04 with gemma-4-31B @ 65536 + MTP: matched `q8_0`/`q8_0` yields 2391 t/s prompt / 86 t/s generation, the mixed `q8_0`/`q4_0` pair collapses to 32 t/s / 9 t/s because it falls off the fused FlashAttention kernel. Untested on Vulkan (Gertrude), whose presets still use the skill's `q8_0`/`q4_0` floor — so the llama-preset skill's V-floor is not safe to apply blindly on the CUDA box.

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

## RPC: pooling a second machine's GPU into hermine's server

**The measurements that used to be here were removed 2026-09-22.** They were taken with the
7900 XTX sitting in `lieselotte` (i9-14900K host) and hermine pulling it in over RPC. The card
has since moved into `Gertrude` (i9-9900K, 31 GB RAM) and lieselotte has no GPU at all any
more, so every pooled number — the `-ts` sweep, the ~10 ms/token sync tax, the speculation
ladder that bought it back, the `device`-key collapse — was host-dependent and is void. Nothing
was re-measured on the Gertrude/hermine pair; if RPC pooling is picked up again, measure it
from scratch.

What survives is build- and protocol-level, not hardware-level:

- Official prebuilts ship `ggml-rpc-server(.exe)` + `libggml-rpc`/`ggml-rpc.dll` (verified in
  both the win-cuda and ubuntu-vulkan b10621/b10766 archives), so no source build is needed.
- `-d <GPU>` on the rpc-server keeps the remote CPU out of the pool; `-c` caches shipped
  tensors on the remote disk — without it every model load re-transfers the full weights.
- `llama-fit-params` and `llama-server` both accept `--rpc` (env `LLAMA_ARG_RPC`); fit-params
  emits a ready `-ngl/-ts/-ot` combination for the pooled devices. `recommend.sh` predates RPC:
  its device table only shows local devices and it misreads split GGUFs (sees the 10 MiB first
  shard, calls a 125B MoE "dense", derives the section name from the quant subdir) — for RPC
  models, run fit-params by hand and use the script only as checklist.
- RPC protocol: no auth, no encryption, version-matched builds on both ends. LAN only, and use
  the IP rather than a hostname (`hermine`-style names are unreliable across the WSL/Windows
  resolver split).
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


## Claude Code's trailing system message vs. the Qwen chat templates (2026-09-14)

Every `claudelocal` turn against hermine's router returned HTTP 500 with
`Jinja Exception: System message must be at the beginning.` (line 106 of the
`Qwen3.8-27B` GSQ template). Cause, captured with a logging proxy in front of
`hermine:8081` while a real `claude -p` session ran against it:

- Claude Code posts to `/v1/messages?beta=true` with the harness prompt in the
  top-level `system` field **and an extra `{"role": "system"}` message appended
  at the END of `messages`** (content: the "Available agent types for the Agent
  tool" listing). Captured shape: `roles = ["user", "system"]`.
- llama.cpp's Anthropic adapter passes that role through verbatim. The Qwen
  templates reject any system message that is not `messages[0]`, so the render
  aborts before the model is ever reached. The one request in the capture
  without the trailing block (`roles = ["user"]`) returned 200.

Affected templates (checked by reading `tokenizer.chat_template` out of each
GGUF listed in `models.ini`):

| Model | Raise present |
|-------|---------------|
| `Qwen3.8-27B` (GSQ-RCO), `Qwen3.8-27B-UD`, `Qwen3.8-27B-UD-Q8_K_XL…rpc`, `Ternary-Bonsai-27B`, `Qwen3.8-Flash-Next` | yes |
| `Qwen3.6-35B-A3B`, `Laguna-XS-2.1`, `Ornith-1.5-35B-A3B`, `Muse-Glimmer-30B` | no |

Three distinct template variants exist among the affected five: the GSQ-RCO one
(`not loop.first` guard), the Ternary-Bonsai one (same guard, different body),
and one file shared **byte-identically** by `UD-Q4_K_S`, `UD-Q8_K_XL` and
`Qwen3.8-Flash-Next` (`num_sys` guard, also covers `role == "developer"`).

Fix: the templates were extracted to `llama.cpp/presets/templates/*.sysfix.jinja`
with that single `raise_exception` replaced by rendering the message as its own
`<|im_start|>system … <|im_end|>` turn, and wired in via `chat-template-file`.
Verified by running two `llama-server` instances (CPU-only, `-ngl 0`, ctx 2048,
same GGUF, one per template) and diffing `/apply-template` output: plain,
multi-turn and tool-call conversations render **byte-identical** to the
unpatched template; only the trailing-system case differs (error → rendered).
A real `/v1/messages` request in the captured Claude Code shape returns 200 on
the patched server and 500 on the unpatched one.

Notes for the next reader:
- This is a client-side quirk (the public Anthropic API has no system role
  inside `messages`), so it will reappear for every model whose template
  enforces the rule — check a new GGUF's template before adding a preset.
- `llama-fit-params`-style probing is not needed here: the template is
  model-independent at render time, so a patched file can be validated against
  any loaded GGUF via `/apply-template`.
- The patched files are tracked in the repo; `models.ini` is not. After
  changing a template, the router must be restarted to pick it up.

## amdgpu runtime-suspends the card and evicts the model into host RAM (Gertrude, 2026-09-24)

The single most expensive fault in this repo's history so far, and it hid for days. `amdgpu` runs with
`power/control=auto` and `autosuspend_delay_ms=5000`: five seconds after the last GPU access the card
runtime-suspends, and the driver moves its VRAM contents into host memory (GTT). `llama-server` neither notices
nor reports it — it keeps answering over PCIe at a fraction of the speed while pinning ~16 GiB of system RAM, and
it never migrates back. One episode ran **two days** undetected and left the 32 GB box at 273 MiB free RAM with a
full swap; that is what prompted the investigation, via the unrelated-looking question "why is the RAM full".

The decisive measurement, same configuration both phases: **a request every 10 s held 19809 MiB of VRAM steady
across nine samples over 90 s; 15 s of idle dropped it to 26 MiB VRAM / 15944 MiB GTT.** `power/runtime_suspended_time`
stood at ~260206 s against a 72 h uptime — the card had been asleep essentially the whole time.

**Four wrong diagnoses preceded it, and each was disproved by measurement**, which is why they are recorded here:
(1) a one-off consequence of an OOM-kill — refuted, it recurred; (2) the router's model switching — refuted, a
single switch stayed clean and the exact failing three-switch sequence replayed clean; (3) VRAM headroom pressure —
refuted, it evicted at 2652 MiB free, more headroom than a configuration that stayed stable; (4) something specific
to the Q4_K_XL weights — refuted by the idle/active split above. The common error in all four: **every
reproduction attempt measured immediately after a request**, inside the 5 s wake window. A one-shot check after
loading cannot see this fault at all.

**Fix: `amdgpu.runpm=0` in `GRUB_CMDLINE_LINUX_DEFAULT`**, verified across a reboot — `power/control=on`,
`runtime_status=active`, 60 s idle with no eviction, no manual step. A udev rule keyed on vendor/device
(`ATTR{vendor}=="0x1002", ATTR{device}=="0x744c", ATTR{power/control}="on"`) was written first and **measured not
to work**: the attribute is set before `amdgpu` binds and the driver then overrides it. Delete it rather than
leave it as decoration. `echo on > /sys/bus/pci/devices/<addr>/power/control` works immediately but does not
survive a reboot.

`llama.cpp/tools/healthcheck.sh` remains as the safety net for whatever else can produce the same end state, and
caught a real incident before the cause was known. Its detector is amdgpu-specific and **does not transfer to
hermine**, where the Windows driver spills into shared memory while `nvidia-smi` "used" still looks plausible —
that host needs a throughput probe instead.

## The "hard 22.5 GB VRAM cliff" on Gertrude never existed

Gertrude's `models.ini` header carried, for weeks, a measured-looking claim: throughput collapses by a factor of
three above ~22.5 GB of occupied VRAM, "22461 MiB runs, 22855 MiB tips", re-verified on kernel 6.12 as "22854 MiB
still only delivers 22 t/s". **All of it was the runtime-suspend eviction above.** The "collapsed" runs were runs
that had fallen into host memory between the load and the measurement.

Measured after the fix: **23002 MiB occupied gives a 60.6 t/s median** — 147 MiB past the supposed tipping point
and the fastest figure ever recorded on that box. The lesson is not about VRAM: a number that only ever appears
together with a second, unmodelled failure mode will encode that failure mode instead of the thing being measured.

Consequence for the archive: **every throughput number taken on Gertrude before 2026-09-24 14:00 is suspect.**
A same-session comparison of UD-Q4_K_S against UD-Q4_K_XL read 34.6 vs 51.8 t/s under the eviction regime and
58.5 vs 60.6 t/s once it was gone — the entire apparent gap was the artefact, and a preset decision had already
been taken on the strength of it.

## Second GPU on Gertrude: Vulkan enumeration and the card-number trap (2026-09-24)

An RTX 3060 was added for image generation alongside the 7900 XTX. Debian's `nvidia-driver` **535.309.01** from
`non-free` builds against kernel **6.12.95** via DKMS and loads cleanly. Two things to know before repeating this:
**`bookworm-backports` carries no `nvidia-driver` at all**, so `apt install -t bookworm-backports nvidia-driver`
fails on an unsatisfiable dependency mix rather than doing anything useful, and `non-free` has to be added to
`sources.list` first (`non-free-firmware` alone is not enough). DKMS builds during `apt install`, so a build
failure is immediate and visible, not a post-reboot surprise. `dkms` lives in `/usr/sbin`, which is not on a
normal user's PATH — `dkms: command not found` after a successful install means nothing.

The driver installs `nvidia_icd.json`, so llama.cpp now enumerates **`Vulkan0` = 7900 XTX, `Vulkan1` = RTX 3060**.
`device = VULKAN0` therefore still resolves to the AMD card — but llama.cpp selects by **index**, with no
name-based option, so **`--list-devices` must be re-checked after every driver or BIOS change**. Disable the
serving unit before the reboot that activates a new driver; otherwise it can come up on the wrong card unattended.

Installing the card also **renumbered the AMD GPU from `card0` to `card1`**, which silently pointed every
`card0`-hardcoded helper at the NVIDIA card. Address GPUs by PCI id (`/sys/bus/pci/devices/0000:03:00.0`) or find
them by probing for `mem_info_vram_used` plus `vendor == 0x1002`; `healthcheck.sh` does the latter and survived
the change untouched.

**`llama-fit-params` now needs `-dev Vulkan0`, or it measures a configuration that never runs** (found
2026-09-26). With two Vulkan devices present it fits across *both* by default, while every preset here pins
`device = VULKAN0`. The same model, same build, same KV types:

```
without -dev:        Vulkan0  8808 1119 1114     Vulkan1  9940 1663 1615
with -dev Vulkan0:   Vulkan0 18748 2782  498  =  22028 MiB
```

The split figure is less than half the real one. This was caught only because the reference model no longer
reproduced its 2026-09-24 number — a sweep of a *new* model alone would have looked entirely plausible and been
wrong by 12 GB. Add `-dev <device>` to every fit-params invocation on a multi-GPU box, and keep one known model
in the sweep as a control.

The box is headless — no connector on either card reports `connected` — so there is no Xorg or display-provider
risk, and `amdgpu` is in-kernel, so `apt purge '~nnvidia'` is a clean rollback that cannot affect it. One
unexplained observation: the same preset occupied 23419 MiB before the reboot and 24186 MiB after it. Both
figures are post-fix, so it is not the old eviction; separating the driver's presence from `runpm=0` would mean
removing the driver again and was judged not worth it.
