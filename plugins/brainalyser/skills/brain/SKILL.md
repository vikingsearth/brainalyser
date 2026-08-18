---
name: brain
description: Recall from and capture to the personal knowledge memory (the OKF bundle at brain/ in myMemory). Use when the user asks what do I know about X, says remember, recall, or log this, or shares a durable fact about a person, project, quest, learning, win, preference, decision, or company knowledge.
compatibility: Requires uv and git. Repo root from $BRAIN_REPO, default ~/dev/myMemory.
metadata:
  author: wikus
  version: "0.2.0"
  purpose: utility
  type: P1
disable-model-invocation: false
user-invocable: true
argument-hint: Give a recall question or the fact to capture
---

# Brain

Recall from and capture to the personal knowledge memory: a single OKF v0.2
bundle at `brain/` - markdown + YAML frontmatter, domains as directories,
markdown links as edges, per-scope `index.md` (navigation) and `log.md`
(history). No derived layers: the files ARE the brain. Format authority is the
vendored `okf` skill (spec at `plugins/brainalyser/skills/okf/reference/SPEC.md`).

## When to Use

- The user asks what they know about a person, project, tool, or topic ("what do I know about X", "who is Y", "how do X and Y connect")
- The user says remember / recall / log this / add to the brain
- The user shares a durable fact worth keeping: a person fact, project or quest update, learning, win, preference, decision, or company knowledge
- The user asks to harvest another Claude session - including archived ones - into the brain
- A session-start hook or the user asks for brain context before starting work

## Workflow

**Mode detection**: a question about existing knowledge -> recall. New information to keep -> capture. Both in one message -> recall first, then capture.

### Recall

1. Progressive disclosure: read `brain/index.md` -> the relevant domain `index.md` -> the concept file(s). Descriptions in the indexes are the routing signal.
2. Grep `brain/` when the question is keyword-shaped or spans domains; `log.md` files answer "what happened / when" questions.
3. Answer with sources - cite the concept paths used.
4. History lives in logs and git - if a note contradicts its log, the log is the timeline, the note is the current state.

### Capture

1. Classify the input against the routing rules in [references/REFERENCE.md](references/REFERENCE.md) - domain, target path, operation (create / append / update), confidence.
2. Below 0.5 confidence: write the raw input to `inbox/<YYYY-MM-DD-slug>.md` (repo root, outside the bundle) and stop - never lose input, never guess.
3. Route into the domains the bundle's own `index.md` lists - that list is authoritative, and [references/REFERENCE.md](references/REFERENCE.md)'s domain map is only the default layout. Create concepts per the okf conventions: frontmatter `type` (required) + `title`, `description`, `tags`, `generated: {by, at}`; body with structural markdown; related concepts linked bundle-absolute (`/people/team/jordan-lee.md`) in prose or a `## Related` section. Update existing concepts in place.
   - **Trust and freshness** (see [references/REFERENCE.md](references/REFERENCE.md) for the full policy): set `generated.by` to this session's actor (`claude-code/<model>`) and refresh `generated.at` whenever you materially rewrite a note. Append a `verified: [{by, at}]` entry ONLY when the content was genuinely confirmed against its sources - `human:<you>` when they stated the fact themselves, `claude-code/<model>` when you checked it against ground truth, and nothing at all when you merely transcribed or inferred it. Add `stale_after` per the policy - for a quest, prefer the next dated commitment the note names over the default horizon.
4. Record history: append a dated entry to the nearest `log.md` (quest/project dir for scoped changes, the domain's log otherwise; create the log if missing). Decisions are log entries on the thing they decide about, not their own notes.
5. Maintain navigation: add/update the concept's line in the directory's `index.md`.
6. Superseded facts: correct the note in place and log the change - git history keeps the old truth; never leave a note asserting something the log says stopped being true.
7. Validate when the change is structural (new dirs, renames): `uv run plugins/brainalyser/skills/validate/scripts/okf_validate.py brain`.
8. Commit atomically - conventional commits, max 2 files per commit (a new concept + its index/log touches count as one logical change; bundle them), trailer `Co-Authored-By: Claude <model name from this session> <noreply@anthropic.com>`.
9. End with a one-line receipt: path(s) written + log entries added.

**Harvest from another session**: when the source is a different Claude session (including archived), pull it with the ccd session-mgmt MCP tools - `search_session_transcripts` or `list_sessions` (`include_archived: true`) to locate it, `list_events` to read the transcript - then run each durable fact through the capture flow above.

GitHub is the work tracker - quest notes mirror issues/PRs for context only.
Never build board/tracking files; indexes are listings, not state.

## Example Inputs

- "what do I know about jordan?"
- "/brain how do litellm and the agent SDK connect?"
- "remember: michelle prefers KPI dashboards over raw tables"
- "log this: we decided to keep markdown as the canonical brain store"
- "log the win: shipped the netskope publisher"
- "harvest that archived session about the litellm spike into the brain"

## Edge Cases

- **Ambiguous classification (0.5-0.8)**: write to the best-fit path and add a `[review]` line to the nearest log entry
- **Target concept doesn't exist during an update**: create it (okf templates at `plugins/brainalyser/skills/okf/templates/`), then apply the update
- **Link target missing**: keep the link - the spec tolerates broken links as not-yet-written knowledge (§5.3); create the target if the entity matters
- **New domain or subdomain needed**: propose it to the user first - the domain layout is a design surface, not an extraction detail
- **Fact is company-bound vs portable**: company-bound knowledge (org structure, operators, internal maps - anything that stays behind at job change) goes to `tribal-knowledge/`; portable mental models go to `concepts/`

## File References

Paths below starting `plugins/brainalyser/` are relative to the brain repo root
and assume that clone also hosts this plugin's marketplace (the default setup).
If your `$BRAIN_REPO` holds only `brain/`, the same files sit under the installed
plugin root instead - `~/.claude/plugins/cache/<marketplace>/brainalyser/<version>/skills/...`.

- [references/REFERENCE.md](references/REFERENCE.md) - routing rules, confidence thresholds, frontmatter + trust/freshness + log conventions
- `scripts/list_stale_and_unverified.py` - derives §5.5 staleness and §5.3 trust tiers from the bundle; shared with brain-sweep and brain-validity so one policy applies everywhere
- `plugins/brainalyser/skills/okf/SKILL.md` + `reference/SPEC.md` - format authority (produce/maintain/consume)
- `plugins/brainalyser/skills/okf/templates/` - concept/index/log templates
- `plugins/brainalyser/skills/validate/scripts/okf_validate.py` - conformance checker
- `brain/index.md` (repo root) - the bundle's front door
