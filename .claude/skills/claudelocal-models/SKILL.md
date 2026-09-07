---
name: claudelocal-models
description: Gleicht die modelPicker-Zeilen in claude-backup/.claude/settings.local.json mit dem ab, was hermines llama.cpp-Router unter /v1/models tatsächlich serviert, damit "/model" in einer claudelocal-Session alle lokalen Modelle anbietet. Fügt neue IDs hinzu, entfernt tote, behält handgeschriebene Labels und warnt, wenn ANTHROPIC_MODEL nicht mehr serviert wird oder CLAUDE_CODE_MAX_CONTEXT_TOKENS über die ctx-size des Default-Modells hinausgeht. Triggert bei "claudelocal Modelle aktualisieren", "modelPicker synchronisieren", "/model zeigt das lokale Modell nicht", "neues Preset in die Claude-Settings aufnehmen", "settings.local.json an models.ini angleichen".
---

# claudelocal-models — keep the `/model` picker in sync with the router

`claudelocal` is the alias in `bashrc-backup/.bashrc-aliases`:

```bash
alias claudelocal="claude --settings ~/.claude/settings.local.json"
```

That file is backed up in this repo as `claude-backup/.claude/settings.local.json`
and deployed by `claude-backup/install.sh`. Its `modelPicker` block is what makes
llama.cpp models selectable with `/model`. The block is a **static list** — when
`llama.cpp/presets/models.ini` gains or loses a section and the router is
restarted, the list goes stale, and a stale row is a model ID that fails at
request time. This skill regenerates it from the router's own answer.

## Run it

```bash
python3 .claude/skills/claudelocal-models/scripts/sync-models.py --dry-run   # report
python3 .claude/skills/claudelocal-models/scripts/sync-models.py             # write
```

Stdlib Python only, no jq. The router URL comes from `env.ANTHROPIC_BASE_URL` in
the settings file itself (`--base-url` overrides). Useful flags:

| Flag | Effect |
|---|---|
| `--dry-run` | print the diff, write nothing |
| `--settings PATH` | target another settings file (default: the repo backup) |
| `--presets-only` | add only models the router serves from a preset, skipping HuggingFace cache entries pulled on demand (`source: "cache"`) |
| `--exclude ID` | never add this ID as a new row (repeatable) |
| `--keep-unserved` | keep rows the router no longer serves |
| `--behaves-as ID` | `behavesAs` target for new rows (default `claude-sonnet-5`) |

Existing rows keep their `label`, `description` and `behavesAs` **verbatim** —
those are hand-written and worth more than anything the script generates. Only
new IDs get a generated description, built from the router's answer: `ctx-size`
out of the preset args, `input_modalities` out of the architecture block.

After writing, deploy it: `bash claude-backup/install.sh`. The running
`claudelocal` session does not pick up the change — restart it.

## Two constraints that decide whether this works at all

Both were read out of the Claude Code binary and hold as of 2.1.263; re-check
them if a future version behaves differently.

1. **`modelPicker` is only honored from managed settings, `--settings`/SDK, and
   user settings — not from a project checkout.** The setting's own schema text
   says so, and `bK("modelPicker")` filters on `policySettings | flagSettings |
   userSettings`. `~/.claude/settings.local.json` is not read as user settings
   either: `localSettings` resolves against the project directory, not `$HOME`.
   So this file works **only** through the `claudelocal` alias (`--settings`,
   which is `flagSettings`). Do not "fix" it by moving the block into
   `.claude/settings.json` of a project — it would be ignored there.
2. **`modelPicker` needs Claude Code ≥ 2.1.245, `behavesAs` needs ≥ 2.1.263.**
   2.1.236 does not know the key at all (its only `modelPicker` string is a
   keybinding name). Unknown keys in the row schema are stripped, not rejected,
   so a `behavesAs` row is harmless on 2.1.245–2.1.251 — it just has no effect.
   Check with `claude --version` before debugging an empty picker.

`replaceBuiltInOptions: true` is deliberate: against `hermine:8081` the built-in
Claude lineup is dead weight. The picker still shows a `Default` row, which
resolves to `env.ANTHROPIC_MODEL`.

## What to check after a sync

The script prints these as `!` lines; act on them rather than shipping the file:

- `ANTHROPIC_MODEL` / `ANTHROPIC_SMALL_FAST_MODEL` still served. A dead default
  is the defect that motivated this skill.
- `CLAUDE_CODE_MAX_CONTEXT_TOKENS` not larger than the default model's
  `ctx-size`.
- Keep `ANTHROPIC_SMALL_FAST_MODEL` equal to `ANTHROPIC_MODEL`. hermine's router
  holds one model at a time, so a different fast model makes every haiku-class
  call swap models and stall the session behind a reload.

Preset work itself — adding, retuning or diagnosing a `models.ini` section —
belongs to the `llama-preset` skill. This skill only mirrors the result into the
Claude settings.
