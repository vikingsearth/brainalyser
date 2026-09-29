# Changelog

All notable changes to the brainalyser plugin. Versions follow [semver](https://semver.org);
the plugin's `plugin.json` version is authoritative.

After upgrading, re-copy the routine prompts if this file says they changed - the copies in
`~/.claude/scheduled-tasks/` are snapshots and a plugin update does not refresh them. See
[routines/README.md](routines/README.md).

## [Unreleased]

### Changed
- Routine setup now says which run settings to use: permission mode **Auto** and model
  **Opus 5.5**, on both `daily-brain-sweep` and `weekly-brain-validity`. A new scheduled
  task starts on the app's defaults - manual or accept edits, and the default model - and
  onboarding left it there because the docs only asked for "a permission mode that will
  not stall". Neither setting lives in `SKILL.md` or the scheduled-tasks tooling, so the
  instructions have the user set them in the app's UI. `brain-init` and `START-HERE.md`
  no longer count setup as done until the user confirms both. The routine prompts are
  unchanged, so there is nothing to re-copy.

## [0.6.0] - 2026-08-25

Found by the spec watch shipped in 0.5.0, on its first scheduled run: upstream OKF moved on
2026-08-21 and the watch caught it on 2026-08-24.

### Added
- `validate` now enforces that every timestamp-valued key carries an explicit offset. OKF
  §5 gained a normative sentence - *"Every timestamp-valued key in OKF is an ISO 8601
  datetime with an explicit UTC offset"* - and one matcher now covers `generated.at`,
  `verified[].at`, `stale_after`, `sources[].last_modified` and both `usage_window` bounds.
  `stale_after` previously had its own `YYYY-MM-DD` check and `last_modified` another; the
  spec collapsed those into one rule and so does this.
  The failure it catches is quiet rather than loud: a date-only value reads as valid, sorts
  correctly, and silently makes §5.5's `now >= stale_after` depend on the reader's idea of
  when the day starts. Reported as a warning, so `--strict` is the gate.
- `validate` now enforces bundle-absolute cross-links outside `index.md`. The spec accepts
  both spellings - §6.1 only asks that a path resolve - which is exactly why this drifts: a
  relative link resolves fine and still disappears from any traversal keyed on the leading
  slash, so the note holding it reads as unlinked in the visualizer and in an orphan sweep.
  Four notes had drifted that way before the check existed, one of them losing its only
  outbound edge. `index.md` is exempt deliberately - a directory index is navigation over
  its own contents, where relative entries are the established form.

### Changed
- `okf/reference/SPEC.md` re-vendored from knowledge-catalog `3fcbb9f8` to `62432a09`
  (upstream #323). 43 changed lines, all one theme, and **no version bump - still v0.2** -
  so a bundle that passed yesterday still parses; it is only less precise than the spec now
  asks for. The previously vendored body hashed to exactly the recorded watermark with its
  9-line header stripped, which is what proves the diff is the whole upstream change with
  nothing else mixed in. `SPEC.md` is re-vendored on its own cadence, independent of the
  upstream skills code, so the recorded `okf_visualize.py` layout patch is untouched.
- `list_stale_and_unverified.py` keeps comparing **calendar dates**, deliberately, now that
  §5.5 phrases staleness as `now >= stale_after`. An instant comparison would make a
  same-day check depend on the hour the sweep happens to run, and the consumer of this
  output is a weekly audit that has to raise the same note twice if nothing was done about
  it. An offset-aware value is converted to UTC first, so `2026-08-26T01:00:00+02:00` lands
  on the 25th rather than on whatever its first ten characters say. Its suggested
  `stale_after` is emitted as an instant, so the tool stops proposing values its own
  validator would warn about.
- The skills that author notes now tell their reader to write an instant: `brain-sweep`'s
  `at: <today>`, `brain-init`'s verified seed, `okf`'s concept template, and `brain`'s
  REFERENCE.md worked example would each have produced a value the new check flags. A
  validator warning is only half a fix while the writers still emit the old shape.

### Fixed
- The visualizer would have silently stopped flagging a concept on the exact day it went
  stale. It compared `TODAY` against `stale_after` as strings, and `"2026-08-26" >=
  "2026-08-26T00:00:00Z"` is false because the shorter string sorts smaller. Both consumers
  now slice to the UTC date. A latent trap rather than an observed failure - it required a
  bundle that had already migrated - but it is the class of bug where the badge just never
  appears and nobody notices its absence.

### Upgrade note
A bundle written before this release is **conformant but warns** - one warning per
date-only timestamp. Migrating is a mechanical rewrite of frontmatter timestamp keys to
`<date>T00:00:00Z`; midnight UTC is the reading every consumer already applied implicitly,
so no staleness verdict changes. Do it in this order - update the plugin, then migrate the
bundle. Reversed, the migration is checked by a validator that cannot see the thing being
migrated, and a green `--strict` from an unpublished checker is a claim only its author can
reproduce.

## [0.5.0] - 2026-08-20

Found by running the weekly routine by hand rather than waiting for its Monday dispatch.

### Added
- `brain-validity/scripts/okf_spec_watch.sh` - the OKF spec watch is now a script instead
  of a prose instruction. It fetches to a file, hashes the file, and reports `UNCHANGED` /
  `CHANGED` / `FIRST-RUN` / `PARSE-FAILED` / `FETCH-FAILED` / `HASH-FAILED` / `WRITE-FAILED`
  (exit 0/10/20/30/1/11/40). It also
  distinguishes an in-place spec edit from a version bump - same version line, different
  bytes - which the old wording could not express, and `--update` rewrites the watermark
  while preserving `seeded:`.
  **Only exit 10 means the spec moved.** Every other outcome carries its own status rather
  than being folded into `CHANGED`: a version line that will not parse, a `shasum` that
  produces nothing, and a 404 are each reported as themselves. A false "the spec moved" is
  the expensive direction, because it is the one finding meant to halt the work.

### Fixed
- The spec watch could report the spec as changed when it had not. Step 4 said "fetch the
  spec and compute its sha256" and left the spelling to the reader; the obvious spelling is
  wrong, because `SPEC=$(curl ...)` strips trailing newlines, so hashing `"$SPEC"` digests
  one byte fewer than the file. Observed once, on a manual run on 2026-08-20. The scheduled
  run on 2026-08-24 hashed correctly and caught a genuine upstream change, so this was a
  latent trap in the wording rather than a fault that fired every week - which is the
  argument for a script, since whether it fires depends on which spelling the reader picks. This was the last mechanical bucket still described in
  prose - the staleness and win-attribution buckets have been scripts precisely so they
  cannot be got wrong by hand - and it is the most expensive false positive in the audit,
  since a real spec change is meant to halt the work and pull a human in. Crying wolf
  weekly teaches the reader to skip the one bucket that must not be skipped. `SKILL.md` now
  names the anti-pattern so it does not come back.
- `brain-validity`'s `allowed-tools` now covers the new script in both the bare and
  argument-bearing forms. The detection call takes no arguments, so a single space-wildcard
  entry risked not matching it - which would have stalled the unattended weekly run on a
  permission prompt, the failure that field was added to prevent in 0.4.0. The bare form is
  how this estate already writes a no-argument script permission.
- A version line that does not parse no longer reports as a version change. It used to
  become the literal string `unknown`, which printed as `0.2 -> unknown` and, under
  `--update`, was written into the watermark - so one bad parse poisoned every later
  comparison. It is now `PARSE-FAILED` and refuses to write.
- A failing `shasum` no longer reads as a spec change. `set -e` is deliberately absent so the
  HTTP status can be judged explicitly, which left an empty hash to be compared against the
  watermark; that now exits as `HASH-FAILED`.
- The stored-hash lookup is anchored to `^sha256:`. Unanchored, any line containing the
  substring could win `-m1` - a watermark carrying a comment about `sha256` read the word
  `note` as the hash and reported a false `CHANGED`.
- `--update` announced `watermark : updated` without checking the write landed. Against a
  read-only watermark the redirect failed and it still reported success - the same defect
  the script exists to remove, one level down. It now verifies the file contains the hash it
  meant to write and exits 40 as `WRITE-FAILED` otherwise.
- `PARSE-FAILED` withheld the byte comparison. The likeliest cause of an unparseable version
  is upstream restructuring the spec, so the content has probably moved too; reporting only
  "no version line matched" buried the bigger fact. It now states whether the bytes changed
  against the watermark as well.
- `HASH-FAILED` has its own exit (11) rather than sharing 1 with `FETCH-FAILED`, and the
  `SKILL.md` status table now lists every status the script can emit - it was missing
  `HASH-FAILED` entirely, so an agent reading the table would not have recognised it.
- `--help` reads to the first blank line instead of a hardcoded line range, so editing the
  header can no longer truncate the help or spill code into it.

## [0.4.0] - 2026-08-20

Audited against the Claude Code plugin reference; this release is that audit's outcome.

### Added
- **Brain repo** plugin option, prompted when the plugin is enabled, so the bundle location
  no longer has to be an exported variable. Resolution order is exported `BRAIN_REPO`, then
  the option, then `$HOME/dev/myMemory` - existing setups are unaffected. The option does
  not reach the scheduled routines, which run outside the plugin.
- `allowed-tools` on the five brain skills, scoped to the exact bundled-script commands each
  one runs, so an unattended routine cannot stall on a permission prompt.
- `homepage`, `repository` and `$schema` in `plugin.json`.
- This changelog.
- The SessionStart hook now inlines the writing-register preferences from the bundle: the
  `## Preference` section of every `preferences/` note tagged both `communication` and
  `ai-tooling`. Those rules govern every sentence an agent produces, and both brain sensors
  are keyed to named entities - the recall trigger to factual claims about a repo, project,
  person, tool or quest, the prompt hook to entity slugs in the message - so an agent's own
  prose style could never trigger a lookup for them. Emitted from the bundle rather than
  copied into the hook so the two cannot drift, selected by tag so a renamed or added note
  is picked up without editing the hook, capped at 80 lines with any truncation stated in
  the output, and silent when no note matches.

### Changed
- Skills now reference bundled scripts through `${CLAUDE_SKILL_DIR}` and
  `${CLAUDE_PLUGIN_ROOT}` instead of paths relative to the bundle repo. The old paths only
  resolved when the bundle repo also hosted the plugin, so every script invocation was
  broken for anyone who installed the plugin normally.
- `CLAUDE.md` is now `ARCHITECTURE.md`. A plugin-root `CLAUDE.md` is not loaded as context
  for plugin users, so the name implied something untrue; a thin `CLAUDE.md` imports it to
  keep the notes loading for people working on the plugin in this repo.

### Removed
- The `skills: ["./skills/"]` declaration. `skills/` is always scanned, so it did nothing.

## [0.3.0] - 2026-08-19

### Added
- `daily-brain-sweep` and `weekly-brain-validity` routine prompts, and an offer to install
  them from `brain-init`.

### Fixed
- `brain-validity` audits `Serves:` links on wins.
- `brain-backfill` scopes extraction to the chosen source and requires evidence quotes.
- `BACKFILL_MODEL` and `BACKFILL_EFFORT` made configurable.

## [0.2.0] - 2026-08-18

### Added
- First standalone release: the machinery split out of the private bundle repo into a
  plugin plus marketplace, with `brain-init` and `brain-backfill` so a newcomer can create
  and cold-start a bundle. The 0.1.x versions predate this repo and were never released
  from it.
