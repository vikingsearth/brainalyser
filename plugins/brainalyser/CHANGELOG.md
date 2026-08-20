# Changelog

All notable changes to the brainalyser plugin. Versions follow [semver](https://semver.org);
the plugin's `plugin.json` version is authoritative.

After upgrading, re-copy the routine prompts if this file says they changed - the copies in
`~/.claude/scheduled-tasks/` are snapshots and a plugin update does not refresh them. See
[routines/README.md](routines/README.md).

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
  and cold-start a bundle. Earlier versions were not distributed.
