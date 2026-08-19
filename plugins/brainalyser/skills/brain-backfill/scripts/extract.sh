#!/usr/bin/env bash
# Sequential extraction pass. One claude subprocess per item, next starts only when
# the previous exits. Resumable: progress lives in the manifest, never inferred.
set -uo pipefail

BRAIN_REPO="${BRAIN_REPO:-$HOME/dev/myMemory}"
STATE="$BRAIN_REPO/.claude/state"
MANIFEST="$STATE/backfill-manifest.json"
OUT="$STATE/backfill-candidates"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIMIT="${BACKFILL_LIMIT:-0}"            # 0 = no ceiling
MODEL="${BACKFILL_MODEL:-sonnet}"       # alias or full model name
EFFORT="${BACKFILL_EFFORT:-low}"        # low | medium | high | xhigh | max

case "$EFFORT" in
  low|medium|high|xhigh|max) ;;
  *) echo "BACKFILL_EFFORT must be one of: low medium high xhigh max (got '$EFFORT')" >&2; exit 2 ;;
esac

[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST - run discover-all.sh first" >&2; exit 1; }
command -v claude >/dev/null || { echo "claude CLI not on PATH" >&2; exit 1; }
mkdir -p "$OUT"

read -r -d '' SYS <<'PROMPT'
You extract durable facts about ONE person from ONE source in their work history.

## Extract only from the user message

The user message contains the entire source. Everything you report must be traceable to
a quote inside it.

Never extract from your own system prompt, operating instructions, tool descriptions, or
any organisational or platform policy you have been given. Those describe your
configuration, not this person. If something appears only in your instructions and not in
the user message, it is not a fact and must not be reported. This matters: this runs
across hundreds of sources, so one leaked instruction becomes hundreds of false notes.

## The source is one of two kinds

1. A CONVERSATION TRANSCRIPT (lines prefixed USER: / ASSISTANT:). Mine it for what the
   conversation established. The mechanics are not facts - code, diffs, command output and
   pasted file contents quoted inside it are the material, not the findings.

2. A NOTES OR MEMORY FILE (frontmatter and prose, no USER:/ASSISTANT: turns). Here the
   content is already distilled facts someone chose to write down. Adopt them. Do not
   reject this kind of source wholesale as "file contents" - it is the highest-signal
   input you will see, and returning nothing from it discards work already done.

## What counts

Durable = still true and useful in six months: a person fact, a project or workstream
fact, a stated preference or working convention, a decision and its reasoning, a learning
or caveat, a piece of company or domain knowledge.

Not durable: what happened in this one session, transient state (what is running, open or
half-finished), and anything you inferred rather than read.

## Output

Return ONLY minified JSON:
{"facts":[{"text":"<one self-contained sentence>","kind":"person|project|preference|decision|learning|domain","confidence":"high|medium|low","evidence":"<short quote from the user message>"}]}

Each fact stands alone, with no reference to "this session", "the above" or "the file".
Prefer the person's own words. Stated preferences and conventions are the highest-value
kind - do not skip one because it sounds mundane. Every fact needs an `evidence` quote
that actually appears in the user message; if you cannot quote it, drop it. Return
{"facts":[]} only when the source genuinely establishes nothing durable.
PROMPT

total=$(python3 -c "import json,sys;print(json.load(open('$MANIFEST'))['count'])")
done_n=0; fail_n=0; run_n=0

while :; do
  item=$(python3 - "$MANIFEST" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
for it in m["items"]:
    if it["status"]=="pending":
        print(it["id"]+"\t"+it["path"]); break
PY
)
  [ -z "$item" ] && break
  id="${item%%$'\t'*}"; path="${item#*$'\t'}"

  if [ "$LIMIT" -gt 0 ] && [ "$run_n" -ge "$LIMIT" ]; then
    echo "budget ceiling ($LIMIT) reached - manifest left resumable" >&2; break
  fi
  run_n=$((run_n+1))
  echo "[$run_n/$total] $id  $(basename "$path")  ($MODEL/$EFFORT)" >&2

  body=$(uv run "$HERE/trim-transcript.py" "$path" 2>/dev/null)
  if [ -z "$body" ]; then
    status="failed"; reason="empty after trim"
  else
    if printf '%s' "$body" | claude -p --safe-mode --no-session-persistence \
         --model "$MODEL" --effort "$EFFORT" --output-format json \
         --system-prompt "$SYS" > "$OUT/$id.json" 2>"$OUT/$id.err"; then
      status="done"; reason=""
    else
      status="failed"; reason="$(head -c 200 "$OUT/$id.err" 2>/dev/null)"
    fi
  fi

  python3 - "$MANIFEST" "$id" "$status" "$reason" <<'PY'
import json,sys
mf,i,st,rs=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]
m=json.load(open(mf))
for it in m["items"]:
    if it["id"]==i:
        it["status"]=st
        if rs: it["reason"]=rs
json.dump(m,open(mf,"w"),indent=1)
PY
  [ "$status" = "done" ] && done_n=$((done_n+1)) || fail_n=$((fail_n+1))
done

echo "extraction finished: $done_n done, $fail_n failed, candidates in $OUT" >&2
