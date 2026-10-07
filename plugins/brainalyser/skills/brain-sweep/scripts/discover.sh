#!/usr/bin/env bash
# Discover local harvest sources since the watermark: session transcripts + auto-memory.
# Transcripts are windowed on the timestamps INSIDE them, never on file mtime.
set -euo pipefail

show_help() {
  cat <<'EOF'
discover.sh - list local sweep sources active since the watermark.

Usage:
  bash discover.sh [--cap N]

Options:
  --cap N      Max transcripts to return, most recently active first (default 10
               - keeps a single sweep run bounded; the rest land in skipped_by_cap)

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
    (their content belongs to the parent session). A transcript is in the window
    when its NEWEST INTERNAL timestamp is at or after the watermark - a .jsonl is
    appended to on every resume, so its mtime records the last touch rather than
    the work. For a one-sided "since" window mtime only ever over-includes (a
    file's mtime is never earlier than its last event), and it over-includes
    badly: it re-lists months-old sessions that something merely reopened, and
    the cap then gets spent on them. Sorting uses the same stamp.
  - Auto-memory: ~/.claude/projects/*/memory/*.md, excluding MEMORY.md and
    myMemory's own project memory (same no-self-loop rule as transcripts). These
    stay on mtime deliberately: a memory file is rewritten in place rather than
    appended to on resume, so its mtime IS its activity date.

Output: JSON on stdout -
  {watermark, window, transcripts[], skipped_by_cap[], memory_files[],
   summary{}, warnings[]}
Diagnostics go to stderr. Exit 0 even when nothing is found.

Equivalent inline fallback if this script fails. Window transcripts on the dates
INSIDE them - grep every UTC date from the watermark's day to today, which is the
cheap pre-filter (~0.6s over 743 files) - and do NOT reach for `find -newer`, which
answers the mtime question this script exists to avoid. It matches on whole dates,
so it is slightly over-inclusive on the watermark's own day; over-inclusive is the
right way for a fallback to be wrong, since the sweep dedups anyway:
  WM=$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/dev/myMemory/.claude/state/harvest-state.json")))["last_run"])')
  DATES=$(python3 -c 'import datetime,sys;d=datetime.date.fromisoformat(sys.argv[1][:10]);t=datetime.datetime.now(datetime.timezone.utc).date();print("|".join(str(d+datetime.timedelta(n)) for n in range((t-d).days+1)))' "$WM")
  grep -rlE "\"timestamp\":\"($DATES)T" ~/.claude/projects --include='*.jsonl' | grep -v myMemory | grep -v /subagents/
  touch -d "$WM" /tmp/wm   # auto-memory stays on mtime, so it does need the stamp file
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
# there against each transcript's newest INTERNAL timestamp: `find -newermt` is not
# portable enough to trust with an ISO stamp (BSD find rejects a trailing Z), and it
# would answer the mtime question anyway, which is the wrong one.
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
  # every candidate, unfiltered; the python step applies the cutoff and sorts
  TRANSCRIPTS=$(find "$PROJECTS" -name "*.jsonl" -not -path "*myMemory*" -not -path "*/subagents/*" 2>/dev/null || true)
  MEMORY=$(find "$PROJECTS" -depth 2 -maxdepth 2 -name memory -type d -not -path "*myMemory*" 2>/dev/null \
    | while read -r d; do find "$d" -name "*.md" -not -name "MEMORY.md" 2>/dev/null; done || true)
fi

TRANSCRIPTS="$TRANSCRIPTS" MEMORY="$MEMORY" WATERMARK_TS="$WATERMARK_TS" WINDOW="$WINDOW" CAP="$CAP" \
CUTOFF="$CUTOFF" WARNINGS_JOINED="$(printf '%s\n' "${WARNINGS[@]:-}")" python3 <<'EOF'
import datetime, json, os, re

cutoff = float(os.environ["CUTOFF"])
mtime = lambda p: os.path.getmtime(p) if os.path.exists(p) else 0


def since_cutoff(paths, when):
    # Score each path once: `when` reads the file and records fallbacks.
    scored = [(when(p), p) for p in paths]
    # >= not > : a file active in the same second as the watermark stays in the window.
    # Re-reading one is free (the sweep dedups); dropping one loses it for good.
    return [p for t, p in sorted(scored, reverse=True) if t >= cutoff]


TS_RE = re.compile(rb'"timestamp":"([^"]{19,40})"')
TAIL_BYTES = 262144  # 256 KiB - enough to hold the last events of any real transcript


def _epoch(raw):
    try:
        ts = datetime.datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return None
    if ts.tzinfo is None:  # a naive stamp in a UTC-stamped file - read it as UTC
        ts = ts.replace(tzinfo=datetime.timezone.utc)
    return ts.timestamp()


def _newest_in(blob):
    best = None
    for m in TS_RE.finditer(blob):
        e = _epoch(m.group(1).decode("ascii", "replace"))
        if e is not None and (best is None or e > best):
            best = e
    return best


def last_activity(path):
    """Epoch of the newest event INSIDE a transcript, or None if it carries none.

    A .jsonl is appended to on every resume, so its mtime is the last touch, not the
    work: an mtime window re-lists months-old sessions that were merely reopened.
    The payload carries its own timestamps, so those are the evidence and mtime is
    at most a hint.

    Only the newest stamp matters here. The window asks "does this session have any
    event at or after the cutoff", which is exactly max(timestamps) >= cutoff - the
    per-day attribution the same rule needs elsewhere does not apply to a watermark.

    Reading the tail makes it O(1) in file size rather than O(bytes): JSONL is
    append-ordered, so the newest events sit at the end. A full scan runs only when
    the tail carried no stamp at all (one oversized trailing record).
    """
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as fh:
            if size > TAIL_BYTES:
                fh.seek(size - TAIL_BYTES)
            newest = _newest_in(fh.read())
            if newest is None and size > TAIL_BYTES:
                fh.seek(0)
                newest = _newest_in(fh.read())
        return newest
    except OSError:
        return None


undated = []


def transcript_activity(path):
    # Fall back to mtime rather than dropping an unparseable transcript: a silent
    # drop is the failure this whole change exists to remove. The fallback is
    # reported, so a systemic format change shows up instead of quietly degrading.
    stamp = last_activity(path)
    if stamp is None:
        undated.append(path)
        return mtime(path)
    return stamp


lines = lambda v: [l for l in os.environ[v].splitlines() if l.strip()]
transcripts = since_cutoff(lines("TRANSCRIPTS"), transcript_activity)
# Auto-memory stays on mtime deliberately - a memory file is rewritten in place, not
# appended to on resume, so its mtime IS its activity date.
memory = since_cutoff(lines("MEMORY"), mtime)
warnings = lines("WARNINGS_JOINED")
if undated:
    warnings.append(
        f"{len(undated)} transcript(s) carried no parseable internal timestamp - "
        f"fell back to mtime for those (first: {undated[0]})"
    )
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
