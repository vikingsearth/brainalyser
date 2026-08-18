---
name: brain-init
description: Create a new brain from scratch - interview the user about what they actually want to remember, scaffold an OKF bundle around their answers, and seed it with their first facts. Use when someone has no bundle yet, says set up my brain / start a second brain / I just installed brainalyser, or when BRAIN_REPO points nowhere.
compatibility: Requires uv and git. Writes to $BRAIN_REPO (default $HOME/dev/myMemory); the bundle is $BRAIN_REPO/brain.
metadata:
  author: wikus
  version: "0.1.0"
  purpose: utility
  type: P1
disable-model-invocation: false
user-invocable: true
---

# Brain Init

Stand up a new OKF bundle **shaped around this user**, not around a template.
The interview is the point: a brain whose top level does not match how its owner
thinks gets abandoned. Do not skip it and scaffold a default.

## When to Use

- The user has no bundle yet, or `BRAIN_REPO` resolves to nothing
- "set up my brain", "start a second brain", "I just installed brainalyser"
- **Not** for adding a domain to an existing bundle - that is a normal `brain` capture

## Guardrails

- **Never overwrite an existing bundle.** If `$BRAIN_REPO/brain/index.md` exists, stop and
  say so. Offer `brain-backfill` (to fill an existing brain) instead.
- **Ask, then confirm, then write.** Show the proposed layout and get a yes before creating files.
- **Small beats complete.** Three domains they will use beats nine they will not.
  Steer to 3-5. They can add more the first time something does not fit.
- Everything written here is `generated: {by: process:brain-init}` and **unverified**.
  Seeds are the user's own words, so `verified: [{by: human:<id>, at: <today>}]` is
  legitimate on those - but only those.

## Workflow

### 1. Locate

Resolve `BRAIN_REPO` (default `$HOME/dev/myMemory`). Confirm the path with the user
before creating anything - this is where their brain lives from now on. If the
directory is not a git repo, offer to `git init` it.

### 2. Interview

Ask these **one at a time**, conversationally. Keep it under five questions; a long
interview is where people quit. Adapt wording to how they answer.

1. **"What do you spend most of your working time on?"**
   Derives the candidate domains. Listen for recurring nouns: repos, products, clients, subjects.
2. **"What do you find yourself telling an AI over and over?"**
   This is the highest-value question. The answers become the seed concepts in step 5,
   and they are usually preferences and people facts.
3. **"When you go looking for something you wrote down, what do you search by -
   the topic, or roughly when it happened?"**
   Topic -> categorical top level (domains by subject). When -> timeline top level
   (`daily/`, `weekly/`, `monthly/`, or `<year>/<month>/`). Both are valid OKF; this is a
   genuine fork, so take their answer at face value rather than steering to categorical.
4. **"Is any of this tied to one employer - stuff that would be useless or
   not yours if you changed jobs?"**
   Yes -> add a company-bound domain (let them name it, e.g. `acme-tribal-knowledge/`)
   and keep it separate from portable knowledge. This split is much cheaper to make now
   than to retrofit.
5. **"Anything you want to track that we have not covered?"**

### 3. Propose

Show the layout as a plain tree and say what each domain is for, in their words, not
OKF jargon. Ask for edits. Expect renames - take them.

Default layout, only for someone with no opinion (see
[the brain skill's domain map](../brain/references/REFERENCE.md)):
`preferences/`, `people/`, `projects/`, `performance/`, `concepts/`.

### 4. Scaffold

On confirmation, create under `$BRAIN_REPO/brain/`:

- `index.md` at the root - **must** declare `okf_version: '0.2'` in frontmatter, and
  list every domain with a one-line description
- one directory per agreed domain, each with an `index.md` (navigation) and `log.md` (history)
- a root `log.md` whose first entry is dated today and marked `**Creation**`

Use the `okf` skill's templates rather than inventing structure. If `okf_init.py`
covers a step, prefer it over hand-writing.

### 5. Seed

Turn the step-2 answers into 3-5 real concepts - not placeholders. A brain whose
first session produces empty scaffolding reads as homework; one that already answers
a question reads as useful.

Include a person concept for **the owner themselves**. A bundle that knows the team
and not its owner cannot resolve "I" or "my", and that gap is invisible until it bites.

### 6. Wire up

- Tell them to set `BRAIN_REPO` if the bundle is not at the default path, and show the
  exact export line for their shell.
- Confirm the SessionStart hook picks the bundle up - the next session should announce it.
- Offer `brain-backfill` if they have existing material worth pulling in.

### 7. Validate and commit

Run the validator from the repo root and fix anything it flags:

```
uv run <plugin>/skills/validate/scripts/okf_validate.py brain --strict
```

Then commit. Report: where the bundle is, its domains, how many concepts, and the
one next action (usually "just talk to me normally - I will capture as we go").

## Failure Modes

- **Bundle already exists** - stop, do not merge. Suggest `brain-backfill`.
- **User wants everything tracked** - push back once, land on 3-5, note that adding a
  domain later costs nothing.
- **User has no answers** - do not invent domains for them. Scaffold `inbox/` plus one
  domain, and say the shape will emerge from a week of use. An honest small brain beats a
  fabricated taxonomy.
- **Validator fails** - fix before commit; a bundle that starts non-conformant stays that way.
