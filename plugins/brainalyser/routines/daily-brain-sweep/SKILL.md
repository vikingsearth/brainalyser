---
name: daily-brain-sweep
description: Daily catch-all - harvest durable facts from yesterday's Claude sessions and auto-memory into the brain
---

First, move into the bundle repo:

    cd "${BRAIN_REPO:-$HOME/dev/myMemory}"

Do this explicitly. A scheduled run does not start there, and the sweep's
watermark, report paths and commits are all repo-relative.

Then invoke the `brain-sweep` skill and follow it end to end. It is the single
source of truth for this routine - if this prompt and the skill ever disagree,
the skill wins.

`brain-sweep` ships in the brainalyser plugin and is user-scoped, so it loads
regardless of the working directory. If it somehow did not load, do not
improvise a harvest - read the shipped SKILL.md directly and follow that:

    ls -d "$HOME"/.claude/plugins/cache/*/brainalyser/*/skills/brain-sweep/SKILL.md | sort -V | tail -1

If that finds nothing either, the plugin is not installed. Stop and report it
rather than sweeping by hand: a hand-rolled harvest writes unrouted notes into
the bundle and moves the watermark past sessions it never really read.
