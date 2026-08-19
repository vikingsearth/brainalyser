---
name: weekly-brain-validity
description: Weekly brain validity check - mechanical lint + reality-drift audit, findings as a reviewable report - proposes, never mutates
---

First, move into the bundle repo:

    cd "${BRAIN_REPO:-$HOME/dev/myMemory}"

Do this explicitly. A scheduled run does not start there, and the report path,
the okf-spec watermark and the commits are all repo-relative.

Then invoke the `brain-validity` skill and follow it end to end. It is the
single source of truth for this routine - if this prompt and the skill ever
disagree, the skill wins.

**HARD RULE, either way: propose only, never mutate the brain.** The only
writes permitted are the report file in `inbox/`, the okf-spec watermark at
`.claude/state/okf-spec.sha`, and their commits. No concept, index or log gets
edited by this routine.

`brain-validity` ships in the brainalyser plugin and is user-scoped, so it loads
regardless of the working directory. If it somehow did not load, read the
shipped SKILL.md directly and follow that:

    ls -d "$HOME"/.claude/plugins/cache/*/brainalyser/*/skills/brain-validity/SKILL.md | sort -V | tail -1

If that finds nothing either, the plugin is not installed. Stop and report it
rather than auditing by hand - an eyeball pass that reports "conformant"
without the validator having run is worse than no audit.
