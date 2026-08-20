# Skill Spec: brain

## Identity

- **Name**: brain
- **Purpose**: utility
- **Complexity**: standard
- **Description**: Recall from and capture to the personal knowledge memory (the OKF bundle at `brain/` in myMemory). Use when the user says "remember/recall/what do I know about X", shares a durable fact worth keeping (person, project, quest update, learning, win, preference, decision, company knowledge), or asks to log something to the brain. Also invoked via /brain.

## Behavior

- **Input**: free-form - a question to recall against, or new info to capture (optionally `/brain <text>`)
- **Output format**: prose recall answers with concept-path sources; capture ends with a one-line receipt (paths written + log entries added)
- **Output structure**: single response; capture may touch several bundle files (concept + index + log)
- **Operations** (two modes):
  1. **recall** - progressive disclosure (root index -> domain index -> concept) + Grep over `brain/`; logs answer "what/when happened" questions
  2. **capture** - classify (routing rules in REFERENCE.md) -> write/update concept per okf conventions -> append dated log entry -> maintain the directory index -> below-0.5 confidence = `inbox/` (repo root) -> atomic conventional commits
- **External dependencies**: uv, git; vendored `okf`/`validate` skills as format authority. Repo root: `$BRAIN_REPO`, default `~/dev/myMemory`
- **Degradation**: none needed - the bundle is plain files; no services, no derived layers

## File Plan

- **references/**
  - `REFERENCE.md` - domain map, routing rules table (signal -> route -> operation), confidence thresholds, concept/log/index conventions
- **scripts/**: none - okf templates live in the plugin's `skills/okf/templates/`; validation is the vendored `validate` skill
- **assets/**: none

## Hooks (user settings.json, script in repo)

- **SessionStart**: runs `.claude/hooks/session-start.sh` -> announces the bundle + concept count, recall/capture guidance. Registered in `~/.claude/settings.json` so it fires in every project.
- Deliberately no Stop/UserPromptSubmit hooks - too noisy; revisit if capture keeps getting forgotten.

## History

- v0.1: Obsidian vault + typed frontmatter edges + falkordb derived index + brain MCP. Retired 2026-07-21.
- v0.2: OKF bundle - this spec.
