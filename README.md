# brainalyser

Machinery for a **shared brain**: a folder of plain markdown your AI reads before it
answers and writes to after it learns.

No database, no sync layer, no service. The files *are* the memory - which is why the
brain outlives whatever tool you were using when you started it.

The format is [Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog)
(OKF v0.2): markdown + YAML frontmatter, one fact per file, directories as domains, an
`index.md` for navigation and a `log.md` for history at every level.

**This repo ships no knowledge.** It ships the tooling. Your brain stays your own git
repo, located via `BRAIN_REPO`.

## Start here

**Fastest path - let your AI do it.** Send someone this and nothing else:

> Look at this repo: https://github.com/vikingsearth/brainalyser
> Read START-HERE.md and follow it to set me up with a second brain.

[`START-HERE.md`](START-HERE.md) is addressed to the agent rather than the human. It
works out whether it can run commands, then takes the right path - installing the plugin,
or running the interview in-chat and asking for the single manual step it cannot do
itself. No prior knowledge needed on the human's side.

The manual routes, if you prefer them:


**In Claude Code** - install the plugin, then run `/brain-init`:

```
/plugin marketplace add vikingsearth/brainalyser
/plugin install brainalyser@memorymarket
/brain-init
```

`brain-init` interviews you about what *you* want to remember and builds the structure
around your answers. There is no default taxonomy to adopt.

**Anywhere else** (Claude apps, web, another assistant) - open
[`BRAIN-SEED.md`](BRAIN-SEED.md), copy the whole file, and paste it into your project's
custom instructions. Same format, same rules, done by hand. You can upgrade to the
plugin later without changing anything you have written.

## Skills

| skill | does |
| --- | --- |
| `brain-init` | interviews you and scaffolds a new bundle around your answers |
| `brain-backfill` | one-time cold start: imports your existing history, merges duplicates, lands the survivors as unverified proposals |
| `brain` | recall and capture during normal work - owns routing and confidence |
| `brain-sweep` | scheduled catch-up harvest from recent sessions |
| `brain-validity` | weekly audit: conformance plus drift against reality. Proposes, never mutates |
| `okf` | the format authority - read before inventing frontmatter keys |
| `validate` | deterministic conformance checker, not an eyeball pass |
| `visualize` | renders a bundle as a self-contained interactive HTML graph |

`brain-init` and `brain-backfill` are the two you use once. The rest run for years.

## Hooks

| hook | does |
| --- | --- |
| `SessionStart` | announces the bundle and states the recall trigger |
| `UserPromptSubmit` | greps the bundle for entities named in your prompt and injects what it finds |

Both emit context only. Neither writes to your bundle, and neither returns a permission
decision. This is what makes recall automatic rather than something you have to ask for.

## Routines

| routine | cadence | does |
| --- | --- | --- |
| `daily-brain-sweep` | daily | harvests what the day's sessions produced, via `brain-sweep` |
| `weekly-brain-validity` | Monday | conformance lint plus drift audit, written to `inbox/` for you to review |

Without these, the brain only grows when you remember to say "log this". Claude Code
discovers scheduled tasks only under `~/.claude/scheduled-tasks/`, so these cannot install
themselves with the plugin - the prompts ship in `plugins/brainalyser/routines/` and get
copied across. `brain-init` offers to do it; [routines/README.md](plugins/brainalyser/routines/README.md)
has the manual steps and the cron lines.

## Configuration

`BRAIN_REPO` points at the git repo holding your brain, defaulting to
`$HOME/dev/myMemory`. The bundle itself is `$BRAIN_REPO/brain`.

```bash
export BRAIN_REPO="$HOME/dev/my-brain"
```

Keep the bundle in its own repo, separate from this plugin. A plugin directory is
install-managed and overwritten on update - notes captured inside one would be silently
discarded. Both hooks refuse a `BRAIN_REPO` under `~/.claude/plugins/` for exactly that
reason.

## Two ways people organise

There is no right answer, and the tooling does not prefer one:

- **categorical** - top level by subject (`people/`, `projects/`, `preferences/`).
  Good if you search by remembering the topic.
- **timeline** - top level by time (`daily/`, `weekly/`, `monthly/`). Good if you search
  by remembering roughly when.

`brain-init` asks which way you think and builds accordingly.

## Credits

`okf`, `validate` and `visualize` are vendored from
[scaccogatto/okf-skills](https://github.com/scaccogatto/okf-skills) (MIT) - see
`plugins/brainalyser/skills/okf/VENDORED`. Re-vendor rather than hand-edit.
