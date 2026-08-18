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
You extract durable facts from one work-session transcript.

A durable fact is still true and useful in six months: a person fact, a project or
workstream fact, a stated preference or convention, a decision and its reasoning, a
learning or caveat, a piece of company/domain knowledge.

NOT durable: what was done in this session, transient state, file contents, code,
anything you inferred rather than read, and anything that reads as chatter.

Return ONLY minified JSON:
{"facts":[{"text":"<one self-contained sentence>","kind":"person|project|preference|decision|learning|domain","confidence":"high|medium|low","evidence":"<short quote>"}]}

Rules: each fact stands alone with no reference to "this session" or "the above".
Prefer the user's own words. Return {"facts":[]} rather than padding. Be conservative -
a wrong fact in a knowledge base is worse than a missing one.
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
