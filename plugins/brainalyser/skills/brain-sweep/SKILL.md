---
name: brain-sweep
description: Harvest durable facts from recent Claude sessions and auto-memory into the brain (the user's OKF bundle) - the scheduled catch-all layer under in-session capture. Use for the daily-brain-sweep scheduled task, or when the user says sweep the brain, harvest recent/yesterday's sessions, or catch up the brain.
compatibility: Requires the brain skill (same repo), uv, git, and read access to ~/.claude/projects. ccd session-mgmt MCP optional (graceful fallback). Repo root from $BRAIN_REPO, default ~/dev/myMemory.
allowed-tools:
  - Bash(bash "${CLAUDE_SKILL_DIR}/scripts/discover.sh")
  - Bash(bash "${CLAUDE_SKILL_DIR}/scripts/discover.sh" *)
  - Bash(uv run "${CLAUDE_PLUGIN_ROOT}/skills/validate/scripts/okf_validate.py" *)
  - Bash(uv run "${CLAUDE_PLUGIN_ROOT}/skills/brain/scripts/list_stale_and_unverified.py" *)
metadata:
  author: wikus
  version: "0.3.0"
  purpose: utility
  type: P1
disable-model-invocation: false
user-invocable: true
---

# Brain Sweep

Catch-all harvest: find durable facts that recent Claude sessions produced but
the brain doesn't have yet, and capture them via the brain skill. Be
conservative - durable facts only. GitHub is the work tracker: quest notes
mirror issues/PRs for context only; never create board/tracking files.

## When to Use

- The daily-brain-sweep scheduled task fires (its prompt is a thin pointer here)
- The user says sweep the brain, harvest recent/yesterday's sessions, or catch the brain up

## Workflow

### 1. Watermark

Read `.claude/state/harvest-state.json` (`{"last_run": "<ISO timestamp>"}`).
If missing, treat the window as the last 24 hours. All discovery below means
"modified since the watermark". The file is written again at the very end
(step 6) - it is gitignored and per-machine, never commit it.

### 2. Discover

- Local transcripts + auto-memory: `bash "${CLAUDE_SKILL_DIR}/scripts/discover.sh"` - returns JSON
  with transcripts and memory files since the watermark, newest first, capped
  at 10 transcripts. myMemory's own sessions are excluded (no self-referential
  loops), and so are subagent/workflow transcripts - their content belongs to
  the parent session. Report anything listed under `skipped_by_cap`.
- Remote/archived sessions: if the ccd session-mgmt MCP tools are available,
  `list_sessions` (`include_archived: true`) -> keep sessions active since the
  watermark that have no local transcript under `~/.claude/projects`, still
  excluding myMemory's own -> read each via `list_events` (counts toward the
  transcript cap). These tools may be absent or need approval in scheduled
  runs: skip gracefully and note it in the report; list any unreadable
  sessions there for manual harvest via the brain skill.
- If nothing is found, still run step 5's validation, then write the watermark
  and report.

### 3. Extract candidates

For each transcript: skim for durable facts - decisions made, learnings and
gotchas discovered, wins landed, new people/tools/projects encountered, quest
progress, preferences expressed. For large transcripts, spawn a subagent
(Agent tool) to read it and return a compact structured list of candidates
(fact, route guess, evidence) - keep the main context small. Ignore ephemeral
content: debugging state, tool output, dead ends, point-in-time observations.
Ignore ideas/systems the user has explicitly retired (check the relevant
log.md files for retirement decisions before resurrecting an old concept).

Auto-memory files are already distilled - take their durable content as
candidates directly.

### 4. Dedup, then capture

For each candidate, Grep `brain/` (concepts + logs) for it. Skip known facts -
including facts already recorded as log entries.

Dedup EVERY candidate, not a sampled subset. Immediately before writing any new
note, run one more Grep for that note's own topic - its title, filename stem,
and any codename or GitHub handle it hides under (e.g. `grep -rli "pr-watchdog"
brain/`; a person can appear as a handle like `sixtymage`). On a hit, enrich or
fold into the existing note instead of creating a sibling. A silent duplicate is
worse than a miss: the sweep reports "captured, validated, pushed" while
fragmenting the brain. Treat this per-note grep as mandatory, like the final
`okf_validate` run.

For genuinely new facts, invoke the `brain` skill and follow its capture flow
(routing rules, okf conventions, log + index maintenance, below-0.5
confidence -> `inbox/`). If the skill isn't loaded in this session, read
`${CLAUDE_PLUGIN_ROOT}/skills/brain/SKILL.md` and its `references/REFERENCE.md` directly
and follow them.

**Trust and freshness on every write** (full policy in the brain skill's
`references/REFERENCE.md`):

- `generated: {by: claude-code/<model>, at: <today>}` on new notes; when you
  enrich an existing note in place, refresh `generated.at` too - a note whose
  body you rewrote but whose `generated.at` still reads three weeks old is the
  same drift this sweep exists to prevent.
- `verified` is earned, not routine. Append `{by, at}` only when the fact was
  genuinely confirmed: `human:<you>` when they stated it themselves in the
  transcript (his own preference, decision, or a colleague he works with),
  `claude-code/<model>` when the session actually checked it against ground
  truth (gh API, live config, source). A fact merely *asserted* in a
  transcript is not verified - leave the field off. Never overwrite an existing
  entry; the list is an audit trail.
- `stale_after` per policy on new live work. When a harvested fact moves a
  quest's next dated commitment, update that quest's `stale_after` to the new
  date - that is the sweep's main freshness job, and it is what keeps the
  weekly audit's stale list honest rather than decorative.

### 5. Validate, commit, push

- `uv run "${CLAUDE_PLUGIN_ROOT}/skills/validate/scripts/okf_validate.py" brain` - include
  errors/warnings in the report (report-only; do not fix findings you didn't
  cause this run, except conformance errors in files you just wrote).
- `uv run "${CLAUDE_PLUGIN_ROOT}/skills/brain/scripts/list_stale_and_unverified.py" brain --soon 7` -
  report the counts, plus any note going stale within 7 days. Two of these are
  actionable in a sweep and the rest are not:
  - a **due-soon quest whose commitment this sweep just advanced** -> update its
    `stale_after` now, while the evidence is in front of you;
  - a **missing `stale_after`** on live work you created this run -> add it.

  Do NOT chase the existing stale list here; that is the weekly audit's job and it
  proposes rather than mutates. Surfacing it daily is what stops a stale note
  sitting for a week.
- Conventional commits, max 2 files per commit (a concept + its index/log
  updates are one logical change), trailer
  `Co-Authored-By: Claude <model name from this session> <noreply@anthropic.com>`.
- `git push origin main` from the repo root (never force). If there are
  uncommitted brain files you did NOT create (another session mid-capture),
  leave them uncommitted and note them in the report.

### 6. Watermark + report

Write `.claude/state/harvest-state.json` with the current ISO timestamp.
Report short and casual: sessions scanned/skipped, candidates found, concepts
created/updated, log entries added, dedup skips, inbox items, validation
result, freshness counts (stale / due-soon / missing `stale_after`) and any
`stale_after` dates this run moved, push status.

## Example Inputs

- "sweep the brain" / "/brain-sweep"
- "harvest yesterday's sessions into the brain"
- the daily-brain-sweep scheduled task prompt

## Edge Cases

- **ccd session-mgmt MCP absent/unapproved**: local-only sweep; note the gap
  and any known-but-unreadable sessions in the report
- **Transcript cap hit**: harvest the newest 10, list the skipped ones in the
  report - they'll be older than the new watermark, so flag them for a manual
  sweep rather than silently dropping them
- **Nothing discovered**: still validate, write the watermark, and report
- **discover.sh fails**: fall back to the inline `find` commands documented in
  its --help; note the failure in the report

## File References

`${CLAUDE_SKILL_DIR}` is this skill's own directory and `${CLAUDE_PLUGIN_ROOT}` the
installed plugin root; Claude Code substitutes both, so these paths resolve wherever the
plugin lives and whatever the working directory is. Paths without a variable are relative
to the bundle repo root.

- `${CLAUDE_SKILL_DIR}/scripts/discover.sh` - local discovery: transcripts + auto-memory since the
  watermark, JSON out
- `${CLAUDE_PLUGIN_ROOT}/skills/brain/scripts/list_stale_and_unverified.py` - §5.5
  staleness + §5.3 trust tiers; same script the weekly audit runs, so both apply
  one policy
- `${CLAUDE_PLUGIN_ROOT}/skills/brain/SKILL.md` - capture mechanics this skill
  delegates to
- `.claude/state/harvest-state.json` (repo root, gitignored) - the watermark
