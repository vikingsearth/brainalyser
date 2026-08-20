#!/usr/bin/env bash
# Discover local harvest sources since the watermark: session transcripts + auto-memory.
set -euo pipefail

show_help() {
  cat <<'EOF'
discover.sh - list local sweep sources modified since the watermark.

Usage:
  bash discover.sh [--cap N]

Options:
  --cap N      Max transcripts to return, newest first (default 10 - keeps a
               single sweep run bounded; the rest land in skipped_by_cap)

Environment:
  BRAIN_REPO   Repo root (default: ~/dev/myMemory)

Behavior:
  - Watermark: the last_run value inside
    $BRAIN_REPO/.claude/state/harvest-state.json - never the file's own mtime,
    which drifts from last_run and would silently shrink the window. Missing
    file, or an absent/unparseable last_run => fall back to a last-24h window
    (a warning is included in the output). The reported watermark is the stamp
    actually applied, normalised to UTC, and null on either fallback.
  - Transcripts: ~/.claude/projects/**/*.jsonl, excluding myMemory's own
    sessions (no self-referential loops) and subagent/workflow transcripts
    (their content belongs to the parent session).
  - Auto-memory: ~/.claude/projects/*/memory/*.md, excluding MEMORY.md and
    myMemory's own project memory (same no-self-loop rule as transcripts).

Output: JSON on stdout -
  {watermark, window, transcripts[], skipped_by_cap[], memory_files[],
   summary{}, warnings[]}
Diagnostics go to stderr. Exit 0 even when nothing is found.

Equivalent inline fallback if this script fails. Stamp a reference file at last_run
and compare against that - do NOT pass the ISO stamp to find -newermt, which BSD
find rejects, and do NOT use -newer on the state file itself (that is the mtime bug
this script exists to avoid):
  WM=$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/dev/myMemory/.claude/state/harvest-state.json")))["last_run"])')
  touch -d "$WM" /tmp/wm
  find ~/.claude/projects -name "*.jsonl" -newer /tmp/wm -not -path "*myMemory*" -not -path "*/subagents/*"
  find ~/.claude/projects/*/memory -name "*.md" -not -name "MEMORY.md" -not -path "*myMemory*" -newer /tmp/wm
EOF
}

CAP=10
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help) show_help; exit 0 ;;
    --cap) [[ $# -ge 2 ]] || { echo "error: --cap needs a value (see --help)" >&2; exit 1; }; CAP="$2"; shift 2 ;;
    *) echo "error: unknown argument '$1' (see --help)" >&2; exit 1 ;;
  esac
done
[[ "$CAP" =~ ^[0-9]+$ ]] || { echo "error: --cap needs a non-negative integer, got '$CAP' (see --help)" >&2; exit 1; }

REPO="${BRAIN_REPO:-${CLAUDE_PLUGIN_OPTION_BRAIN_REPO:-$HOME/dev/myMemory}}"
WATERMARK="$REPO/.claude/state/harvest-state.json"
PROJECTS="$HOME/.claude/projects"

# Resolve the window. The watermark is the recorded last_run value, NOT the state
# file's mtime - the two drift (the file is rewritten at the end of a sweep), and an
# mtime newer than last_run silently narrows the window past sessions the sweep is
# meant to see. The cutoff is handed to the python step as an epoch and compared
# against each candidate's mtime there: `find -newermt` is not portable enough to
# trust with an ISO stamp (BSD find rejects a trailing Z outright).
#
# '|' as the field separator, not a tab: tab is IFS whitespace, so `read` would
# collapse the empty stamp field on the fallback paths and shift the epoch left.
IFS='|' read -r WM_STATUS WATERMARK_TS CUTOFF < <(python3 - "$WATERMARK" <<'PY'
import datetime, json, sys

def parse(path):
    raw = (json.load(open(path)).get("last_run") or "").strip()
    ts = datetime.datetime.fromisoformat(raw.replace("Z", "+00:00"))
    if ts.tzinfo is None:  # naive value - the writer meant local time
        ts = ts.astimezone()
    return ts.astimezone(datetime.timezone.utc)

fallback = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1)
try:
    open(sys.argv[1]).close()
except OSError:
    print("no-file", "", fallback.timestamp(), sep="|")
else:
    try:
        ts = parse(sys.argv[1])
    except Exception:
        print("no-last-run", "", fallback.timestamp(), sep="|")
    else:
        print("ok", ts.strftime("%Y-%m-%dT%H:%M:%SZ"), ts.timestamp(), sep="|")
PY
)

# Every branch above emits a cutoff; an empty or non-numeric one means the parser
# itself broke, which is a bug rather than an empty sweep - say so instead of letting
# the step below die on float('').
[[ "$CUTOFF" =~ ^[0-9]+(\.[0-9]+)?$ ]] || {
  echo "error: could not resolve a cutoff timestamp (watermark parser returned status='$WM_STATUS' cutoff='$CUTOFF')" >&2
  exit 1
}

WARNINGS=()
case "$WM_STATUS" in
  ok) WINDOW="since-watermark" ;;
  no-last-run)
    WINDOW="last-24h"
    WARNINGS+=("watermark at $WATERMARK has no readable last_run - using last-24h window") ;;
  *)
    WINDOW="last-24h"
    WARNINGS+=("watermark file missing at $WATERMARK - using last-24h window") ;;
esac

if [[ ! -d "$PROJECTS" ]]; then
  WARNINGS+=("$PROJECTS does not exist - no local sources")
  TRANSCRIPTS=""
  MEMORY=""
else
  # every candidate, unfiltered; the python step applies the cutoff and sorts by mtime
  TRANSCRIPTS=$(find "$PROJECTS" -name "*.jsonl" -not -path "*myMemory*" -not -path "*/subagents/*" 2>/dev/null || true)
  MEMORY=$(find "$PROJECTS" -depth 2 -maxdepth 2 -name memory -type d -not -path "*myMemory*" 2>/dev/null \
    | while read -r d; do find "$d" -name "*.md" -not -name "MEMORY.md" 2>/dev/null; done || true)
fi

TRANSCRIPTS="$TRANSCRIPTS" MEMORY="$MEMORY" WATERMARK_TS="$WATERMARK_TS" WINDOW="$WINDOW" CAP="$CAP" \
CUTOFF="$CUTOFF" WARNINGS_JOINED="$(printf '%s\n' "${WARNINGS[@]:-}")" python3 <<'EOF'
import json, os

cutoff = float(os.environ["CUTOFF"])
mtime = lambda p: os.path.getmtime(p) if os.path.exists(p) else 0
# >= not > : a file written in the same second as the watermark stays in the window.
# Re-reading one is free (the sweep dedups); dropping one loses it for good.
since_cutoff = lambda paths: sorted((p for p in paths if mtime(p) >= cutoff), key=mtime, reverse=True)

lines = lambda v: [l for l in os.environ[v].splitlines() if l.strip()]
transcripts, memory = since_cutoff(lines("TRANSCRIPTS")), since_cutoff(lines("MEMORY"))
warnings = lines("WARNINGS_JOINED")
cap = int(os.environ["CAP"])
kept, skipped = transcripts[:cap], transcripts[cap:]

print(json.dumps({
    "watermark": os.environ["WATERMARK_TS"] or None,
    "window": os.environ["WINDOW"],
    "transcripts": kept,
    "skipped_by_cap": skipped,
    "memory_files": memory,
    "summary": {"transcripts": len(kept), "skipped_by_cap": len(skipped), "memory_files": len(memory)},
    "warnings": warnings,
}, indent=2))
EOF
