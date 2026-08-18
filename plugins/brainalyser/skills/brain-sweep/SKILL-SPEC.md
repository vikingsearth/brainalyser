# Skill Spec: brain-sweep

## Identity

- **Name**: brain-sweep
- **Purpose**: utility
- **Complexity**: simple
- **Description**: Harvest durable facts from recent Claude sessions and auto-memory into the brain (OKF bundle) - the scheduled catch-all layer under in-session capture. Runs from the daily-brain-sweep scheduled task or on demand.

## Behavior

- **Input**: none (window comes from the watermark in `.claude/state/harvest-state.json`)
- **Output**: bundle concepts + log entries captured via the brain skill flow, okf validation, commits pushed, plus a short casual report (sessions scanned/skipped, candidates, concepts, log entries, dedup skips, inbox items, validation result, push status)
- **Operations**: watermark -> discover (`scripts/discover.sh` for local; ccd session-mgmt MCP for remote/archived) -> extract candidates -> dedup (Grep over `brain/`, logs included) -> capture via the `brain` skill -> validate -> commit + push -> watermark + report
- **External dependencies**: the `brain` skill (same repo), uv, git; ccd session-mgmt MCP optional with graceful fallback. Repo root: `$BRAIN_REPO`, default `~/dev/myMemory`
- **Degradation**: no session-mgmt MCP -> local-only discovery; the bundle is plain files, so capture never blocks on services

## Deviations

- `disable-model-invocation: false` despite side effects (checklist says true for side-effect skills): the thin scheduled-task prompt invokes this skill via the model - setting true would break the routine. Deliberate.

## Relationship to `brain`

Capture mechanics (routing, okf conventions, confidence thresholds, inbox rule) are NOT duplicated here - this skill orchestrates discovery/dedup/reporting and delegates each fact to the brain skill's capture flow. Scheduled-task prompt is a thin pointer to this skill.
