#!/usr/bin/env bash
# Build the full backfill worklist. No watermark, no cap - the opposite of brain-sweep.
# Usage: discover-all.sh [source-dir]   (default: ~/.claude/projects)
set -euo pipefail

SRC="${1:-$HOME/.claude/projects}"
BRAIN_REPO="${BRAIN_REPO:-$HOME/dev/myMemory}"

if [ ! -d "$SRC" ]; then
  printf '{"source":"%s","exists":false,"count":0,"items":[]}\n' "$SRC"
  exit 0
fi

# Exclude the bundle repo's own sessions (self-referential loop) the way sweep does:
# Claude Code encodes the project path into the directory name with / -> -
SELF_SLUG="$(printf '%s' "$BRAIN_REPO" | sed 's|/|-|g')"

find "$SRC" -type f \( -name '*.jsonl' -o -name '*.json' -o -name '*.md' \) 2>/dev/null \
| grep -v -- "$SELF_SLUG" \
| grep -vE '(subagent|workflow|agent-[0-9a-f]{6,})' \
| while IFS= read -r f; do
    # oldest first: backfill reads history forwards so later facts supersede earlier ones
    printf '%s\t%s\n' "$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f")" "$f"
  done \
| sort -n \
| awk -F'\t' -v src="$SRC" '
    BEGIN { printf "{\"source\":\"%s\",\"exists\":true,\"items\":[", src; n=0 }
    {
      gsub(/"/,"\\\"",$2)
      if (n++) printf ","
      printf "\n  {\"id\":\"%06d\",\"path\":\"%s\",\"mtime\":%s,\"status\":\"pending\"}", n, $2, $1
    }
    END { printf "\n ],\"count\":%d}\n", n }
  '
