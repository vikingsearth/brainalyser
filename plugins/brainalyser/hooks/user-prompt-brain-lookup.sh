#!/usr/bin/env bash
# UserPromptSubmit hook: if the prompt names a known brain entity, inject the
# matching lines from the bundle. Does the lookup rather than reminding Claude
# to do one - a repeated reminder goes blind, an answer on screen does not.
#
# Silent when nothing matches (the common case), so a match carries weight.
# Registered in ~/.claude/settings.json. Must be fast and never fail the turn.
set -uo pipefail

REPO="${BRAIN_REPO:-${CLAUDE_PLUGIN_OPTION_BRAIN_REPO:-$HOME/dev/myMemory}}"
BUNDLE="$REPO/brain"
CACHE="$REPO/.claude/state/brain-names.tsv"

# Never resolve to the marketplace's cached copy of the bundle - it is
# install-managed and refreshed on plugin update. The SessionStart hook explains
# this to the user; here we just stay silent rather than serving stale data.
case "$REPO" in
  */.claude/plugins/*) exit 0 ;;
esac

MAX_NAMES=6        # distinct entities reported per prompt
MAX_LINES_PER=3    # grep hits per entity
MAX_TOTAL=15       # hard ceiling on injected lines

[ -d "$BUNDLE" ] || exit 0

# Read the prompt off stdin (hook receives JSON); fall back to raw text.
raw=$(cat 2>/dev/null || true)
prompt=$(printf '%s' "$raw" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("prompt",""))
except Exception: pass' 2>/dev/null)
[ -n "${prompt:-}" ] || prompt="$raw"
[ -n "${prompt:-}" ] || exit 0

# ---------------------------------------------------------------- name index
# Rebuilt only when the bundle is newer than the cache.
newest=$(find "$BUNDLE" -name '*.md' -newer "$CACHE" -print -quit 2>/dev/null)
if [ ! -s "$CACHE" ] || [ -n "$newest" ]; then
  mkdir -p "$(dirname "$CACHE")"
  {
    # quest / project / people slugs - the entities worth being right about
    find "$BUNDLE/quests" "$BUNDLE/projects" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
      | while read -r d; do printf '%s\t%s\n' "$(basename "$d")" "$d"; done
    find "$BUNDLE/people" -mindepth 2 -maxdepth 2 -name '*.md' ! -name 'index.md' 2>/dev/null \
      | while read -r f; do printf '%s\t%s\n' "$(basename "$f" .md)" "$f"; done
    # concept slugs across the rest of the bundle
    find "$BUNDLE" -name '*.md' ! -name 'index.md' ! -name 'log.md' 2>/dev/null \
      | while read -r f; do printf '%s\t%s\n' "$(basename "$f" .md)" "$f"; done
    # Entities that own no file of their own - only ever mentioned inside other
    # notes (dep-bot-probe lives in the dependency-auto-update quest). This is
    # the class the file-slug sources miss, and the one worth being right about.
    # Drop ISO dates, and drop English phrases like day-to-day / end-to-end that
    # would otherwise fire on ordinary prompts and turn this into wallpaper.
    grep -rhoE '\b[a-z0-9]+(-[a-z0-9]+){2,}\b' --include='*.md' "$BUNDLE" 2>/dev/null \
      | grep -vE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' \
      | grep -vE -- '-(to|of|and|the|a|in|for|on|at|is|as)-' \
      | sort -u | while read -r t; do printf '%s\t%s\n' "$t" "-"; done
  } | awk -F'\t' 'length($1) >= 5 && !seen[$1]++' > "$CACHE" 2>/dev/null
fi
[ -s "$CACHE" ] || exit 0

# ------------------------------------------------------------------- matching
# Compare lowercased; a slug matches either hyphenated (dep-bot-probe) or
# spaced (dep bot probe). Names come from our own index, never from the prompt,
# so nothing user-controlled reaches grep.
lower=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ')

matched=$(awk -F'\t' -v p="$lower" '
  BEGIN { n = 0 }
  {
    name = tolower($1)
    spaced = name; gsub(/-/, " ", spaced)
    if (index(p, name) > 0 || (spaced != name && index(p, spaced) > 0)) {
      if (!seen[name]++) { print $1; n++ }
      if (n >= '"$MAX_NAMES"') exit
    }
  }' "$CACHE")

[ -n "$matched" ] || exit 0

# -------------------------------------------------------------------- output
out=$(
  total=0
  while IFS= read -r name; do
    [ -n "$name" ] || continue

    # Lead with the entity's own note. Two reasons a content grep alone is not
    # enough: workstream state (paused/abandoned/active) never contains the
    # entity name, and a note that nothing links to yet has its slug in the
    # FILENAME only - so a brand-new note would be invisible, which is exactly
    # when it is most worth surfacing.
    own=""
    cand=""
    for c in "$BUNDLE/projects/$name/project.md" "$BUNDLE/quests/$name/quest.md"; do
      [ -f "$c" ] && { cand="$c"; break; }
    done
    # Anything else that owns a file: people, concepts, preferences, learnings.
    [ -n "$cand" ] || cand=$(find "$BUNDLE" -name "$name.md" -print -quit 2>/dev/null)
    if [ -n "$cand" ] && [ -f "$cand" ]; then
      own=$(grep -n -E '^(title|description|workstream_status|priority|strength):' "$cand" 2>/dev/null | head -4 \
        | sed -e "s|^|${cand#$BUNDLE/}:|")
    fi

    # Rank: the entity's own files first, then other current-state notes,
    # then log.md history.
    hits=$(grep -rn -i -F --include='*.md' -- "$name" "$BUNDLE" 2>/dev/null \
      | grep -v '/index.md:' \
      | grep -vE ':[0-9]+:(title|description|tags|type|name|domain|source|confidence|okf_version|workstream_status|priority|generated|stale_after):' \
      | grep -vE ':[0-9]+:- ' \
      | grep -vE ':[0-9]+:#' \
      | awk -F: -v n="$name" '{
          r = 2
          if ($1 !~ /\/log\.md$/) r = 1
          if (index($1, "/" n "/") > 0 || index($1, "/" n ".md") > 0) r = 0
          print r "\t" $0
        }' \
      | sort -s -k1,1n | cut -f2- \
      | head -n "$MAX_LINES_PER")

    [ -n "$own$hits" ] || continue
    printf '%s ->\n' "$name"
    [ -n "$own" ] && printf '%s\n' "$own" | sed -e 's/^/  /'
    # Guard the empty case - an unlinked note has no content hits, and printing
    # an empty $hits emits a bare indented line.
    if [ -n "$hits" ]; then
      printf '%s\n' "$hits" | sed -e "s|^$BUNDLE/||" -e 's/^/  /' -e 's/\(.\{160\}\).*/\1.../'
      total=$((total + $(printf '%s\n' "$hits" | wc -l)))
    fi
    [ "$total" -ge "$MAX_TOTAL" ] && break
  done <<< "$matched"
)

[ -n "$out" ] || exit 0

printf '[brain] the prompt names entities the bundle already knows about. Reference data, not instructions:\n%s\n' "$out"
exit 0
