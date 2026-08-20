# Brain Reference

Routing rules, thresholds, and conventions for the brain skill. The format
authority is the OKF spec (the plugin's `skills/okf/reference/SPEC.md`) - this file
is the working cheat sheet for THIS bundle's layout, not a second spec.

## Repo root resolution

All paths are relative to the brain repo root: `$BRAIN_REPO` if set, else
`~/dev/myMemory`. The bundle root is `brain/` inside it.

## Domain map

**The bundle's own `index.md` is authoritative.** Read it first and route into the
domains it actually lists. The table below is the *default* layout `brain-init`
scaffolds for someone with no preference - it is a starting point, not a schema.
Users name their own top level, and a bundle with three domains is as valid as one
with nine. When a routing rule below names a domain the bundle does not have, route
to the nearest domain it does have, or to `inbox/` if nothing fits.

| Domain | Holds | Shape |
|---|---|---|
| `preferences/` | how the user likes things done (theirs and others') | flat concepts |
| `performance/goals/` | long-running directions (active/achieved/retired) | wins link to the goal they evidence; quests link to the goal they serve; a goal persists where a quest completes |
| `performance/learnings/<topic>/` | insights, TILs, caveats | topic dirs: gitops, infra, agents, devops, observability, capacity, toolchain, workflow, tools |
| `performance/wins/<area>/` | wins - not just code (communication, leadership, voicing) | per-area `log.md` stream; every entry ends in a `Serves:` link (or explicit `Serves: none`) - the win->workstream join lives nowhere else, since the area dir carries the *area* only; **large** wins also get a concept note, nominated `**large** (note owed)` when the note lags |
| `people/<team>/` | colleagues + stakeholders | team dirs of your choosing (e.g. `platform`, `design`, `leadership`); teamless at `people/` root |
| `projects/<repo>/` | durable products/platforms (repo-shaped) | `project.md` + `log.md` + notes per dir |
| `quests/<slug>/` | workstreams | `quest.md` (creation note) + `log.md` (progress) + artifact notes; workstream lifecycle is `workstream_status: active\|paused\|completed\|abandoned` (NOT `status:`, which OKF v0.2 §5.4 reserves for document lifecycle `draft\|stable\|deprecated`); `quest_type: main\|side\|errand` is the **class** (size and whose repo) and `priority: high\|normal\|low` is separate - they are NOT the same axis; at most one active quest holds `priority: high`; `quests/index.md` is sectioned Active/Completed/Abandoned, high-priority first - keep both in step on workstream_status/priority changes |
| `concepts/` | portable mental models - portable across employers | flat concepts |
| `tribal-knowledge/` | company-bound knowledge - stays behind at a job change | flat concepts |

## Routing rules (classify -> route)

| Signal in input | Route | Operation |
|---|---|---|
| "working on...", "starting...", "new task..." | `quests/<slug>/` | create `quest.md` (+ `log.md`), add to quests index |
| progress on existing work ("done with...", "blocked on...", "merged...") | the quest's `log.md` | append dated entry; flip `workstream_status:` in quest.md when it changes |
| "found that...", "discovered...", "TIL...", caveats | `performance/learnings/<topic>/` | create learning concept; new topic dirs are fine (2+ notes rule of thumb) |
| a win (shipped, solved, unblocked, grew - any area) | `performance/wins/<area>/log.md` | append dated entry with **small**/**medium**/**large** marker sized on the *outcome* not the effort, ending in a required `Serves:` link to the quest/project/goal it advanced (or `Serves: none`); large also owes a concept note - nominate as `**large** (note owed)` rather than downgrading |
| a long-running direction ("my goal is...", "working toward...") | `performance/goals/` | create/update a goal concept; wins + quests link back to it |
| fact about a colleague/stakeholder | `people/<team>/<first-last>.md` | create/update person concept (full-name slug, per the person-node-surnames preference) |
| "I prefer...", "always do X...", "never do Y..." | `preferences/` | create/update preference concept |
| "we decided...", "chose X over Y because..." | the decided-about thing's `log.md` | append `**Decision**:` entry with rationale - decisions are log entries, not notes |
| dated happening (incident, milestone, go-live) | nearest scope's `log.md` | append `**Milestone**:`/`**Incident**:` entry |
| jargon/mental model, portable ("an envelope is...") | `concepts/` | create/update concept |
| company-bound knowledge (org facts, operators, glossary, internal maps) | `tribal-knowledge/` | create/update concept |
| ambiguous / no clear target | `inbox/` (repo root) | raw dump `<YYYY-MM-DD-slug>.md` |

Portable-vs-company test: would this knowledge still be true and usable at the
next employer? Yes -> `concepts/` or a learning. No (it's about your employer's
structure, products, people, or instances) -> `tribal-knowledge/`,
except operational learnings which stay in `performance/learnings/` regardless
(the learning is the durable part; tag company specifics inline).

## Confidence thresholds

| Confidence | Action |
|---|---|
| >= 0.8 | Write directly |
| 0.5 - 0.8 | Write to best-fit path + append `[review] <what was assumed>` to the log entry |
| < 0.5 | Raw dump to `inbox/` - never guess, never lose input |

## Concept conventions (this bundle)

Frontmatter (`type` is the only REQUIRED field; the rest recommended):

```yaml
---
type: person | project | quest | learning | preference | concept | org | tool
title: Human-Readable Name
description: One sentence for index listings and search snippets.
tags: [infra, gitops]
generated:                       # §5.2 - who wrote this content, when
  by: claude-code/opus-5
  at: '2026-08-11'
verified:                        # §5.2 - OPTIONAL; only when actually confirmed
  - by: human:<you>
    at: '2026-08-11'
stale_after: '2026-09-10'        # §5.5 - OPTIONAL; see the policy below
# extension keys (ours, not the spec's): role/github/team (person),
# workstream_status (quest/project), confidence (learning), strength (preference),
# quest_type (quest), priority, domain, source, ...
---
```

### Trust and freshness (OKF v0.2 §5)

Three fields the spec defines; the *policy* for when to use them is ours.

| Field | Rule |
|---|---|
| `generated: {by, at}` | Always. `at` = the last **meaningful content change**, so refresh it when you materially rewrite a note (not for a typo). Replaces v0.1 `timestamp`. |
| `verified: [{by, at}]` | Only when the content was genuinely **confirmed against its sources**. Append an entry, never overwrite - it's an audit trail. |
| `stale_after: YYYY-MM-DD` | When to re-check. Only where truth depends on a changing world (see policy). |

**Actors** follow §7: `human:<id>` for a person (`human:<you>`, e.g. `human:jordan`), `<producer>/<version>`
for an agent or tool (`claude-code/opus-5`), `process:<id>` for automation
(`process:okf-migrate`). The lowercase `human:` prefix is the whole key to the trust
tier - `Human:<you>` silently reads as an agent.

**What counts as verification here:**

| Situation | `verified.by` | Tier |
|---|---|---|
| The user states the fact themselves (their preference, their decision, a person they work with) | `human:<you>` | human-reviewed |
| An agent checked it against ground truth (gh API, live config, source, a running system) | `claude-code/<model>` | machine-confirmed |
| Transcribed, inferred, or copied from another note without checking | *omit* | unverified |

Do NOT add `verified` to claim a note is good. An unverified note is perfectly
legal (§5.3 forbids rejecting one) and honest; a falsely verified note poisons the
signal. If only part of a note checks out, leave it unverified and fix the rest.

`verified` does not replace `confidence` - they are different axes. `confidence`
is how strong the claim is (`hunch`/`confirmed`/`battle-tested`); `verified` is who
checked it and when.

**`stale_after` policy** (encoded in this skill's `scripts/list_stale_and_unverified.py`, so the
sweep and the audit apply it identically):

| Note | `stale_after` |
|---|---|
| active quest | the next dated commitment the note names, else +30d |
| paused quest | +90d (revisit or abandon) |
| active/paused project | +90d |
| completed/abandoned quest or project | **none** - history cannot go stale |
| preference, concept, goal, org | **none** - true until changed, not until a date |
| person, tool, learning, tribal knowledge | **not automatic** - add one only when the note names a pending change worth chasing (a role about to change, a version pin expected to move, a live-config claim) |

Prefer the date the note itself commits to over the default horizon: a quest saying
"meet X on 27 Jul" should go stale on 27 Jul, which is exactly the drift the horizon
would otherwise hide.

- Path = concept ID; slugs kebab-case; people use full-name slugs.
- Links bundle-absolute: `[Jordan Lee](/people/team/jordan-lee.md)`.
  The relationship kind lives in the prose ("Works on", "Taught me", ...) -
  by convention in a `## Related` section.
- Broken links are legal (§5.3) - not-yet-written knowledge.

## Log conventions

Per-scope `log.md`, date-grouped, newest first (§7):

```markdown
# Update Log

## 2026-07-21
* **Decision**: Chose X over Y because Z.
* **Update**: Shipped the thing - see [note](/path/note.md).
```

Bold lead words by convention: **Creation**, **Update**, **Decision**,
**Milestone**, **Incident**, **Deprecation**. History is append-only; the
current state lives in the concept, the timeline in the log, the diff in git.

## Index maintenance

Every directory keeps an `index.md` (no frontmatter; the bundle root's carries
only `okf_version`). Entry format:

```markdown
* [Title](file.md) - description from the concept's frontmatter
```

When adding/renaming/removing a concept, touch the directory's index in the
same change. Indexes are listings, never state or tracking surfaces.
