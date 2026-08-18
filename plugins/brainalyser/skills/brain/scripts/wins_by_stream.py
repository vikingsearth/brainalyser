#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Roll the win stream up per quest, project, and goal - the win->workstream join.

Wins live in `performance/wins/<area>/log.md`, so the path a win sits under
records its AREA (engineering, leadership, ...) and says nothing about which
workstream it advanced. That join exists only in the `Serves:` link at the end of
each entry, which is why the link is required:

    * **medium**: one-liner. Why: why it mattered. Serves: [name](/quests/slug/quest.md)

This script reads those links back and inverts them. The index is DERIVED, never
stored - no quest log mirrors its own wins, so there is no second copy to drift.

An entry may name more than one target (it counts under each) or the literal
`Serves: none`, which is a recorded judgement that the win advanced nothing
tracked. An entry with no `Serves:` at all is UNATTRIBUTED - a gap, not a
judgement. `--orphans` shows both, and only that distinction makes the backlog of
missing attribution measurable.

Sizes are reported as counts per target so a thin-looking quest and a quest with
real outcomes behind it are told apart at a glance. `(note owed)` on a large win
is surfaced too: a large win owes a concept note next to its log, and nominating
it in the stream is meant to beat downgrading it to medium to dodge the writing.

Read-only. Never writes. Exit 0 unless --fail-on-unattributed is given.

Usage:
  uv run wins_by_stream.py brain [--orphans] [--json] [--fail-on-unattributed]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

# `* **size**: text` - the bold size marker opens every win entry.
ENTRY_RE = re.compile(r"^\s*\*\s+\*\*(small|medium|large)\*\*\s*(\(note owed\))?\s*:\s*(.*)$")
DATE_RE = re.compile(r"^##\s+(\d{4}-\d{2}-\d{2})\s*$")
# Everything from `Serves:` to end of entry; links are bundle-absolute.
SERVES_RE = re.compile(r"Serves:\s*(.+?)\s*$")
LINK_RE = re.compile(r"\[([^\]]*)\]\((/[^)]+)\)")

SIZES = ("small", "medium", "large")


def parse_log(path: Path, area: str) -> list[dict]:
    """Pull every win entry out of one area log, with its date and Serves targets.

    Entries can wrap over several lines, so a line that is not a new entry and not
    a date heading is treated as a continuation of the entry above it.
    """
    entries: list[dict] = []
    date = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        if m := DATE_RE.match(raw):
            date = m.group(1)
            continue
        if m := ENTRY_RE.match(raw):
            entries.append(
                {
                    "area": area,
                    "date": date,
                    "size": m.group(1),
                    "note_owed": bool(m.group(2)),
                    "text": m.group(3),
                }
            )
        elif entries and raw.strip() and not raw.startswith("#"):
            entries[-1]["text"] += " " + raw.strip()

    for e in entries:
        e.update(resolve_serves(e["text"]))
    return entries


def resolve_serves(text: str) -> dict:
    """Classify one entry's attribution: linked targets, explicit none, or missing."""
    m = SERVES_RE.search(text)
    if not m:
        return {"targets": [], "attribution": "unattributed"}
    tail = m.group(1)
    targets = [link for _, link in LINK_RE.findall(tail)]
    if targets:
        return {"targets": targets, "attribution": "linked"}
    if re.fullmatch(r"none\.?", tail.strip(), re.IGNORECASE):
        return {"targets": [], "attribution": "none"}
    # `Serves:` present but neither a link nor `none` - a malformed field is a gap,
    # not a judgement, so it lands with the unattributed rather than being ignored.
    return {"targets": [], "attribution": "unattributed"}


def stream_label(target: str) -> str:
    """`/quests/foo/quest.md` -> `quests/foo`; keeps goals distinguishable by file."""
    parts = target.strip("/").split("/")
    if len(parts) >= 2 and parts[0] in ("quests", "projects"):
        return f"{parts[0]}/{parts[1]}"
    return target.strip("/").removesuffix(".md")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("bundle", type=Path, help="path to the OKF bundle (e.g. brain)")
    ap.add_argument("--orphans", action="store_true", help="list unattributed + Serves: none entries")
    ap.add_argument("--json", action="store_true", dest="as_json")
    ap.add_argument("--fail-on-unattributed", action="store_true")
    args = ap.parse_args()

    wins_dir = args.bundle / "performance" / "wins"
    if not wins_dir.is_dir():
        print(f"no win stream at {wins_dir}", file=sys.stderr)
        return 2

    entries: list[dict] = []
    for log in sorted(wins_dir.glob("*/log.md")):
        entries.extend(parse_log(log, log.parent.name))

    by_stream: dict[str, list[dict]] = defaultdict(list)
    for e in entries:
        for t in e["targets"]:
            by_stream[stream_label(t)].append(e)

    unattributed = [e for e in entries if e["attribution"] == "unattributed"]
    serves_none = [e for e in entries if e["attribution"] == "none"]
    owed = [e for e in entries if e["size"] == "large" and e["note_owed"]]

    if args.as_json:
        json.dump(
            {
                "total": len(entries),
                "streams": {
                    k: {
                        "count": len(v),
                        "sizes": {s: sum(1 for e in v if e["size"] == s) for s in SIZES},
                        "areas": sorted({e["area"] for e in v}),
                        "latest": max((e["date"] or "" for e in v), default=None),
                    }
                    for k, v in sorted(by_stream.items())
                },
                "unattributed": len(unattributed),
                "serves_none": len(serves_none),
                "notes_owed": len(owed),
            },
            sys.stdout,
            indent=2,
        )
        print()
    else:
        attributed = len(entries) - len(unattributed)
        print(f"{len(entries)} win entries, {attributed} attributed, {len(by_stream)} streams\n")
        rows = sorted(by_stream.items(), key=lambda kv: (-len(kv[1]), kv[0]))
        for label, v in rows:
            sizes = " ".join(
                f"{s[0]}{sum(1 for e in v if e['size'] == s)}" for s in SIZES
            )
            areas = ",".join(sorted({e["area"] for e in v}))
            latest = max((e["date"] or "" for e in v), default="-")
            print(f"  {len(v):>3}  [{sizes}]  {label:<44} {areas:<28} latest {latest}")

        print()
        print(f"  unattributed (no Serves:) : {len(unattributed)}")
        print(f"  Serves: none (judged)     : {len(serves_none)}")
        print(f"  large wins owing a note   : {len(owed)}")

        if args.orphans:
            for title, group in (("UNATTRIBUTED", unattributed), ("SERVES: NONE", serves_none)):
                print(f"\n{title} ({len(group)})")
                for e in group:
                    print(f"  {e['date']}  {e['area']:<18} {e['size']:<7} {e['text'][:96]}")
            if owed:
                print(f"\nLARGE, NOTE OWED ({len(owed)})")
                for e in owed:
                    print(f"  {e['date']}  {e['area']:<18} {e['text'][:96]}")

    return 1 if (args.fail_on_unattributed and unattributed) else 0


if __name__ == "__main__":
    sys.exit(main())
