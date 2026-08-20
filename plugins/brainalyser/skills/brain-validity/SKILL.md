---
name: brain-validity
description: Audit the brain (the user's OKF bundle) for validity - okf conformance plus reality-drift checks against GitHub and the logs - and write findings as a checkbox report in inbox/. Proposes only, never mutates. Use for the weekly-brain-validity scheduled task, or when the user asks to validity-check, audit, or lint the brain.
compatibility: Requires uv and git; gh optional (GitHub bucket skips gracefully without auth). Repo root from $BRAIN_REPO, default ~/dev/myMemory.
allowed-tools:
  - Bash(uv run "${CLAUDE_PLUGIN_ROOT}/skills/validate/scripts/okf_validate.py" *)
  - Bash(uv run "${CLAUDE_PLUGIN_ROOT}/skills/brain/scripts/list_stale_and_unverified.py" *)
  - Bash(uv run "${CLAUDE_PLUGIN_ROOT}/skills/brain/scripts/wins_by_stream.py" *)
  - Bash(bash "${CLAUDE_SKILL_DIR}/scripts/okf_spec_watch.sh" *)
metadata:
  author: wikus
  version: "0.3.0"
  purpose: utility
  type: P1
disable-model-invocation: false
user-invocable: true
---

# Brain Validity

Weekly validity audit for the brain. **HARD RULE: this skill PROPOSES, it
never mutates** - do not edit any bundle concept, index, or log. The only
writes allowed are the report file, the okf-spec watermark, and their commits.

## When to Use

- The weekly-brain-validity scheduled task fires (its prompt is a thin pointer here)
- The user asks to validity-check, audit, or lint the brain
- Returning to the brain after a long gap and wanting a drift check first

## Workflow

### 1. Conformance (mechanical)

Run `uv run "${CLAUDE_PLUGIN_ROOT}/skills/validate/scripts/okf_validate.py" brain --strict`
from the repo root. Collect all errors and warnings (missing/invalid
frontmatter, missing `type`, broken cross-links, reserved-file misuse).
Broken links are spec-tolerated - report them as candidates for either writing
the missing concept or fixing a typo'd path, not as failures.

### 2. Reality drift (agent judgment + gh ground truth)

- **Quest vs GitHub reality**: Grep `brain/quests/` for PR/issue references
  (patterns like "PR 5541", "issues 1073", "#6425"; repo hints in parentheses
  - a repo hint maps to a real `<owner>/<repo>` you configure).
  For each, check real state with `gh` (e.g. `gh pr view 5541 --repo
  <owner>/<repo> --json state,mergedAt`). Flag mismatches: quest
  `workstream_status: active` but its PR merged/closed weeks ago with a silent
  log, quest paused but work visibly moving, etc. Also check *what a closure
  meant* - a COMPLETED issue can be an umbrella closed over unfinished
  children, or scope only half-delivered, so read the closing comments before
  trusting the state. If gh auth fails, note it and skip gracefully.
- **Status coherence**: quests marked active whose parent project is paused
  (check the linked project.md's `workstream_status:`) - flag for confirm.
  Note `workstream_status` is ours (active/paused/completed/abandoned); `status`
  is OKF v0.2 §5.4 document lifecycle (draft/stable/deprecated) - different axis.
- **Note-vs-log contradiction**: concepts whose body asserts something their
  own log.md (or the domain log) records as changed/retired - flag with both
  quotes. The log is the timeline; the note must read as current truth.
- **Staleness and trust (mechanical - run this, don't eyeball it)**:
  `uv run "${CLAUDE_PLUGIN_ROOT}/skills/brain/scripts/list_stale_and_unverified.py" brain`
  from the repo root. It derives §5.5 staleness and §5.3 trust tiers under the
  one shared policy (same script the daily sweep runs), so this bucket is a date
  comparison, not a judgement call. Report:
  - **stale** (`today >= stale_after`): each with its days-overdue and last
    verification. Read the note before proposing - a stale quest usually needs
    either its next commitment re-dated or its `workstream_status` flipped, and
    which one is the actual finding.
  - **missing `stale_after`** where the policy requires it (live quests and
    projects) -> propose the policy date, or the next dated commitment the note
    names if it has one (prefer the note's own date - that is the drift the
    default horizon hides).
  - **trust tiers**: the distribution, plus any note that *asserts a checkable
    claim about a live system* yet sits unverified. Do NOT propose adding
    `verified` to clear a number - unverified is legal and honest (§5.3), and a
    falsely verified note is worse than an unverified one. The finding is "this
    is worth verifying", never "mark this verified".
  - a stale note whose `verified` is recent is a *specific and useful* signal:
    the content was confirmed but the commitment lapsed. Say so rather than
    lumping it in with never-verified notes.
- **Win attribution and owed notes (mechanical - run this, don't eyeball it)**:
  `uv run "${CLAUDE_PLUGIN_ROOT}/skills/brain/scripts/wins_by_stream.py" brain --orphans`
  from the repo root. It inverts the `Serves:` links into a per-stream roll-up.
  This is the only place the win->workstream join exists, so a gap here is
  invisible everywhere else. Report:
  - **unattributed** entries (no `Serves:` at all, or a malformed one): the fix
    is to name the quest/project/goal the win advanced, or write `Serves: none`
    if it advanced nothing tracked. Propose the target; never guess silently.
  - **`Serves: none` count**: a recorded judgement, not a gap - report the number
    without proposing changes, but look at any entry where the prose plainly
    names a live quest the field says it served nothing.
  - **large wins owing a concept note** (`**large** (note owed)` with no note
    beside the log): the note is the promo-case artifact, so an owed one that has
    sat for more than a couple of weeks is the finding.
  - **a live quest or project with zero attributed wins**: either the work
    produced nothing loggable (worth knowing) or wins are landing without the
    link. Cross-check its `log.md` activity before deciding which.
  - **zero large wins over a long window**: read this as a sizing-discipline
    signal, not a fact about the work. Sizes track outcome, not effort, and the
    smaller-when-unsure tiebreak biases down - if a period of shipped, adopted
    work shows `l0`, the plausible finding is that large wins are being logged
    as medium, and the entries to re-read are the ones others now depend on.
- **Learning decay**: learnings with `confidence: hunch` older than 60 days ->
  flag "confirm or prune". Learnings referencing retired tools or superseded
  facts -> flag for an in-place correction + log entry. Cross-check against the
  trust output above: a `confidence: battle-tested` note that has never been
  verified, or whose newest `verified.at` is over a year old, is worth a look -
  `confidence` is how strong the claim is, `verified` is who last checked it, and
  a large gap between the two is the interesting case.
- **Index drift**: directory contents vs the directory's `index.md` - missing
  entries, entries for deleted files, stale descriptions.
- **Stale concepts**: notes embodying ideas/systems the user has retired
  (check **Decision**/**Deprecation** log entries) still phrased as current.

### 3. Clustering gap-finder (agent judgment, propose only)

Spawn one subagent (Agent tool) to read every concept (title + frontmatter +
first ~10 body lines) and propose 5-8 CROSS-DOMAIN thematic clusters
(e.g. a quest + its learnings + preferences + people). Then diff the clusters
against the link layer:

- **Missing links**: pairs of concepts in the same cluster with a clear
  durable relationship but no markdown link in either direction (the payoff
  case: a problem note and its solution quest never linked). Propose the
  exact `## Related` line + which concept it goes on.
- **Bridge concepts**: concepts connecting 2+ clusters - name them (context
  only, no action needed).
- **Orphan drift**: concepts that fit no cluster AND have no inbound/outbound
  links - flag "enrich or accept as leaf".

Only report high-confidence missing links (justify each in one sentence from
the note bodies). This is a gap-finder, not a navigation layer - do not write
cluster tags or touch any note.

### 4. OKF spec watch (mechanical)

The brain is built on the Open Knowledge Format; upstream spec changes need a
human decision, never silent adaptation.

**Mechanical - run this, don't hand-roll it:**

```
bash "${CLAUDE_SKILL_DIR}/scripts/okf_spec_watch.sh"
```

It fetches, hashes, and compares against `.claude/state/okf-spec.sha` for you.
Read its `status:` line - `UNCHANGED` / `CHANGED` / `FIRST-RUN` / `FETCH-FAILED`
(exit 0 / 10 / 20 / 1).

**Do not hand-roll the hash.** The obvious spelling is wrong in a way that fails
towards a false alarm: `SPEC=$(curl ...)` strips trailing newlines - command
substitution always does - so hashing `"$SPEC"` gives a digest one byte short of
the file and reports the spec as CHANGED on **every** run. That is the single
most expensive false positive in this audit, because a real spec change is meant
to stop the work and pull a human in. The script hashes the file on disk and
never pipes the body through the shell.
- **Unchanged**: one line in the report ("okf spec unchanged, v0.2").
- **Changed**: flag it prominently - old/new version lines and a short diff
  summary of what moved (fetch, skim, summarize; do NOT adapt anything). This
  is a discussion trigger for the user, not a work item. Also check the vendored
  copy at `${CLAUDE_PLUGIN_ROOT}/skills/okf/reference/SPEC.md` and note that re-vendoring
  (see `${CLAUDE_PLUGIN_ROOT}/skills/okf/VENDORED`) is part of the eventual adaptation.
- Update the watermark by re-running with `--update` (it preserves `seeded:`),
  and commit it alongside the report - the ONE exception to report-only writes
  (it is the watch's watermark, same pattern as harvest-state). Only after the
  change has been reported, never in the same breath as detecting it.
- Fetch fails (offline/moved): the script exits 1 with `FETCH-FAILED` and the
  real HTTP code - note it and skip the bucket. A 404 is itself a finding (a
  moved spec is a change worth discussing), so never record a failed fetch as
  "unchanged".

### 5. Report (the ONLY writes allowed)

Write findings to `inbox/validity-report-<YYYY-MM-DD>.md` (repo root, outside
the bundle):

- One section per bucket (conformance / github drift / status coherence /
  note-vs-log / staleness + trust / learning decay / preference drift / index
  drift / stale concepts / clustering gaps / okf spec watch).
- Each finding as a markdown checkbox `- [ ]` with: the concept path, what's
  wrong, evidence (e.g. "PR 5541 merged 2026-06-30"), and the PROPOSED change
  spelled out concretely (exact edit / log entry / status flip) so approving
  it is one small edit.
- If everything is clean, still write the report with "all clean" - absence
  of a report should mean the check didn't run, not that all was well.

Commit just that file (conventional commit, trailer
`Co-Authored-By: Claude <model name from this session> <noreply@anthropic.com>`)
and `git push origin main` (never force). Leave any other uncommitted files
alone.

### 6. Summary

Short casual summary: findings per bucket, the report path, and the top 2-3
items most worth acting on. No fluff.

## Example Inputs

- "validity-check the brain" / "/brain-validity"
- "is the brain drifting from reality?"
- the weekly-brain-validity scheduled task prompt

## Edge Cases

- **gh unauthenticated/unavailable**: note it in the report and skip the
  GitHub-drift bucket; all other buckets still run
- **okf_validate.py fails to run**: report the failure as its own finding and
  continue with the judgment buckets
- **All clean**: write the report anyway ("all clean") - see step 5
- **Everything unverified**: expected, not a finding. The v0.2 migration wrote
  `generated` only, so notes start unverified and earn `verified` as they get
  confirmed. Report the tier distribution as context and move on
- **Tempted to fix a finding**: don't - even one-character fixes go in the
  report as proposals; mutation belongs to the brain skill in a normal session

## File References

`${CLAUDE_SKILL_DIR}` is this skill's own directory and `${CLAUDE_PLUGIN_ROOT}` the
installed plugin root; Claude Code substitutes both, so these paths resolve wherever the
plugin lives and whatever the working directory is. Paths without a variable are relative
to the bundle repo root.

- `${CLAUDE_PLUGIN_ROOT}/skills/validate/scripts/okf_validate.py` - the mechanical half;
  deterministic, run any time
- `${CLAUDE_PLUGIN_ROOT}/skills/brain/scripts/list_stale_and_unverified.py` - the other
  mechanical half: §5.5 staleness + §5.3 trust tiers under the shared policy.
  The daily sweep runs the same script, so a finding here is never a
  disagreement about policy, only about what to do next
- `${CLAUDE_PLUGIN_ROOT}/skills/brain/scripts/wins_by_stream.py` - the win->workstream
  join, derived from `Serves:` links and stored nowhere. `--orphans` lists the
  unattributed, the `Serves: none`, and any large win still owing its concept note
- `${CLAUDE_SKILL_DIR}/scripts/okf_spec_watch.sh` - the spec
  watch, mechanical. Byte-exact by construction; `--update` rewrites the watermark
- `inbox/` (repo root) - where reports land
- `${CLAUDE_PLUGIN_ROOT}/skills/brain/SKILL.md` - the capture flow that acts on
  approved findings later
- `.claude/state/okf-spec.sha` (repo root) - the spec watch watermark
