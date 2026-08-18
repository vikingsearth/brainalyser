# brainalyser

Machinery for a personal knowledge memory held as an Open Knowledge Format (OKF v0.2) bundle - markdown + YAML frontmatter, one concept per file, directories as domains, per-scope `index.md` (navigation) and `log.md` (history). No graph db, no derived layers: the files ARE the memory. **This plugin ships no knowledge** - it ships the skills that read and write a bundle, the OKF toolchain that validates one, and two hooks that make an agent consult the bundle before making claims about the user's own repos, projects and people.

## Setup

The bundle is mutable data you commit to; a plugin directory is install-managed and gets overwritten on update. They are deliberately separate:

| | lives in | why |
| --- | --- | --- |
| Skills, hooks, OKF toolchain | this plugin | versioned, disposable, replaced on update |
| The bundle (`brain/`) | your own git clone | mutable - you write notes into it and commit |

Both hooks locate the bundle via `BRAIN_REPO`, defaulting to `$HOME/dev/myMemory` (the bundle is `$BRAIN_REPO/brain`). Set it if your clone lives elsewhere - `brain-init` will offer to.

**If this plugin's marketplace is hosted in the same repo as the bundle**, installing it clones a second, read-only copy of `brain/` into the plugin cache. Both hooks refuse to use that copy - capturing into a cache that gets refreshed on update would silently discard notes. Point `BRAIN_REPO` at your working clone.

When no bundle is found, the SessionStart hook says so and instructs the agent to state that recall is unavailable rather than answering from memory about the user's repos or projects.

## Capabilities

- **`brain-init`** (skill) - stand up a NEW bundle. Interviews the user about what they
  actually want to remember and scaffolds around their answers; never overwrites an
  existing bundle. Use when there is no bundle yet.
- **`brain-backfill`** (skill) - one-time cold start from existing material (Claude Code
  history, an export, a notes folder). Sequential background extraction, then a single
  merge pass, then routing through `brain`. Everything it writes stays unverified.
  Not for routine catch-up - that is `brain-sweep`.
- **`brain`** (skill) - recall and capture. Use when the user asks what they know about a person, project, tool or topic; says remember / recall / log this; or shares a durable fact (person fact, quest update, learning, win, preference, decision, tribal knowledge). Owns routing, confidence thresholds and logging conventions.
- **`brain-sweep`** (skill) - scheduled harvest of durable facts from recent sessions into the bundle. The catch-all beneath in-session capture; use for a daily sweep or "catch up the brain".
- **`brain-validity`** (skill) - weekly audit for OKF conformance plus reality-drift against external sources. Proposes only, never mutates.
- **`okf`** (skill) - format authority: author, maintain and consume OKF bundles. Read before inventing frontmatter keys or directory conventions.
- **`validate`** (skill) - deterministic conformance checker (`--strict`) and v0.1 → v0.2 migration. A real checker, not an eyeball pass.
- **`visualize`** (skill) - render a bundle as a self-contained interactive HTML graph.

`okf`, `validate` and `visualize` are vendored upstream code (MIT, scaccogatto/okf-skills) - re-vendor rather than hand-edit; provenance in `skills/okf/VENDORED`.

## Hooks

| hook | fires | does |
| --- | --- | --- |
| `SessionStart` | once per session | announces the bundle and states the recall trigger |
| `UserPromptSubmit` | every message, silent unless matched | greps the bundle for entities named in the prompt, injects matching lines, leads with `workstream_status` |

Both are sensors: they emit context only, never return a permission decision, and never write to the bundle.

## Rules

- **The recall trigger is mechanical, not a judgement call.** Grep the bundle before any factual claim about a named repo, project, person, tool or quest of the user's - including asides, parentheticals, closing summaries and hedges. A hedge is not an exemption.
- **Having an answer already is not a reason to skip it.** A filesystem, git or local-clone answer in hand is the usual reason the answer is stale - a clone can be hundreds of commits behind, and a repo existing on disk says nothing about whether the work is active, paused or abandoned. Only the bundle holds workstream state.
- **Current state lives in the concept; history lives in `log.md`.** If a note contradicts its log, the log is the timeline and the note is the current state. Correct notes in place and log the change.
- **Capture through `brain`, not by hand-editing bundle files** - it owns routing and confidence thresholds, and low-confidence input goes to `inbox/` rather than being guessed into a domain.
- **Start with `okf` before changing bundle structure**, and finish with `validate` - structural changes are the ones that break conformance silently.
