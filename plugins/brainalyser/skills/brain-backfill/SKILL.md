---
name: brain-backfill
description: Cold-start a brain from existing material - walk a user's whole Claude Code history (or any source they point at), extract durable facts one item at a time in the background, merge the duplicates, and land the survivors as unverified proposals. Use for a one-time backfill after brain-init, or when the user says backfill / import my history / cold start my brain. Not for routine catch-up - that is brain-sweep.
compatibility: Requires the brain skill (same plugin), the claude CLI on PATH, uv, git, and read access to the chosen source. Repo root from $BRAIN_REPO, default $HOME/dev/myMemory.
allowed-tools:
  - Bash(bash "${CLAUDE_SKILL_DIR}/scripts/discover-all.sh")
  - Bash(bash "${CLAUDE_SKILL_DIR}/scripts/discover-all.sh" *)
  - Bash(bash "${CLAUDE_SKILL_DIR}/scripts/extract.sh")
  - Bash(bash "${CLAUDE_SKILL_DIR}/scripts/extract.sh" *)
metadata:
  author: wikus
  version: "0.1.0"
  purpose: utility
  type: P1
disable-model-invocation: false
user-invocable: true
---

# Brain Backfill

One-time cold start. `brain-sweep` cannot do this job: with no watermark it looks
back **24 hours** and caps at **10 transcripts**, which is correct for a daily
catch-up and useless for someone with two years of history.

Backfill is the opposite shape - full history, no watermark, sequential, resumable,
and it **merges before it writes**.

## When to Use

- Straight after `brain-init`, when the user has history worth importing
- "backfill", "import my history", "cold start my brain"
- **Not** for routine catch-up - that is `brain-sweep`, and running this instead will
  duplicate everything sweep already captured

## Why Two Phases

Sweep writes per session because it handles ~10 items and dedups against a brain that
already exists. Backfill has neither luxury: the same fact appears in forty sessions,
and a newly-initialised brain has nothing to dedup against, so duplication compounds
*within the run*. Extract-then-write per item produces a bundle full of near-identical
notes that is worse than no bundle.

```
discover -> extract (cheap, sequential, resumable) -> merge (expensive, once) -> route + write
```

Spend the effort where the judgement is. "What durable facts are in this transcript" is
mechanical - Sonnet at low effort, times N. "Is this the same fact as that one, which
domain owns it, does it contradict an existing note" is the hard part, and it runs once
over the aggregate.

## Workflow

### 1. Source

Default is Claude Code transcripts under `~/.claude/projects`. **Confirm the source
before starting** - many users have none (anyone working in the Claude apps rather than
the CLI has no local transcripts at all). Accept any of:

| source | how |
| --- | --- |
| Claude Code transcripts | `~/.claude/projects/**/*.jsonl` (default) |
| an exported chat history | a directory of `.json` / `.md` the user points at |
| existing notes | a notes folder, an Obsidian vault, a docs directory |

If the default source is empty, say so plainly and ask what to point at. Do not
silently produce an empty backfill.

### 2. Build the worklist

`bash "${CLAUDE_SKILL_DIR}/scripts/discover-all.sh" [source-dir]` returns every candidate, oldest first, as
JSON. Unlike sweep's discovery there is **no watermark and no cap**.

Exclusions that still apply, for the same reasons sweep applies them:
- the bundle repo's own sessions (self-referential loop)
- subagent / workflow transcripts (their content belongs to the parent session)

Write the worklist to `$BRAIN_REPO/.claude/state/backfill-manifest.json` with every item
`"pending"`. **This file is the resumption record.** A backfill over hundreds of sessions
runs for hours and will be interrupted; on restart, re-read the manifest and skip
anything already `"done"`. Never infer progress from what is on disk.

Report the count and a rough time estimate before starting. Get a go-ahead.

### 3. Extract - background, sequential, one at a time

`bash "${CLAUDE_SKILL_DIR}/scripts/extract.sh"` walks the manifest and runs **one** `claude` subprocess per
item, starting the next only when the previous exits. Sequential is deliberate: a fan-out
across hundreds of sessions will burn through the user's tokens in minutes.

Each subprocess is deliberately minimal:

```
claude -p --safe-mode --no-session-persistence \
       --model "$BACKFILL_MODEL" --effort "$BACKFILL_EFFORT" \
       --output-format json
```

Two things the first end-to-end run established, both worth not re-learning:

- **`low` is the right default.** On a source that extracted nothing, `medium` also
  extracted nothing and cost 6x more. Under-extraction was a prompt fault, not an
  effort fault - raise effort only after ruling the prompt out.
- **The extractor must be scoped to the user message, and every fact needs an
  `evidence` quote.** `--safe-mode` still delivers admin/policy instructions to the
  child, and an unscoped prompt happily mined those and reported them as facts about
  the user (org hosting rules, commit-trailer policy). Across hundreds of sources that
  is hundreds of false notes. The shipped prompt forbids extracting from its own
  instructions and drops any fact whose quote is not in the source.

Defaults are `sonnet` / `low`, overridable per run. Valid effort levels are exactly
`low`, `medium`, `high`, `xhigh`, `max` - the script rejects anything else rather than
letting the CLI fail N times. If a trial run under-extracts (few facts from a rich
transcript), raise to `medium` before reaching for a bigger model; extraction is
recall-bound, not reasoning-bound.

- `--safe-mode` disables hooks, plugins, skills and CLAUDE.md for the child. Without it
  every extraction pays for the SessionStart brain injection and re-greps the bundle -
  N times over. Use this rather than `--bare`, which forces `ANTHROPIC_API_KEY` and
  breaks subscription auth.
- `--no-session-persistence` keeps the child from writing its own transcript. Otherwise
  the backfill litters `~/.claude/projects` with N new sessions that the next `brain-sweep`
  dutifully tries to harvest - the loop feeding itself.
- The transcript is piped in on **stdin**, pre-trimmed by `${CLAUDE_SKILL_DIR}/scripts/trim-transcript.py`
  (user and assistant text only; tool results, diffs and base64 dropped). No tools, no
  file access, no permission prompts - text in, JSON out.

Each item's candidates land in `$BRAIN_REPO/.claude/state/backfill-candidates/<id>.json`,
then the manifest entry flips to `"done"`. Mark failures `"failed"` with the reason and
carry on - one bad transcript must not end the run.

Respect a budget ceiling if the user set one; stop cleanly at the limit, leave the
manifest resumable, and report how much is left.

### 4. Merge - once, over everything

Only when extraction completes. Load every candidate file and cluster them:

- identical and near-identical facts collapse into one, keeping the **clearest** phrasing
  and the **earliest** date the fact was established
- facts that changed over time become one concept holding the current state, plus dated
  `log.md` entries for the change - this is the format's whole point, so do not emit two
  competing notes
- direct contradictions are not silently resolved. Keep the later one, and record the
  earlier as a superseded entry in the log

This step is worth real effort. Use high or xhigh reasoning here.

### 5. Route and write

Hand the merged set to the **`brain` skill** - it owns routing, confidence thresholds and
logging conventions, and reusing it is what keeps backfill and sweep from drifting apart.

Two rules specific to backfill:

- **Everything is `generated: {by: process:brain-backfill}` and stays unverified.** These
  facts were inferred from transcripts, not confirmed by anyone. A cold start is the
  easiest place in the whole system to manufacture false confidence - a brain that hands
  someone 300 notes that look reviewed is actively worse than one that admits it is
  guessing. `verified` is earned, never routine.
- **Low-confidence items go to `inbox/`, not into a domain.** Backfill output is a
  proposal, not a commit.

### 6. Validate, log, report

Run the validator (`--strict`) and fix what it flags. Append a `**Milestone**` entry to
the bundle's root `log.md` recording the backfill: source, items processed, facts landed,
items skipped or failed.

Report: items processed, candidates extracted, facts after merge (the gap between those
two numbers is the interesting one), what went to `inbox/`, and anything that failed.
Then delete the candidates directory - the manifest stays as the record.

## Failure Modes

- **No transcripts** - say so and ask for a source. Never report an empty backfill as success.
- **Interrupted** - expected. Re-run; the manifest resumes. Say how many remain.
- **`claude` not on PATH** - stop with the fix; do not fall back to in-session extraction
  of hundreds of transcripts, which will blow the context window.
- **A source that yields zero facts** - check the prompt before the effort level. Notes
  and memory files are a different shape from transcripts and an over-strict exclusion
  list rejects them wholesale.
- **Huge transcript** - `trim-transcript.py` truncates to a head+tail window and notes the
  truncation in the candidate file rather than failing the item.
- **A brain that already has content** - fine, but dedup against existing notes in step 4,
  not just within the run.
