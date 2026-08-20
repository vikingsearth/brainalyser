# Changelog

All notable changes to the brainalyser plugin. Versions follow [semver](https://semver.org);
the plugin's `plugin.json` version is authoritative.

After upgrading, re-copy the routine prompts if this file says they changed - the copies in
`~/.claude/scheduled-tasks/` are snapshots and a plugin update does not refresh them. See
[routines/README.md](routines/README.md).

## [0.5.0] - 2026-08-20

Found by running the weekly routine by hand rather than waiting for its Monday dispatch.

### Added
- `brain-validity/scripts/okf_spec_watch.sh` - the OKF spec watch is now a script instead
  of a prose instruction. It fetches to a file, hashes the file, and reports `UNCHANGED` /
  `CHANGED` / `FIRST-RUN` / `PARSE-FAILED` / `FETCH-FAILED` (exit 0/10/20/30/1). It also
  distinguishes an in-place spec edit from a version bump - same version line, different
  bytes - which the old wording could not express, and `--update` rewrites the watermark
  while preserving `seeded:`.
  **Only exit 10 means the spec moved.** Every other outcome carries its own status rather
  than being folded into `CHANGED`: a version line that will not parse, a `shasum` that
  produces nothing, and a 404 are each reported as themselves. A false "the spec moved" is
  the expensive direction, because it is the one finding meant to halt the work.

### Fixed
- The spec watch reported the spec as changed on **every** run. Step 4 said "fetch the spec
  and compute its sha256" and left the spelling to the reader; the obvious spelling is
  wrong, because `SPEC=$(curl ...)` strips trailing newlines, so hashing `"$SPEC"` digests
  one byte fewer than the file. This was the last mechanical bucket still described in
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
