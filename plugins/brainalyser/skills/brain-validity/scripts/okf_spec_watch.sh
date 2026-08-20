#!/usr/bin/env bash
# OKF spec watch: is the upstream spec still the one this bundle was built against?
#
# Why this is a script and not a prose instruction: the obvious hand-rolled
# spelling is wrong. `SPEC=$(curl ...)` strips trailing newlines - command
# substitution always does - so `printf '%s' "$SPEC" | shasum` hashes one byte
# fewer than the file and reports a spec change on every single run. A false
# "the spec moved" is expensive: it is the one finding in the weekly audit that
# is meant to stop everything and pull a human in.
#
# So: fetch to a file, hash the file, never pipe the body through the shell.
#
# Usage:  okf_spec_watch.sh [--update] [--repo <path>]
#   --update   rewrite the watermark to what was just fetched (do this only
#              after the change has been reported)
#   --repo     bundle repo root; default $BRAIN_REPO, else $HOME/dev/myMemory
#
# Exit: 0 unchanged | 10 CHANGED (report it) | 20 first run (no watermark)
#       1 fetch failed | 2 bad usage

set -uo pipefail

URL="https://raw.githubusercontent.com/GoogleCloudPlatform/knowledge-catalog/main/okf/SPEC.md"
REPO="${BRAIN_REPO:-$HOME/dev/myMemory}"
UPDATE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --update) UPDATE=1; shift ;;
    --repo)   REPO="${2:?--repo needs a path}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

WATERMARK="$REPO/.claude/state/okf-spec.sha"
TMP="$(mktemp -t okf-spec)" || { echo "cannot mktemp" >&2; exit 1; }
trap 'rm -f "$TMP"' EXIT

# -f so a 404 is a failure rather than an HTML body we would happily hash
# deliberately NOT -f: with -f curl exits non-zero and the real status is lost,
# so a 404 would report as a generic failure. Take the code and judge it here.
CODE="$(curl -sSL --max-time 30 -w '%{http_code}' -o "$TMP" "$URL" 2>/dev/null)" || CODE="000"
BYTES=$(wc -c < "$TMP" | tr -d ' ')

if [ "$CODE" != "200" ] || [ "$BYTES" -lt 1000 ]; then
  echo "status: FETCH-FAILED"
  echo "  url        : $URL"
  echo "  http        : $CODE"
  echo "  bytes       : $BYTES"
  echo "  note        : a moved or 404'd spec is itself a finding - report it, do not treat as unchanged"
  exit 1
fi

NEW_SHA="$(shasum -a 256 "$TMP" | cut -d' ' -f1)"
NEW_VER="$(grep -oiEm1 '\*\*version[ :]+[0-9]+\.[0-9]+\*\*|okf_version:[ ]*.?[0-9]+\.[0-9]+' "$TMP" \
            | grep -oE '[0-9]+\.[0-9]+' | head -1)"
NEW_VER="${NEW_VER:-unknown}"

echo "  url         : $URL"
echo "  bytes       : $BYTES"
echo "  fetched sha : $NEW_SHA"
echo "  fetched ver : $NEW_VER"

if [ ! -f "$WATERMARK" ]; then
  echo "status: FIRST-RUN (no watermark at $WATERMARK)"
  RC=20
else
  OLD_SHA="$(grep -m1 'sha256' "$WATERMARK" | awk '{print $2}')"
  OLD_VER="$(grep -m1 '^version' "$WATERMARK" | awk '{print $2}')"
  echo "  stored  sha : $OLD_SHA"
  echo "  stored  ver : $OLD_VER"
  if [ "$NEW_SHA" = "$OLD_SHA" ]; then
    echo "status: UNCHANGED (okf spec unchanged, v$OLD_VER)"
    RC=0
  else
    echo "status: CHANGED"
    echo "  version     : $OLD_VER -> $NEW_VER"
    [ "$OLD_VER" = "$NEW_VER" ] && echo "  note        : same version line, different bytes - an in-place spec edit, not a release"
    echo "  next        : summarise what moved (do NOT adapt anything), then re-run with --update"
    RC=10
  fi
fi

if [ "$UPDATE" -eq 1 ]; then
  # read `seeded` out FIRST: the `>` below truncates the file before any command
  # substitution inside the block runs, which silently blanked it when this was
  # written inline. Caught by a test that asserted the field survived an update.
  SEEDED="$(grep -m1 '^seeded' "$WATERMARK" 2>/dev/null | awk '{print $2}')"
  SEEDED="${SEEDED:-$(date +%F)}"
  mkdir -p "$(dirname "$WATERMARK")"
  { echo "sha256: $NEW_SHA"
    echo "version: $NEW_VER"
    echo "seeded: $SEEDED"
    echo "updated: $(date +%F)"
  } > "$WATERMARK"
  echo "  watermark   : updated"
fi
exit $RC
