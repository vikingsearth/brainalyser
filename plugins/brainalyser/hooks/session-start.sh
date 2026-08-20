#!/usr/bin/env bash
# SessionStart hook: announce the knowledge bundle and state the recall trigger.
# Shipped by the brainalyser plugin; registered via hooks/hooks.json.
#
# The bundle is DATA and lives outside this plugin - a plugin directory is
# install-managed and would be clobbered on update, so the bundle stays a normal
# git clone. Located via BRAIN_REPO, defaulting to the conventional checkout.
# Must be fast and never fail the session.
set -uo pipefail

REPO="${BRAIN_REPO:-${CLAUDE_PLUGIN_OPTION_BRAIN_REPO:-$HOME/dev/myMemory}}"
BUNDLE="$REPO/brain"

# Guard: never resolve to the marketplace's own cached copy. The plugin is
# hosted in the same repo as the bundle, so installing it clones brain/ into the
# plugin cache too. That copy is refreshed from git on every plugin update -
# capturing into it would silently discard notes.
case "$REPO" in
  */.claude/plugins/*)
    cat <<EOF
Brain memory: BRAIN_REPO points inside the plugin cache ($REPO), which is
install-managed and gets overwritten on plugin update. Point BRAIN_REPO at your
working clone of the bundle instead, then restart the session.
EOF
    exit 0
    ;;
esac

# Not-yet-cloned case: the whole point of the plugin is a clean machine, so say
# what to do rather than announcing an empty bundle at a path that isn't there.
if [ ! -d "$BUNDLE" ]; then
  cat <<EOF
Brain memory is NOT available: no bundle at $BUNDLE.
- The brainalyser plugin ships the machinery only; the knowledge bundle is a
  separate private git repo.
- Clone it, then either place it at \$HOME/dev/myMemory or export BRAIN_REPO=<path>
  so this hook can find it. Until then, brain recall and capture are unavailable -
  say so rather than answering from memory about the user's repos or projects.
EOF
  exit 0
fi

COUNT=$(find "$BUNDLE" -name '*.md' ! -name 'index.md' ! -name 'log.md' 2>/dev/null | wc -l | tr -d ' ')

# Existing win areas, read off disk rather than hardcoded - a new area dir shows
# up here the moment it exists, and a renamed one can't go stale.
WINS_DIR="$BUNDLE/performance/wins"
AREAS=$(find "$WINS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort | paste -sd, - | sed 's/,/, /g')

cat <<EOF
Brain memory is available: an OKF knowledge bundle at $BUNDLE (${COUNT:-0} concepts).
- Recall: progressive disclosure - read $BUNDLE/index.md, then the domain index, then the concept; or grep the bundle.
- TRIGGER (mechanical, not a judgement call): grep the bundle before ANY factual claim about a named repo, project, person, tool or quest of the user's - including asides, parentheticals, closing summaries and hedges ("likely tied to...", "probably still needed..."). A hedge is NOT an exemption; hedged claims still drive decisions. If you are naming one of their things, you owe it a grep.
- Already having an answer from the filesystem, git or a local clone is NOT a reason to skip the brain - it is the usual reason the answer is stale (a local clone can be hundreds of commits behind; a repo on disk says nothing about whether the work is active, paused or abandoned).
- Capture durable facts (person facts, quest updates, learnings, wins, preferences, tribal knowledge) via the brain skill; record changes in the nearest log.md.
- Logging wins: when the user lands a win (fix, ship, solved bug, review cleared, unblocked the team, growth milestone, communication/leadership win), append it to the win stream at $WINS_DIR/<area>/log.md - existing areas: ${AREAS:-none yet}. Create a new area dir only when one genuinely fits better. Entry format, under a \`## YYYY-MM-DD\` heading, newest date first:
      * **small|medium|large**: one-liner. Why: why it mattered. Serves: [<name>](/quests/<slug>/quest.md)
  All three parts are required, \`Serves:\` included - it is the only thing tying a win to the quest, project or goal it advanced, and nothing else in the bundle makes that join (the directory a win lives under carries its *area*, never its workstream). Link the quest if one covers the work, else the project, else the goal; more than one link is fine. When the win genuinely served nothing tracked, write \`Serves: none\` - explicitly, so a recorded judgement is never mistaken for a forgotten field.
  Sizes track the **outcome**, not the effort: small = a fix landed / review cleared / annoyance killed; medium = something others now rely on (a feature shipped, a gnarly bug closed, a doc or tool the team uses); large = promo-case material - the outcome changed how the team or the estate works, or is the kind of thing a career conversation gets argued from. A large win owes its own concept note next to the log (see $WINS_DIR/index.md), but that note is never a reason to log it smaller: nominate it the same day as \`**large** (note owed)\` and write the note when there is room. Unsure between two sizes -> pick the smaller, but size on what the outcome *did*, not on how hard it felt. Don't ask permission for a clear win, just mention you logged it. Never edit or delete existing entries unasked. A win entry records the win, not agent process notes - keep meta-commentary out of it.
EOF
exit 0
