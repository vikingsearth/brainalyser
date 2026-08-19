# Skill Spec: brain-validity

## Identity

- **Name**: brain-validity
- **Purpose**: utility
- **Complexity**: simple
- **Description**: Brain validity audit - okf conformance, reality-drift checks against GitHub and the logs, plus a clustering gap-finder for missing links. Proposes only, never mutates; findings land as a checkbox report in `inbox/`. Runs from the weekly-brain-validity scheduled task or on demand.

## Behavior

- **Input**: none
- **Output**: `inbox/validity-report-<YYYY-MM-DD>.md` (repo root; the ONLY content write allowed besides the okf-spec watermark), committed and pushed, plus a short casual summary
- **Operations**: conformance (`okf_validate.py --strict`) -> reality-drift buckets (gh cross-checks, status coherence, note-vs-log contradiction, learning decay, index drift, stale concepts) -> clustering gap-finder (one subagent proposes cross-domain clusters, diffs them against the link layer: missing links / bridges / orphans, propose-only) -> okf spec watch -> checkbox report -> commit + push -> summary
- **External dependencies**: uv, git, the Agent tool (clustering subagent); gh optional (that bucket skips gracefully when auth fails). Repo root: `$BRAIN_REPO`, default `~/dev/myMemory`
- **Degradation**: gh unauthenticated -> note it and skip the GitHub bucket; everything else is local

## Deviations

- No skill-local scripts: the mechanical half is the vendored `validate` skill's `okf_validate.py` - wrapping it would duplicate logic for nothing. The judgment half (drift buckets) is agent work, not scriptable.
- The never-mutates guarantee is the core contract; it lives in SKILL.md as a hard rule and in the scheduled-task prompt as a one-line reminder. The okf-spec watermark (`.claude/state/okf-spec.sha`) is the single sanctioned exception.
- `disable-model-invocation: false` despite side effects (checklist says true for side-effect skills): the thin scheduled-task prompt invokes this skill via the model - setting true would break the routine. Deliberate.
