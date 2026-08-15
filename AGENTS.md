# AGENTS.md

## Repository purpose

A personal tooling collection: curated developer tool references (`README.md`), bash config backups, OpenCode config backup, Claude config backup, and a fresh-Linux bootstrap guide.

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
├── .opencode/skills/                # Project-local skills (OpenCode reads these)
│   └── llama-preset/                # models.ini section generator + recommend.sh
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
│   ├── .claude/                     # settings.json, mcp.json, commands/, skills/
│   └── install.sh                   # Copies to ~/.claude/
├── llama.cpp/                       # Local LLM inference (prebuilt Vulkan llama.cpp)
│   ├── bootstrap.sh                 # Fetch+extract prebuilt Vulkan release into vendor/
│   ├── download-model.sh            # Pull GGUF(s) from HuggingFace to $LLAMA_MODELS_DIR
│   ├── server.sh                    # Start llama-server (router or single model)
│   ├── config-load.sh               # Sourced by all three: env > config.env > config.ps1
│   ├── config.env.example           # Paths/version/port (copy to config.env)
│   ├── models.list                  # HuggingFace download manifest
│   ├── presets/models.example.ini   # Router preset template
│   ├── PLAN.md / README.md          # Design + usage
│   └── vendor/ cache/               # Binaries + downloads (gitignored)
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

- `bashrc-backup/install.bash` deletes the `# CUSTOM START` … `# CUSTOM END` block from `~/.bashrc`, appends the new block at the end, then calls `exec bash -l` to reload the shell.
- `opencode-backup/install.sh` copies `opencode.jsonc` to `~/.config/opencode/opencode.jsonc`, `AGENTS.md` to `~/.config/opencode/AGENTS.md`, any `agents/*.md` to `~/.config/opencode/agents/`, and `skills/*/` to `~/.config/opencode/skills/` (creates dirs if needed). Add-only: existing agents/skills/plugins from other sources are kept. It ships **no plugin** — the bash guard comes from `stadtwerk_ai_config` (see below).
- `claude-backup/install.sh` copies `settings.json`, `settings.local.json`, `mcp.json`, `commands/`, and `skills/` into `~/.claude/`. Note: `settings.local.json` is in `.gitignore` and won't be present in a fresh clone — the script will fail on that step; ignore or create an empty file first.

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
| Per-model preset rationale + measurements (12 models) | `docs/models/<model-ID>.md` |
| Cross-model llama.cpp measurements, hermine hardware, WSL traps | `docs/llama-operations.md` |
| recommend.sh rewrite history | `docs/llama-recommend-sh.md` |
| OpenCode guard, permissions, provider findings | `docs/opencode.md` |

## OpenCode config notes

- No global default `model` is pinned in `opencode.jsonc` (pick per session).
- `opencode-backup/AGENTS.md` → `~/.config/opencode/AGENTS.md` holds the **global personal rules** (currently: German conversation / English artefacts, the human-vs-agent writing register, measured-vs-guessed numbers, cleaning up processes and temp files you started, and verifying documented values against the live system with read-only commands). Global and project rules are separate categories in OpenCode, so this file is loaded *in addition to* a project's own `AGENTS.md`, in every session. That is deliberate: a preference that must hold for every edit belongs here and not in a skill, because skills only enter context when their `description` matches and they are known to undertrigger. Keep the file short — it costs context in every session.
- Two llama.cpp providers: `lieselotte` (local, `127.0.0.1:8081`) and `hermine` (remote, `hermine:8081`). Model IDs are bare aliases without the `.gguf` suffix.
- Both `lieselotte` and `hermine` list the **same twelve** model IDs, and both `models` maps match their `whitelist` exactly: `Qwen3.8-27B`, `Qwen3.6-27B`, `Qwen3.6-35B-A3B`, `gemma-4-26B-A4B`, `Ornith-1.0-9B`, `Ornith-1.0-35B`, `Qwen-AgentWorld-35B-A3B`, `gemma-4-31B`, `Laguna-XS-2.1`, `Ternary-Bonsai-27B`, `Muse-Glimmer-30B`, `Nemotron-3.5-Lightning-30B-A3B`. The `Qwen3.8-27B` and Nemotron GGUFs are only verified present on hermine. Disk-verification history: `docs/opencode.md`.
- **Model ID = `models.ini` section name, case-sensitive.** Take IDs from `/v1/models`, never from the `alias` key (often a bare filename); two lowercase entries were dead for this reason. Details: `docs/opencode.md`.
- `gemma-4-26B-A4B` and `gemma-4-31B` are declared image-capable in `opencode.jsonc` but have no `mmproj` on disk — genuinely multimodal are `Muse-Glimmer-30B` and `Qwen3.8-27B`. Left as-is deliberately (capability decision, not a typo). Details: `docs/opencode.md`.
- **Per-model deep-dives live in `docs/models/<ID>.md` — read the model's file before touching its preset, retuning it, or citing any of its numbers.** One line each (hermine values):
  - `Qwen3.8-27B` — dense 27B VLM (arch `qwen35`), embedded MTP; 147456 / q8_0 / `draft-mtp,ngram-mod` n-max 3, mmproj on CPU, `reasoning-preserve = true`.
  - `Qwen3.6-27B` — dense 27B, embedded MTP; 131072 / q8_0 / `draft-mtp,ngram-mod` n-max 3, coding sampling set (temp 0.6).
  - `Qwen3.6-35B-A3B` — 35B-A3B MoE, embedded MTP; 262144 / q8_0 / `draft-mtp,ngram-mod`, coding sampling set.
  - `Ornith-1.0-9B` — dense 9B agentic coder; 262144 / q8_0 / `ngram-mod`, temp 0.6.
  - `Ornith-1.0-35B` — dense 35B; 65536 / q8_0 / `ngram-mod`; **throughput cliff at 131072, `fit = off` is load-bearing** — do not raise ctx without reading the doc.
  - `Laguna-XS-2.1` — 33B-A3B MoE agentic coder; 163840 / q8_0 / `ngram-mod`; **`reasoning = on` required** (template defaults thinking off).
  - `Qwen-AgentWorld-35B-A3B` — language world model, **not a coding assistant**; 262144 / q8_0 / `ngram-mod`, temp 0.6.
  - `gemma-4-31B` — dense QAT VLM (no mmproj wired); 65536 / q8_0 / `draft-mtp` sidecar n-max 3; thin margin deliberate.
  - `gemma-4-26B-A4B` — MoE QAT VLM (no mmproj wired); 262144 / q8_0 / `draft-mtp` sidecar n-max 4; **never force `reasoning = on`** (card forbids carrying thoughts).
  - `Ternary-Bonsai-27B` — ternary 1.71 bpw Qwen3.6-27B; 262144 / q8_0 / `ngram-mod`; only the `Q2_g64` pack loads on stock llama.cpp, DSpark drafter closed by official-builds policy.
  - `Muse-Glimmer-30B` — dense 30B agentic multimodal; 131072 / q8_0 / `draft-dflash,ngram-mod` **n-max 16**, mmproj resident on GPU.
  - `Nemotron-3.5-Lightning-30B-A3B` — Mamba-2 MoE; 262144 / q8_0 / `ngram-mod`; **MTP drafter measured 2.25× slower — do not re-add without re-measuring.**
- Enabled providers: `lieselotte`, `hermine`, `anthropic`, `openrouter` (a fifth, `elektronengehirn`, appeared in `opencode.jsonc` from outside this session and is undocumented here)
- `openrouter` is the built-in OpenRouter provider (models preloaded from Models.dev); its API key is read from the `OPENROUTER_API_KEY` env var via `"apiKey": "{env:OPENROUTER_API_KEY}"` instead of `/connect`
- Plugin (npm): `opencode-claude-auth@latest`; `share: disabled`
- Bash guard: shipped by `stadtwerk_ai_config` (`command-guard.js` → `~/.config/opencode/plugin/`), deny-only, normalises and recursively splits commands before matching. Health signal: the "Löschschutz aktiv" toast plus `echo guard-selftest`, which must be blocked. Known false positive: multi-target `rm -f`. Full rule list and analysis: `docs/opencode.md`.
- Permissions come from the **team** config `~/.config/opencode/opencode.json` (default-ask plus ~116 read-only allow patterns); a `permission` block in the personal `opencode.jsonc` would override the team baseline and is forbidden. Measurements: `docs/opencode.md`.
- MCP servers: `atlassian` (remote OAuth at `https://mcp.atlassian.com/v1/mcp`) and `playwright` (local via `npx @playwright/mcp@latest`)

## Claude Code config notes

- MCP server: `chrome-devtools` (local via `npx chrome-devtools-mcp@latest`)
- Custom commands: `claude-backup/.claude/commands/commit-push.md`
- Skills: `c4-devops-ticket` (Jira ticket creation for DO project)

## llama.cpp config notes

- Linux/Pop!_OS adaptation of `countzero/windows_llama.cpp`; **Vulkan** backend, **prebuilt** binaries (no compiler/conda).
- Scope: run already-built GGUF models only (no quantization/conversion).
- `bootstrap.sh` downloads `llama-<tag>-bin-ubuntu-vulkan-<arch>.tar.gz` into `vendor/` (idempotent, `--force` to reinstall).
- `download-model.sh` pulls GGUFs to `$LLAMA_MODELS_DIR` (default `~/.local/share/llama.cpp/models`, outside the repo); prefers `hf`/`huggingface-cli`, falls back to `curl`; manifest `models.list`.
- `server.sh`: router mode (default, `presets/models.ini`) or single model; serves OpenAI-compatible API at `LLAMA_HOST:LLAMA_PORT` (default `127.0.0.1:8081`).
- `LLAMA_VERSION` defaults to `latest`. `server.sh`/`server.ps1` auto-run `bootstrap.*` before serving to pick up new releases, throttled by a `vendor/.last-auto-check` marker (`LLAMA_UPDATE_CHECK_INTERVAL`, default 3600s) so repeated restarts don't hit GitHub's API. `LLAMA_AUTO_UPDATE=0` disables it (offline use); a failed check falls back to the already-installed build instead of hard-failing.
- Config in `config.env` (gitignored; copy from `config.env.example`). The Windows host uses `config.ps1` instead (gitignored, holds a plaintext `HF_TOKEN`); all bash entry points load via `config-load.sh`, precedence env > `config.env` > `config.ps1` > `.example`, CR stripped. `recommend.sh` keeps its own copy of this logic so it runs standalone. Why the `.example` fall-through was broken twice over: `docs/llama-operations.md`.
- Paths handed to a Windows `.exe` go through `host_path()` (`wslpath -m`); bash keeps POSIX paths for its own tests. The two defects that kept `server.sh` from serving on hermine: `docs/llama-operations.md`.
- `fit = off` in all twelve sections; **load-bearing only in `Ornith-1.0-35B`** (`fit = on` silently offloads MoE experts, ~30 % slower), elsewhere a measured no-op set so VRAM shortfalls fail loudly. Measurements: `docs/llama-operations.md`.
- WSL-on-Windows traps on hermine: `--host 127.0.0.1` binds the *Windows* loopback — use `0.0.0.0` plus the gateway IP from `ip route` (`hermine` does not resolve from inside WSL). Kill test servers by PID from `tasklist.exe`, **never by image name while the user's router runs**. Details: `docs/llama-operations.md`.
- **hermine drives its display from a GT 610 since 2026-08-15; the 4090 idles at ~22–44 MiB.** VRAM figures measured before that date sat on a 394–1172 MiB desktop baseline — re-measure before trusting them at the margin. If the 4090 shows Code 31/39 after a Windows-Update cycle, it is the legacy-driver conflict; verified fix: `docs/llama-operations.md`.
- On CUDA (hermine), `cache-type-v` MUST equal `cache-type-k` — a mixed pair falls off the fused FlashAttention kernel and collapses throughput ~9× (measured; untested on Vulkan/lieselotte, whose presets keep the `q8_0`/`q4_0` floor). Numbers: `docs/llama-operations.md`.
- `spec-type` carries `ngram-mod` in every section (lossless, no VRAM; gain unmeasured on both machines). `cache-ram = 16384` on hermine's four agentic-coding sections. `cache-reuse = 256` is written everywhere but **inert on current builds** (measured across four arches; on `Qwen3.8-27B` blocked by multimodal instead) — do not credit it with anything. Details: `docs/llama-operations.md`.
- Models are **never** committed: `.gitignore` excludes `llama.cpp/{vendor,cache}/`, `config.env`, `presets/models.ini`, and `**/*.gguf`.
- **`presets/models.ini` is kept comment-free — the user deletes `#` comments from it on sight.** Rationale goes into `models.example.ini` (tracked, comment-friendly) and the model's file under `docs/models/`. Discovery story: `docs/llama-operations.md`.
- OpenCode: the local `lieselotte` provider `baseURL` is `http://127.0.0.1:8081/v1`; the remote `hermine` provider points at `http://hermine:8081/v1`.
- Skill `.opencode/skills/llama-preset/` (`scripts/recommend.sh`) generates/updates `models.ini` sections from measured hardware plus agentic defaults; substantially rewritten 2026-08-04 after a dozen real defects found by running it on this machine. Read `docs/llama-recommend-sh.md` before changing the script — it records each defect and the validation run. Known gap: it misses embedded MTP heads whose repo name lacks `-MTP-` (bit `Qwen3.8-27B`).

## Conventions

- This repo is a dotfiles/config backup, not a software project. Do not add build tooling or tests.
- `.gitignore` excludes `.claude/settings.local.json`, `.playwright-mcp`, and the llama.cpp `vendor/`, `cache/`, `config.env`, `presets/models.ini`, and `*.gguf`.
- Fresh machine setup order: SSH → clone repo → `bashrc-backup/install.bash` → Claude Code → `claude-backup/install.sh` → `opencode-backup/install.sh` → authenticate MCPs → (optional) `llama.cpp/bootstrap.sh`.
- Only **official** llama.cpp builds go into `llama.cpp/vendor/` — the releases `bootstrap.sh` fetches from `ggml-org/llama.cpp`. Vendor forks are not used even when they ship prebuilt binaries and even when they are the only way to run a model's advertised feature; the Ternary-Bonsai DSpark drafter is the case that established this. `bootstrap.sh` always installs into the fixed `vendor/llama.cpp` and `rm -rf`s it first, so a second build can never appear there by accident — which is what keeps the plain `find vendor/ -name llama-server*` in `server.sh` and `recommend.sh` unambiguous.
- Any work on `llama.cpp/presets/*.ini` — adding a section, retuning an existing one, or diagnosing a model's context/speed — goes through the `llama-preset` skill (`.opencode/skills/llama-preset/`) **first**. This bullet exists because description-based skill triggering undertriggers while an `AGENTS.md` line is loaded in every session; the skill is also project-local, so it is invisible outside this repo. Do not hand-write a preset value that `recommend.sh` would have measured — and do overrule the script when a hand measurement contradicts it, recording both numbers. Measuring throughput of an already-configured model belongs to the neighbouring skill `tilloh-local-llm-bench` instead.
- Verification here is cheap in consequence and expensive in time: loading a 16 GB model and reading `nvidia-smi` costs minutes but changes nothing. Spend those minutes instead of asking. Ask first only when verifying means stopping something the user is currently running (a live `llama-server`, for instance).
- Prefer running the tool that reports a number over deriving it by arithmetic. `llama-fit-params` plus a real prompt run beats KV-per-token estimates — the estimates were wrong by enough to matter. A measurement that contradicts your model of the system is the interesting result, not an error to explain away.
- State what you could not verify rather than smoothing over it. Numbers that hold on one machine and were never tested on the other are marked as untested (e.g. whether the mixed-KV collapse also affects Vulkan/lieselotte). An unverified claim presented as fact is worse than an admitted gap, because the next reader has no way to tell.
