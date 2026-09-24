# Hooks

`install.sh` copies `.claude/hooks/*` to `~/.claude/hooks/` but does not touch
`~/.claude/settings.json`, because that file also carries the team's command
guard and personal permissions. Register a hook by merging the snippet below
into the `hooks` object of `~/.claude/settings.json`, then open `/hooks` once
or restart Claude Code.

## skills-overview.sh

Prints a one-screen list of user, project and synced skills when a session
starts or after `/clear`. Silent on resume and compact. The list is shown to
you only; the model already receives the skill listing from the harness, so
nothing is added to its context.

```json
"SessionStart": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "bash \"$HOME\"/.claude/hooks/skills-overview.sh",
        "timeout": 10
      }
    ]
  }
]
```

Tune the description width with `SKILLS_OVERVIEW_DESC_MAX` (default 64) and the
section-rule width with `SKILLS_OVERVIEW_WIDTH` (default 88); both go into the `env`
block of `settings.json` or in front of the command.
Test without starting a session:

```bash
echo '{"source":"startup","cwd":"'"$PWD"'"}' | ~/.claude/hooks/skills-overview.sh | jq -r .systemMessage
```
