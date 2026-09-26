# AGENTS.md

## Repository purpose

A personal tooling collection and local AI stack: curated developer tool references (`README.md`), bash config backups, OpenCode config backup, Claude config backup, and a fresh-Linux bootstrap guide.

No build system, no tests, no CI. All content is documentation and shell scripts.

## Structure

```
tooling/
├── README.md                        # Curated tool/service link list
├── docs/                            # Deep-dive docs, loaded on demand (see below)
│   ├── models/<model-ID>.md         # Per-model preset rationale + measurements
│   ├── llama-operations.md          # Cross-model measurements, hermine hardware
│   ├── llama-recommend-sh.md        # recommend.sh rewrite history
│   └── opencode.md                  # Guard, permissions, provider findings
├── .claude/skills/                  # Project-local skills (Claude Code reads these)
│   ├── llama-preset/                # models.ini section generator + recommend.sh
│   ├── llama-4090-community/        # Community tuning levers for 24GB/4090 (read by llama-preset)
│   └── claudelocal-models/          # Syncs the claudelocal modelPicker with /v1/models
├── bashrc-backup/                   # Bash config to deploy to ~
│   ├── .bashrc                      # PS1 + sources aliases/functions
│   ├── .bashrc-aliases              # All shell aliases
│   ├── .bashrc-functions            # All shell functions
│   └── install.bash                 # Deploys to ~; replaces CUSTOM block
├── opencode-backup/
│   ├── opencode.jsonc               # OpenCode global config
│   ├── AGENTS.md                    # Global personal rules -> ~/.config/opencode/AGENTS.md
│   ├── skills/                      # OpenCode skills, incl. commit-push (agents/ too if present)
│   └── install.sh                   # Copies config + AGENTS.md + skills/ to ~/.config/opencode/
├── claude-backup/
│   ├── .claude/skills/              # Global Claude Code skills and references
│   ├── .claude/hooks/               # Hook scripts (skills-overview.sh, SessionStart)
│   ├── hooks.md                     # settings.json snippets to register the hooks
│   └── install.sh                   # Add-only install into ~/.claude/ (skills + hooks)
├── llama.cpp/                       # Local LLM inference (prebuilt Vulkan llama.cpp)
│   ├── bootstrap.sh                 # Fetch+extract prebuilt Vulkan release into vendor/
│   ├── download-model.sh            # Pull GGUF(s) from HuggingFace to $LLAMA_MODELS_DIR
│   ├── server.sh                    # Start llama-server (router, single GGUF, or --section from models.ini)
│   ├── config-load.sh               # Sourced by all three: config.env > config.ps1 > .example
│   ├── config.env.example           # Paths/version/port (copy to config.env)
│   ├── models.example.list          # Download manifest template (copy to models.list)
│   ├── models.list                  # HuggingFace download manifest (gitignored)
│   ├── presets/models.example.ini   # Router preset template
│   ├── presets/templates/           # Patched chat templates (system-message fix)
│   ├── tools/healthcheck.sh         # Periodic check: model evicted VRAM -> host RAM?
│   ├── tools/systemd/               # Timer + service units for the health check
│   ├── PLAN.md / README.md          # Design + usage
│   └── vendor/ cache/               # Binaries + downloads (gitignored)
├── vllm-backup/                     # Second engine (vLLM, WSL-only), measured & documented
│   ├── config.env.example           # Model/port/ctx (copy to config.env)
│   ├── install.sh / serve.sh        # venv+download / OpenAI server :8091
│   └── README.md                    # Measured verdict vs llama.cpp (loses for this workload)
├── comfyui-backup/                  # Image generation (ComfyUI on the RTX 3060)
│   ├── config.env.example           # ComfyUI dir, bind, torch index (copy to config.env)
│   ├── install.sh                   # Clone + venv + pinned torch + ComfyUI-GGUF node
│   ├── download-models.sh           # Pull the manifest into ComfyUI/models/
│   ├── models.example.list          # Qwen-Image-2.1 int8 safetensors + encoder + VAE
│   ├── serve.sh / systemd/          # Server on :8188 + user unit
│   └── README.md                    # Measured sizing/timings, Hermes wiring
└── fresh_linux/debian-based/
    └── bootstrap-guide.md           # New machine setup checklist
```

## Install commands

| What | Command |
|------|---------|
| Bash aliases + functions | `cd bashrc-backup && bash install.bash` |
| OpenCode config | `cd opencode-backup && bash install.sh` |
| Claude Code config | `cd claude-backup && bash install.sh` |
| Local llama.cpp (Vulkan) | `cd llama.cpp && cp config.env.example config.env && bash bootstrap.sh` |
| ComfyUI (image gen, CUDA) | `cd comfyui-backup && cp config.env.example config.env && cp models.example.list models.list && bash install.sh` |

- `bashrc-backup/install.bash` deletes the `# CUSTOM START` … `# CUSTOM END` block from `~/.bashrc`, appends the new block at the end, then calls `exec bash -l` to reload the shell. Since 2026-09-22 it no longer clobbers the `export *_API_KEY=` lines with the template's `insert_api_key_here` placeholder: it reads each key's current value out of the old block and asks per key whether to keep it (Enter) or type a new one; input is silent (`read -s`) and never echoed, and without a terminal on stdin it keeps the existing values and asks nothing. The key list is derived from the template, so a new `export FOO_API_KEY=` line in `.bashrc` is picked up automatically.
- `opencode-backup/install.sh` copies `opencode.jsonc` to `~/.config/opencode/opencode.jsonc`, `AGENTS.md` to `~/.config/opencode/AGENTS.md`, any `agents/*.md` to `~/.config/opencode/agents/`, and `skills/*/` to `~/.config/opencode/skills/` (creates dirs if needed). Add-only: existing agents/skills/plugins from other sources are kept. It ships **no plugin** — the bash guard comes from `stadtwerk_ai_config` (see below).
- `claude-backup/install.sh` merges all bundled skills into `~/.claude/skills/` and hook scripts into `~/.claude/hooks/`: unrelated skills and extra files are kept, while files under the same bundled skill path are updated. It does **not** edit `~/.claude/settings.json` (that file also holds the team command guard); hook registration is a manual merge from `claude-backup/hooks.md`. It copies the gitignored `settings.local.json` with mode `0600` when present and skips it on a fresh clone. The installer resolves paths relative to itself, so it can be run from any directory.

## Key aliases (after install)

| Alias | Expands to |
|-------|-----------|
| `oc` | `opencode` |
| `g` / `gs` / `gp1` / `gp2` | `git` / `git status` / `git pull` / `git push` |
| `gac 'msg'` | `git add . && git commit -m 'msg'` |
| `gcob <branch>` | `git switch -c <branch>` |
| `gl` | fancy graph git log |
| `c` / `h` | `clear` / `history` |
| `k` | `kubectl` |
| `kg` / `kl` / `kp` | `kubectl get pod` / `kubectl logs` / `kubectl port-forward` |
| `kdepl` / `kstate` | `kubectl get deployment` / `kubectl get statefulset` |
| `ksvc` / `ks` / `kexs` | `kubectl get svc/secrets/externalsecrets` |
| `kpv` / `kpvc` | `kubectl get pv/pvc` |
| `kr` / `krs` | `kubectl rollout restart deployment/statefulset` |
| `goprod` / `gotest` | `kubectx` to prod / test EKS cluster |
| `gobastion` | exec into documentdb-client pod in alfresco namespace |
| `flux1` / `flux2` | reconcile flux-system source / apps kustomization |
| `awslogin` | `aws sso login --profile c4-sso` |

## Key functions (after install)

| Function | Purpose |
|----------|---------|
| `go <ns>` | Set current kubectl namespace, then print `whereami` |
| `whereami` | Show kubectx + current cluster/namespace |
| `watching <alias>` | `watch` the command behind a shell alias |
| `kex <pod>` | `kubectl exec -it <pod> -- sh` |
| `kd <type> <name>` | `kubectl describe <type> <name>` |
| `klp <pod>` | Pod logs piped through `pino-pretty@13.0.0` |
| `kwo <ns>` | Watch pods in namespace, filtering out `c4-*` |
| `serve <app> <flags>` | `nx serve` piped through `pino-pretty@13.0.0` |
| `restarting <type> <ns>` | Restart all `c4-*-backend` deployments/statefulsets in a namespace |
| `kdel <type> <name>` | Delete a k8s entity with confirmation prompt |
| `delete_with_status <ns>` | Delete pods with `ContainerStatusUnknown` in a namespace |

This table said `switch <ns>` until 2026-08-11, when a live check showed no such function exists. The namespace switcher is `go` and always was in the installed shell; only its own `check_args` usage string still prints `switch <namespace>` (`.bashrc-functions:147`), which is a leftover from the rename. Do not "correct" the function name to match that string — `go` is what is used.

## Deep-dive docs (load on demand)

Measured details, per-model rationale and dead ends live in `docs/` and are deliberately not
inlined here, so a fresh session starts small. Rule: **before working on one of these topics,
read its file first** — the summaries in this file are not sufficient at the margin, and the
docs record which numbers are measured vs. computed. When retuning or re-measuring, update the
doc file; this file only carries the one-line summary.

| Topic | File |
|-------|------|
| Per-model preset rationale + measurements (13 models) | `docs/models/<model-ID>.md` |
| Cross-model llama.cpp measurements, hermine hardware, WSL traps | `docs/llama-operations.md` |
| recommend.sh rewrite history | `docs/llama-recommend-sh.md` |
| OpenCode guard, permissions, provider findings | `docs/opencode.md` |
| Inference-engine alternatives (vLLM measured, others assessed) | `docs/inference-engines.md` |

## OpenCode config notes

- No global default `model` is pinned in `opencode.jsonc` (pick per session).
- `opencode-backup/AGENTS.md` → `~/.config/opencode/AGENTS.md` holds the **global personal rules** (currently: German conversation / English artefacts, the human-vs-agent writing register, measured-vs-guessed numbers, cleaning up processes and temp files you started, and verifying documented values against the live system with read-only commands). Global and project rules are separate categories in OpenCode, so this file is loaded *in addition to* a project's own `AGENTS.md`, in every session. That is deliberate: a preference that must hold for every edit belongs here and not in a skill, because skills only enter context when their `description` matches and they are known to undertrigger. Keep the file short — it costs context in every session.
- **Fleet**: `Gertrude` (this box — i9-9900K, 31 GB RAM, RX 7900 XTX, Vulkan, runs the local router on `:8081` as the systemd user service `llama-server.service`) and `hermine` (RTX 4090, CUDA, WSL on Windows). A third machine, `lieselotte`, held the 7900 XTX until 2026-09-22; the card moved into Gertrude, lieselotte has no GPU any more and is out of scope. **Its measurements were deleted rather than re-attributed** — different CPU, RAM and LAN path, so nothing pooled or host-bound transfers. Affected docs carry a dated removal note. Since 2026-09-24 Gertrude also holds an **RTX 3060** (PCI `0000:05:00.0`, chipset slot) intended for image generation; it is invisible to Vulkan (no NVIDIA Vulkan driver installed), so `device = VULKAN0` still resolves to the 7900 XTX. Installing it renumbered the AMD card from `card0` to `card1` — address GPUs by PCI id in scripts.
- Two llama.cpp providers: `gertrude` (local, `127.0.0.1:8081`) and `hermine` (remote, `hermine:8081`). Model IDs are bare aliases without the `.gguf` suffix.
- Both `gertrude` and `hermine` list the same thirteen base model IDs (`models` maps match their `whitelist` exactly): `Qwen3.8-27B`, `Qwen3.6-27B`, `Qwen3.6-35B-A3B`, `gemma-4-26B-A4B`, `Ornith-1.0-9B`, `Ornith-1.0-35B`, `Ornith-1.5-35B-A3B`, `Qwen-AgentWorld-35B-A3B`, `gemma-4-31B`, `Laguna-XS-2.1`, `Ternary-Bonsai-27B`, `Muse-Glimmer-30B`, `Nemotron-3.5-Lightning-30B-A3B` — **except that hermine's provider still carries the A/B twin pair `Qwen3.8-27B-small` / `Qwen3.8-27B-large` (fourteen IDs there), and both are dead**: since 2026-09-07 hermine's router serves `Qwen3.8-27B` (GSQ-RCO IQ3_S, 262k) and `Qwen3.8-27B-UD` (UD-Q4_K_S, 131k) instead (see the Qwen3.8-27B line below; `Qwen3.8-27B-lang` existed only 2026-09-06/07 and is gone); the provider was not updated yet, and hermine's `Qwen3.8-27B` section name now collides with Gertrude's plain ID (different machine/quant). `Ornith-1.5-35B-A3B` was added to both providers 2026-08-20 (backup + live synced); its GGUF is only verified present on hermine. The `Qwen3.8-27B` and Nemotron GGUFs are only verified present on hermine. Since the 2026-09-07 pruning, the provider IDs `Qwen3.6-27B`, `Ornith-1.0-9B`, `Ornith-1.0-35B`, `Qwen-AgentWorld-35B-A3B` and (since later that day) `Nemotron-3.5-Lightning-30B-A3B`, `gemma-4-31B` and `gemma-4-26B-A4B` are also dead on hermine (sections removed; Gertrude's own models.ini was not touched). Disk-verification history: `docs/opencode.md`. Note 2026-08-15: the live `~/.config/opencode/opencode.jsonc` had lagged the repo backup (Nemotron missing) because `install.sh` was never re-run; the backup was synced over it that day after checking the live file held nothing extra.
- **Model ID = `models.ini` section name, case-sensitive.** Take IDs from `/v1/models`, never from the `alias` key (often a bare filename); two lowercase entries were dead for this reason. Details: `docs/opencode.md`.
- `gemma-4-26B-A4B` and `gemma-4-31B` are declared image-capable in `opencode.jsonc` but have no `mmproj` on disk — genuinely multimodal are `Muse-Glimmer-30B` and `Qwen3.8-27B`. Left as-is deliberately (capability decision, not a typo). Details: `docs/opencode.md`.
- **Per-model deep-dives live in `docs/models/<ID>.md` — read the model's file before touching its preset, retuning it, or citing any of its numbers.** One line each (hermine values):
  - *Pruned 2026-09-07 (user decision, agentic-fleet cleanup): `Qwen3.6-27B`, `Ornith-1.0-9B`, `Ornith-1.0-35B`, `Qwen-AgentWorld-35B-A3B`, `Nemotron-3.5-Lightning-30B-A3B`, `gemma-4-31B`, `gemma-4-26B-A4B` (the last three removed later the same day) — sections removed from both preset files and `models.list`; their `docs/models/<ID>.md` files stay as measurement records, GGUFs still on E: (not deleted). Rationale: superseded by the Qwen3.8 pair / Ornith-1.5, AgentWorld is a world model, not an assistant.*
  - `Qwen3.8-27B` — dense 27B VLM (arch `qwen35`), embedded MTP. **On Gertrude the daily driver since 2026-09-24 is `[Qwen3.8-27B]` = unsloth UD-Q4_K_S at ctx 229376** (23226 MiB, 1334 MiB free, tg median 55.0 t/s, `reasoning-effort = high`); it is the only id the router exposes there. It replaced UD-Q4_K_XL after an aider-polyglot A/B on that box — see `docs/models/Qwen3.8-27B.md`. GSQ-RCO IQ3_S and UD-Q3_K_XL were dropped from Gertrude the same day (GGUFs kept on disk). hermine's own preset is unchanged and still carries its separate quants.
  - `Qwen3.6-35B-A3B` — 35B-A3B MoE, embedded MTP; 262144 / q8_0 / `draft-mtp,ngram-mod`, coding sampling set. **On Gertrude the weights are `llmfan46`'s uncensored "heretic" Q4_K_S since 2026-09-26** (19.03 GiB, replacing unsloth UD-IQ4_XS at 16.96 GiB; the id and all tuning are unchanged, only `alias`/`model` moved). Measured swap: 23185 MiB against 20819, so **2.4 GB less headroom** — 1375 MiB free, still above the 600 MiB rule — and **no speed difference that survives the noise** (tg median 108.5 vs 104.4, ranges 89.8–111.0 vs 98.5–120.2, n=4 each). Architecture `qwen35moe` and the MTP tensors were verified against the old file before downloading, not taken from the repo name. Quality is untested. The old GGUF stays on disk.
  - `Ornith-1.5-35B-A3B` — 35B-A3B MoE agentic coder (`qwen35moe`, hybrid attention → ctx is VRAM-free); 163840 / q8_0 / `ngram-mod`, `reasoning-preserve = true`, temp 0.6. **ctx is a pure speed choice, not a fit choice** (measured sweep: 131072~83 → 262144~65 t/s; 163840 picked by user). **Embedded MTP head, but `draft-mtp` measured 15–20 % slower — do not re-add without re-measuring.** Added 2026-08-20 (both OpenCode providers, backup + live).
  - `Laguna-XS-2.1` — 33B-A3B MoE agentic coder; 163840 / q8_0 / `ngram-mod`; **`reasoning = on` required** (template defaults thinking off).
  - `Ternary-Bonsai-27B` — ternary 1.71 bpw Qwen3.6-27B; 262144 / q8_0 / `ngram-mod`; only the `Q2_g64` pack loads on stock llama.cpp, DSpark drafter closed by official-builds policy.
  - `Muse-Glimmer-30B` — **removed 2026-09-21 (user decision): preset section deleted from this machine's `presets/models.ini`, `models.list` lines commented out, the 19 GB of GGUFs deleted from `$LLAMA_MODELS_DIR`; `docs/models/Muse-Glimmer-30B.md` stays as the measurement record.** Was: dense 30B agentic multimodal; 131072 / q8_0 / `draft-dflash,ngram-mod` **n-max 16**, mmproj resident on GPU. The OpenCode providers in `opencode-backup/opencode.jsonc` still list the ID — not cleaned up yet.
  - `Qwen3.8-Flash-Next` — 125B MoE (6B active, `qwen4exp`) + 51B n-gram table; **hermine-only, local since 2026-09-07 (RPC dissolved — dropping it alone doubled tg)**: UD-IQ3_XXS via mmap (NO `load-mode` — the n-gram table stays lazily on NVMe, experts page-cache into RAM, box runs at ~3 GB free RAM under load), 261888 ctx, **`threads = 8` (P-cores only on the 13900KF — 12/16/24 all measured slower, spin-wait trap)**, `threads-batch = 24`, **`ubatch/batch = 1024` (+56 % pp at zero tg cost; 2048 doubles pp but costs a third of tg)**, `fit = on` + `fit-target = 1024,1024` (load-bearing). Measured: **tg 20–23 t/s, pp@19k ~370**, ~1.3 GiB VRAM free. No spec-type (ngram-mod 4 % acceptance; **MTP tested 2026-09-08 via an isolated unsloth PR build — net loss in every config despite 0.7–0.99 acceptance: on a RAM-bound CPU-expert MoE a verify batch re-reads ~n× expert weights, speculation amortizes nothing; the PR's on-device-state fix was built from source and tested 2026-09-08 — closes nothing here — do not adopt when it merges**). No build pin needed anymore. Not in the OpenCode providers. Details: `docs/models/Qwen3.8-Flash-Next.md`.
- Enabled providers: `gertrude`, `hermine`, `anthropic`, `openrouter` (a fifth, `elektronengehirn`, appeared in `opencode.jsonc` from outside this session and is undocumented here)
- `openrouter` is the built-in OpenRouter provider (models preloaded from Models.dev); its API key is read from the `OPENROUTER_API_KEY` env var via `"apiKey": "{env:OPENROUTER_API_KEY}"` instead of `/connect`
- Plugin (npm): `opencode-claude-auth@latest`; `share: disabled`
- Bash guard: shipped by `stadtwerk_ai_config` (`command-guard.js` → `~/.config/opencode/plugin/`), deny-only, normalises and recursively splits commands before matching. Health signal: the "Löschschutz aktiv" toast plus `echo guard-selftest`, which must be blocked. Known false positive: multi-target `rm -f`. Full rule list and analysis: `docs/opencode.md`.
- Permissions come from the **team** config `~/.config/opencode/opencode.json` (default-ask plus ~116 read-only allow patterns); a `permission` block in the personal `opencode.jsonc` would override the team baseline and is forbidden. Measurements: `docs/opencode.md`.
- MCP servers: `atlassian` (remote OAuth at `https://mcp.atlassian.com/v1/mcp`) and `playwright` (local via `npx @playwright/mcp@latest`)

## Claude Code config notes

- Skills: `commit-push`, `grill-mich`, `doku`, `affine`, `klartext`, `wortfinder` and `leserfreundlich` (global, from `claude-backup/`); `llama-preset`, `llama-4090-community` and `claudelocal-models` (project-local, in `.claude/skills/`).
- `leserfreundlich` (added 2026-09-22) is a reminder skill, not a process: whenever a text for human readers is created or revised — Confluence, Markdown, Jira, AFFiNE, PR bodies, mails, even a "short comment" — it re-states that textual and structural formatting (lead sentence, headings by reader question, lists, tables, code blocks, callouts) must be used to make the text scannable. It complements `doku` (full document process) and `klartext` (chat-answer style) and is meant to fire in cases where those two do not. Since 2026-09-24 it also keeps texts to the necessary information: five yes/no cut tests (history lesson, route to the decision, meta-commentary, the obvious, second copy → link) plus a keep list (failure a rule prevents, measured numbers, outside constraints, the authoritative rationale, dead-end history, certainty markers). When an existing text is revised, only the touched passages are trimmed; it asks once whether the rest should follow and reports what was cut per category. The cut/keep core was adapted from `trim-prose` in `stadtwerk/fertilizer_management`, without its git-diff machinery.
- **`claudelocal` runs Claude Code against hermine's llama.cpp router**: `claude --settings ~/.claude/settings.local.json` (alias in `bashrc-backup/.bashrc-aliases`), backed up here as `claude-backup/.claude/settings.local.json` (gitignored). Its `modelPicker` block is what makes the local models selectable with `/model`. Two constraints, read out of the 2.1.263 binary: `modelPicker` is honored **only** from managed settings, `--settings`/SDK and user settings — never from a project checkout, and `~/.claude/settings.local.json` is not user settings either, so the alias's `--settings` is the only path that works; and the key needs Claude Code ≥ 2.1.245, `behavesAs` ≥ 2.1.263 (2.1.236 ignores it silently). Keep the list in sync with the `claudelocal-models` skill rather than by hand — it also warns when `ANTHROPIC_MODEL` is no longer served, which is how a dead ID sat in the file from 2026-09-06 to 2026-09-07.
- `affine` is a **workspace** skill, `doku` a **document** skill; the split was made 2026-09-22 after the two had duplicated the AFFiNE write rules (read-back, `analyze_doc_fidelity`, block edits). `affine` now owns only where a page belongs (hub „Übersicht – Hermes Gehirn“, child pages, tags, Organize-Folder) and what must not be stored there; how the page is written lives solely in `doku/references/affine.md`. Its former `references/authoring.md` was folded in and deleted — the add-only `install.sh` leaves the installed copy behind, remove `~/.claude/skills/affine/references/` by hand.
- **SessionStart hook `skills-overview.sh`** (added 2026-09-22, registered in the live `~/.claude/settings.json` the same day): prints a compact list of user, project and synced skills as a `systemMessage` on startup and `/clear`, silent on resume/compact. Deliberately small to avoid info fatigue: one line per skill, first sentence of the description, synced Anthropic skills as names only. It adds nothing to the model's context. Handles YAML block-scalar descriptions (`description: >`), which the `c4-devops-*` skills use.
- `doku` (renamed from `docs` 2026-09-22, content translated to German the same day) creates or revises concise documentation for GitHub Markdown, Confluence Cloud, and AFFiNE. Its `SKILL.md` stays compact; document-type, platform, and accessible-SVG guidance lives in references loaded only when needed. The skill is available automatically for matching tasks and explicitly as `/doku`. Since 2026-09-22 its process makes loading `leserfreundlich` a mandatory step 3 (via the Skill tool, fallback `${CLAUDE_SKILL_DIR}/../leserfreundlich/SKILL.md`) and ends every document with that skill's skim test; a skill cannot trigger another one by itself, so the coupling is an instruction, not a mechanism. A stale `~/.claude/skills/docs/` from an earlier install is not removed by the add-only `install.sh` and must be deleted by hand, or both names show up in `/`.

## llama.cpp config notes

- Linux/Pop!_OS adaptation of `countzero/windows_llama.cpp`; **Vulkan** backend, **prebuilt** binaries (no compiler/conda).
- **Engine choice is measured, not habit**: stock vLLM (0.28, W4A16, WSL) loses on this box for single-user agentics — 46 t/s decode, max ctx 3.5k vs llama.cpp's 72–82 t/s @262k; the fast community vLLM stacks are patched forks. Details + when to revisit: `docs/inference-engines.md`; working setup in `vllm-backup/`.
- Scope: run already-built GGUF models only (no quantization/conversion).
- `bootstrap.sh` downloads `llama-<tag>-bin-ubuntu-vulkan-<arch>.tar.gz` into `vendor/` (idempotent, `--force` to reinstall).
- `download-model.sh` pulls GGUFs to `$LLAMA_MODELS_DIR` (default `~/.local/share/llama.cpp/models`, outside the repo); prefers `hf`/`huggingface-cli`, falls back to `curl`; manifest `models.list`. Since 2026-09-22 `models.list` is **gitignored** (machine-specific, like `presets/models.ini`) and the committed template is `models.example.list`; both download scripts fall back to the template when `models.list` is missing, so a fresh clone still works without a copy step.
- `server.sh`: router mode (default, `presets/models.ini`) or single model; serves OpenAI-compatible API at `LLAMA_HOST:LLAMA_PORT` (default `127.0.0.1:8081`).
- `LLAMA_VERSION` defaults to `latest`. **`latest` is not a GitHub `releases/latest` tag** — ggml-org publishes the binary-carrying `b<number>` tags as prereleases, so `releases/latest` returns a semver release (`v0.3.0`) whose only asset is `nightly-tag.txt`, a pointer to the real build tag. Both bootstrap scripts follow that pointer since 2026-08-30 (before that, `bootstrap.ps1` 404'd). Details: `docs/llama-operations.md`. `server.sh`/`server.ps1` auto-run `bootstrap.*` before serving to pick up new releases, throttled by a `vendor/.last-auto-check` marker (`LLAMA_UPDATE_CHECK_INTERVAL`, default 3600s) so repeated restarts don't hit GitHub's API. `LLAMA_AUTO_UPDATE=0` disables it (offline use); a failed check falls back to the already-installed build instead of hard-failing.
- Config in `config.env` (gitignored; copy from `config.env.example`). The Windows host uses `config.ps1` instead (gitignored, holds a plaintext `HF_TOKEN`); all bash entry points load via `config-load.sh`, precedence `config.env` > `config.ps1` > `.example`, CR stripped. **An environment variable does not override any of them** (user decision 2026-09-24): `config.env` is the single source of truth per machine. Until that date three keys (`LLAMA_MODELS_DIR`, `LLAMA_PRESET`, `LLAMA_VERSION`) were restored from the environment after sourcing while every other `LLAMA_*` was silently clobbered — the header promised the broad rule, the code did the narrow one, so `LLAMA_PORT=8099 ./server.sh` bound 8081 and `LLAMA_AUTO_UPDATE=0` never disabled the update check. `recommend.sh` keeps its own copy of this logic so it runs standalone. Why the `.example` fall-through was broken twice over: `docs/llama-operations.md`.
- Paths handed to a Windows `.exe` go through `host_path()` (`wslpath -m`); bash keeps POSIX paths for its own tests. The two defects that kept `server.sh` from serving on hermine: `docs/llama-operations.md`.
- `fit = off` in all sections **except `Qwen3.8-Flash-Next` (`fit = on` measured +20 % tg there — RPC/CPU-expert splits are where auto-fit earns its keep)**; **load-bearing only in `Ornith-1.0-35B`** (`fit = on` silently offloads MoE experts, ~30 % slower), elsewhere a measured no-op set so VRAM shortfalls fail loudly. Measurements: `docs/llama-operations.md`.
- WSL-on-Windows traps on hermine: `--host 127.0.0.1` binds the *Windows* loopback — use `0.0.0.0` plus the gateway IP from `ip route` (`hermine` does not resolve from inside WSL). Kill test servers by PID from `tasklist.exe`, **never by image name while the user's router runs**. Details: `docs/llama-operations.md`.
- **amdgpu runtime-suspends the card 5 s after the last request and evicts the model into host RAM** — the server keeps answering over PCIe, silently, and one episode ran two days undetected. Fix: `amdgpu.runpm=0` on the kernel command line (verified across a reboot); the udev rule tried first was measured not to work. **Consequence: the "hard 22.5 GB VRAM cliff" this box's preset header claimed does not exist** — it was this artefact, and every throughput number from Gertrude before 2026-09-24 14:00 is suspect. Four wrong diagnoses, the decisive measurement and the reason a one-shot check cannot see it: `docs/llama-operations.md`.
- `llama.cpp/tools/healthcheck.sh` is the safety net for that end state: systemd timer, 60 s, restarts after 2 consecutive hits, logs to `~/.local/state/llama.cpp/healthcheck.log`. `LLAMA_HEALTHCHECK_SETTLE` (90 s) skips the check right after a unit start, because a loading 16 GiB model looks exactly like an eviction from outside. The amdgpu VRAM/GTT signal does **not** transfer to hermine (`detect_*` is pluggable for a throughput probe).
- **A second GPU (RTX 3060, 2026-09-24) renumbered the AMD card from `card0` to `card1`** — address GPUs by PCI id or by probing for `mem_info_vram_used`, never by card number. llama.cpp now lists `Vulkan0` = 7900 XTX, `Vulkan1` = 3060, so `device = VULKAN0` still holds, but selection is by index: **re-check `--list-devices` after every driver or BIOS change**. **`llama-fit-params` needs `-dev Vulkan0` too** — with two devices it fits across both by default and reports less than half the real footprint, while every preset pins one card. Keep a known model in each sweep as a control; that is the only reason this was caught. Driver install notes and the unexplained +767 MiB the same preset gained across that reboot: `docs/llama-operations.md`.
- `server.sh --section <NAME>` serves **one** model with exactly the flags of that `models.ini` section, no router — so the INI stays the one per-machine file worth backing up. `--print-section <NAME>` prints the argv without starting anything. Flag arity (bare switch, `--no-` pair, value flag) is parsed from the installed build's `--help`, never hardcoded: the flag list and the description are separated by 2+ spaces, but short flags are padded so `--long` starts at column 8, and a long flag list (`--spec-draft-type-k, -ctkd, --cache-type-k-draft TYPE`) pushes the description onto the next line. Cutting at a fixed column instead gets those wrong.
- **hermine drives its display from a GT 610 since 2026-08-15; the 4090 idled at ~22–44 MiB at first.** Since later that day Windows shell components (`explorer.exe`, `TextInputHost`) hold ~241 MiB on the 4090 — check `nvidia-smi` before margin-critical loads; VRAM figures measured before the GT-610 swap sat on a 394–1172 MiB baseline. If the 4090 shows Code 31/39 after a Windows-Update cycle, it is the legacy-driver conflict; verified fix: `docs/llama-operations.md`.
- On CUDA (hermine), `cache-type-v` MUST equal `cache-type-k` — a mixed pair falls off the fused FlashAttention kernel and collapses throughput ~9× (measured; untested on Vulkan/Gertrude, whose presets keep the `q8_0`/`q4_0` floor). Numbers: `docs/llama-operations.md`.
- `spec-type` carries `ngram-mod` in every section (lossless, no VRAM; gain unmeasured on both machines). `cache-ram = 16384` on hermine's four agentic-coding sections. `cache-reuse = 256` is written everywhere but **inert on current builds** (measured across four arches; on `Qwen3.8-27B` blocked by multimodal instead) — do not credit it with anything. Details: `docs/llama-operations.md`.
- **RPC pooling**: hermine's server can attach Gertrude's 7900 XTX as `RPC0` (`ggml-rpc-server` ships with the official prebuilts; no auth → LAN only, both ends on the same build). The `nightly-tag.txt` pointer can lag behind an arch merge — pin `LLAMA_VERSION="b<nr>"` in the config then, or the auto-update check **downgrades** the build again. The env `LLAMA_VERSION` override that existed 2026-09-03 to 2026-09-24 is **gone** — pin the build in `config.env` instead. Details: `docs/llama-operations.md`.
- Models are **never** committed: `.gitignore` excludes `llama.cpp/{vendor,cache}/`, `config.env`, `presets/models.ini`, `models.list`, and `**/*.gguf`.
- **Claude Code appends a trailing `{"role":"system"}` message (the agent-type list) to every `/v1/messages` request; the Qwen templates raise `System message must be at the beginning.` on it, so every `claudelocal` turn 500s.** Affected: `Qwen3.8-27B`, `Qwen3.8-27B-UD`, `Qwen3.8-27B-UD-Q8_K_XL-260ctx-q8_0-rpc`, `Ternary-Bonsai-27B`, `Qwen3.8-Flash-Next` — those five now carry `chat-template-file` pointing at patched copies in `llama.cpp/presets/templates/` (tracked; the one `raise_exception` renders as a system turn instead, everything else byte-identical — measured 2026-09-14). Unaffected: `Qwen3.6-35B-A3B`, `Laguna-XS-2.1`, `Ornith-1.5-35B-A3B`, `Muse-Glimmer-30B`. Check a new GGUF's template before adding a preset. Capture + verification: `docs/llama-operations.md`.
- **`presets/models.ini` is kept comment-free — the user deletes `#` comments from it on sight.** Rationale goes into `models.example.ini` (tracked, comment-friendly) and the model's file under `docs/models/`. Discovery story: `docs/llama-operations.md`.
- OpenCode: the local `gertrude` provider `baseURL` is `http://127.0.0.1:8081/v1`; the remote `hermine` provider points at `http://hermine:8081/v1`.
- Skill `.claude/skills/llama-preset/` (`scripts/recommend.sh`) generates/updates `models.ini` sections from measured hardware plus agentic defaults; substantially rewritten 2026-08-04 after a dozen real defects found by running it on this machine. Read `docs/llama-recommend-sh.md` before changing the script — it records each defect and the validation run. Known gap: it misses embedded MTP heads whose repo name lacks `-MTP-` (bit `Qwen3.8-27B`).

## ComfyUI config notes

- **Second engine on the second GPU**: ComfyUI serves image generation on the RTX 3060 while llama.cpp keeps the 7900 XTX. They cannot collide over VRAM **structurally, not by configuration** — the AMD card is not a CUDA device and llama.cpp is pinned to Vulkan. System RAM is the one shared resource (`--lowvram` puts the text encoder there).
- **Measured on Gertrude 2026-09-24** (1024×1024, 20 steps, Qwen-Image-2.1 int8 + qwen3vl_8b int8 encoder): `--lowvram` **183.6 s at a 9515 MiB peak**, `NORMAL_VRAM` 201.7 s at 11411 MiB. `--lowvram` is therefore both faster and leaner, the opposite of what the name suggests — it was originally set so the model would fit at all, which was the wrong reason for the right default. Cold and warm runs differ by 3 s, so the time is compute, not loading.
- **The GGUF route does not work for this model.** The unsloth GGUFs carry no `general.architecture`, so `ComfyUI-GGUF` falls back to guessing from tensor names and its `detect_arch` only knows flux, sd3, aura, hidream, cosmos, hyvid and wan — with no newer upstream commit. The native Comfy-Org safetensors (`diffusion_models/qwen_image_2.1_int8_convrot.safetensors`, 6.76 GB) load without any custom node. **Figures quoted in blog posts did not survive contact**: "~11 GB" is wrong at both ends (bf16 is 13.25 GB, int8 6.76 GB) and the repo id `RealRebelAI/Qwen-Image-2.1-GGUF` does not exist.
- **The torch version window is one minor release wide and `install.sh` pins it.** ComfyUI pins torch not at all, so the wheel index silently decides: cu121 tops out at 2.5.1 and cu124 at 2.6.0, both too **old** — `comfy_kitchen` registers an op annotated `stride: list[int]` and torch's `infer_schema` rejects PEP 585 builtins before 2.7 — while plain PyPI is too **new** for driver 535 ("driver is too old, found version 12020"). **2.7.1+cu126** satisfies both. `install.sh` installs torch *before* `requirements.txt` (which would otherwise pull a CPU-only wheel over it) and checks **both** halves of the window, because a too-old torch passes the CUDA check and only dies on the `comfy_kitchen` import when the server starts.
- **Hermes reaches it over the Docker bridge gateway, not loopback**: the agent runs in a container on `hermes_network`, so `http://172.20.0.1:8188` — the same shape as the `172.21.0.1:8081` route it already uses for the llama.cpp router. UFW allows 8081 from the LAN and both docker ranges; 8188 needs the same rules. Hermes 0.15.1+ speaks ComfyUI natively through its `image_gen` tool and the `hermes-comfyui-local` plugin ships a `qwen_image_2_1_txt2img` workflow, so no OpenAI-style adapter is needed. Gertrude runs 0.20.5 with `HERMES_HOME=/opt/data` mapped to `~/hermes/data`, so config and plugins survive the container updates that `wud` triggers.

## Conventions

- This repo is a dotfiles/config backup, not a software project. Do not add build tooling or tests.
- All three config installers (`bashrc-backup/install.bash`, `claude-backup/install.sh`, `opencode-backup/install.sh`) share one output style since 2026-09-22: a bold header line `<what> install  <source> → <target>`, bold section headers, `✔` per file or skill with a dimmed state (`new` / `updated` / `kept` / `set`), `!` for skipped items and hints, a closing `Done.` line. Colors via `tput`, only when stdout is a terminal, so piped runs print plain text. A new installer follows the same shape; the helpers are duplicated per script on purpose so each runs standalone from a fresh clone.
- `.gitignore` excludes `.claude/settings.local.json`, `.playwright-mcp`, and the llama.cpp `vendor/`, `cache/`, `config.env`, `presets/models.ini`, `models.list`, and `*.gguf`.
- Fresh machine setup order: SSH → clone repo → `bashrc-backup/install.bash` → Claude Code → `claude-backup/install.sh` → `opencode-backup/install.sh` → authenticate MCPs → (optional) `llama.cpp/bootstrap.sh`.
- Only **official** llama.cpp builds go into `llama.cpp/vendor/` — the releases `bootstrap.sh` fetches from `ggml-org/llama.cpp`. Vendor forks are not used even when they ship prebuilt binaries and even when they are the only way to run a model's advertised feature; the Ternary-Bonsai DSpark drafter is the case that established this. `bootstrap.sh` always installs into the fixed `vendor/llama.cpp` and `rm -rf`s it first, so a second build can never appear there by accident — which is what keeps the plain `find vendor/ -name llama-server*` in `server.sh` and `recommend.sh` unambiguous.
- Any work on `llama.cpp/presets/*.ini` — adding a section, retuning an existing one, or diagnosing a model's context/speed — goes through the `llama-preset` skill (`.claude/skills/llama-preset/`) **first**. This bullet exists because description-based skill triggering undertriggers while an `AGENTS.md` line is loaded in every session; the skill is also project-local, so it is invisible outside this repo. Do not hand-write a preset value that `recommend.sh` would have measured — and do overrule the script when a hand measurement contradicts it, recording both numbers. Measuring throughput of an already-configured model belongs to the neighbouring skill `tilloh-local-llm-bench` instead.
- Any change to the `modelPicker` list in `claude-backup/.claude/settings.local.json` goes through the `claudelocal-models` skill (`.claude/skills/claudelocal-models/`), for the same undertriggering reason as the bullet above. It reads the router instead of the preset file, so it also catches sections that `models.ini` still has but a not-yet-restarted router does not serve. Hand-written labels and descriptions in existing rows are preserved — do not let a sync flatten them.
- Verification here is cheap in consequence and expensive in time: loading a 16 GB model and reading `nvidia-smi` costs minutes but changes nothing. Spend those minutes instead of asking. Ask first only when verifying means stopping something the user is currently running (a live `llama-server`, for instance).
- Prefer running the tool that reports a number over deriving it by arithmetic. `llama-fit-params` plus a real prompt run beats KV-per-token estimates — the estimates were wrong by enough to matter. A measurement that contradicts your model of the system is the interesting result, not an error to explain away.
- State what you could not verify rather than smoothing over it. Numbers that hold on one machine and were never tested on the other are marked as untested (e.g. whether the mixed-KV collapse also affects Vulkan/Gertrude). An unverified claim presented as fact is worse than an admitted gap, because the next reader has no way to tell.
