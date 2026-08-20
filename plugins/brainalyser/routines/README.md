# Routines

Two scheduled runs that keep the bundle honest without anyone remembering to:

| routine | cadence | what it does |
| --- | --- | --- |
| `daily-brain-sweep` | daily | harvests durable facts from the last day's Claude sessions and auto-memory into the bundle, via `brain-sweep` |
| `weekly-brain-validity` | weekly (Monday) | OKF conformance lint plus reality-drift audit, written to `inbox/` as a checkbox report, via `brain-validity` |

Both prompts are deliberately thin. The skill is the source of truth; the prompt
only says where to work and which skill to invoke.

## Why these are not part of the plugin proper

Claude Code discovers scheduled tasks **only** under `~/.claude/scheduled-tasks/`.
There is no plugin manifest key for them, so a plugin cannot register a routine
on install - the prompt file has to be copied to the user's config directory.

That copy is the one piece of this plugin that is not self-installing. It is why
these templates live in the repo rather than only on one machine: the copy is
per-machine, the content is versioned here.

## Install

`brain-init` offers to do this. To do it by hand:

```bash
for r in daily-brain-sweep weekly-brain-validity; do
  mkdir -p "$HOME/.claude/scheduled-tasks/$r"
  cp "$CLAUDE_PLUGIN_ROOT/routines/$r/SKILL.md" "$HOME/.claude/scheduled-tasks/$r/SKILL.md"
done
```

These prompts run outside the plugin, so the **Brain repo** plugin option does not reach
them - they read exported `BRAIN_REPO`, else the default. If your bundle is elsewhere and
you set it through the option rather than an export, export it too or these two runs will
work on the wrong path.

Copying the file makes the task discoverable but does not schedule it. Set the
cadence once, through the scheduled-tasks tooling or the app's UI:

| routine | cron (local time) |
| --- | --- |
| `daily-brain-sweep` | `0 8 * * *` |
| `weekly-brain-validity` | `0 8 * * 1` |

Run both under a permission mode that does not stall on prompts - an unattended
run that blocks on a confirmation looks identical to one that finished.

## Updating

The copy is a snapshot, so a plugin update does not refresh it. After upgrading
the plugin, re-run the copy above if these templates changed. Nothing breaks if
you skip it - the prompts are thin pointers and the skills carry the logic - but
a stale prompt can point at a path that has moved.
