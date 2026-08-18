#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml>=6"]
# ///
"""List brain notes that are stale, due soon, missing a `stale_after`, or unverified.

Turns three judgement calls into date and prefix comparisons:

  stale        today >= stale_after                                  (OKF v0.2 §5.5)
  due soon     stale_after within --soon days                        (§5.5)
  missing      policy says this note should carry stale_after, and it doesn't
  trust tier   derived from `verified`, never stored                 (§5.3)
                 no verified            -> unverified
                 non-human: actors only -> machine-confirmed
                 any human: actor       -> human-reviewed

The staleness POLICY is this bundle's, not the spec's. The spec only defines what
stale_after means; which notes deserve one is our call, encoded in POLICY below so
the sweep and the weekly audit apply it identically instead of re-deciding each run.

Read-only. Never writes. Exit 0 always unless --fail-on-stale is given, so a
scheduled run can report without failing the whole routine.

Usage:
  uv run list_stale_and_unverified.py brain [--soon N] [--json] [--fail-on-stale]
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

import yaml

RESERVED = {"index.md", "log.md"}

# Which notes should carry `stale_after`, and the review horizon in days when the
# note names no explicit commitment date of its own.
#
# The test is "does this note's truth depend on a world that changes?" Preferences,
# portable concepts and finished workstreams do not - a completed quest cannot go
# stale, and a preference is true until the user says otherwise, not until a date.
#
# Deliberately narrow. Live work is the only category where a blanket horizon is
# worth flagging unprompted, because that is where drift actually keeps happening.
# A policy that emits 45 person notes every six months is a policy that teaches you
# to ignore it, so person / tool / learning / tribal notes are NOT auto-required -
# they earn a stale_after only when the note names a pending change worth chasing
# (a role about to change, a version pin expected to move, a live-config claim).
# That judgement belongs to capture, not to a blanket rule here.
POLICY = {
    # (type, workstream_status) -> horizon days.  None workstream_status = any.
    ("quest", "active"): 30,
    ("quest", "paused"): 90,
    ("project", "active"): 90,
    ("project", "paused"): 90,
}
# Types that never need stale_after, whatever else they carry.
TIMELESS = {"preference", "concept", "goal", "org", "todo"}


def split_frontmatter(text: str) -> str | None:
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    return text[text.find("\n", 3) + 1 : end + 1]


def as_date(value) -> date | None:
    """Accept a real date (PyYAML resolves unquoted YYYY-MM-DD) or a string."""
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, str):
        try:
            return date.fromisoformat(value.strip()[:10])
        except ValueError:
            return None
    return None


def trust_tier(meta: dict) -> str:
    """§5.3 - derived, never stored. A bare mapping counts as one entry (§5.2)."""
    verified = meta.get("verified")
    if verified is None:
        return "unverified"
    entries = [verified] if isinstance(verified, dict) else verified
    if not isinstance(entries, list) or not entries:
        return "unverified"
    actors = [str(e.get("by", "")) for e in entries if isinstance(e, dict)]
    if not actors:
        return "unverified"
    # The exact lowercase prefix is the whole key - `Human:` reads as an agent.
    return "human-reviewed" if any(a.startswith("human:") for a in actors) else "machine-confirmed"


def policy_horizon(meta: dict) -> int | None:
    ntype = str(meta.get("type", "")).strip()
    if ntype in TIMELESS:
        return None
    ws = meta.get("workstream_status")
    ws = str(ws).strip() if ws is not None else None
    if ntype in {"quest", "project"} and ws in {"completed", "abandoned"}:
        return None  # history cannot go stale
    for (t, want_ws), days in POLICY.items():
        if t == ntype and (want_ws is None or want_ws == ws):
            return days
    return None


def latest_verified(meta: dict) -> str | None:
    verified = meta.get("verified")
    if verified is None:
        return None
    entries = [verified] if isinstance(verified, dict) else verified
    if not isinstance(entries, list):
        return None
    stamps = [str(e.get("at")) for e in entries if isinstance(e, dict) and e.get("at")]
    return max(stamps) if stamps else None


def main() -> int:
    ap = argparse.ArgumentParser(description="List stale, due-soon, and unverified brain notes.")
    ap.add_argument("bundle", type=Path, help="path to the bundle directory")
    ap.add_argument("--soon", type=int, default=7, metavar="N",
                    help="also list notes going stale within N days (default 7)")
    ap.add_argument("--json", action="store_true", help="emit a JSON report")
    ap.add_argument("--fail-on-stale", action="store_true",
                    help="exit 1 if anything is stale (default is always exit 0)")
    args = ap.parse_args()

    if not args.bundle.is_dir():
        print(f"error: {args.bundle} is not a directory", file=sys.stderr)
        return 2

    today = date.today()
    soon_cutoff = today + timedelta(days=args.soon)
    stale, soon, missing = [], [], []
    tiers: dict[str, int] = {"unverified": 0, "machine-confirmed": 0, "human-reviewed": 0}
    unverified_notes = []

    for path in sorted(p for p in args.bundle.rglob("*.md") if p.is_file()):
        if path.name in RESERVED:
            continue
        rel = path.relative_to(args.bundle).as_posix()
        try:
            raw = split_frontmatter(path.read_text(encoding="utf-8"))
        except (UnicodeDecodeError, OSError):
            continue
        if raw is None:
            continue
        try:
            meta = yaml.safe_load(raw)
        except yaml.YAMLError:
            continue
        if not isinstance(meta, dict):
            continue

        tier = trust_tier(meta)
        tiers[tier] += 1
        ntype = str(meta.get("type", "?")).strip()
        if tier == "unverified":
            unverified_notes.append({"path": rel, "type": ntype})

        after = as_date(meta.get("stale_after"))
        horizon = policy_horizon(meta)
        if after is None:
            if horizon is not None:
                missing.append({"path": rel, "type": ntype,
                                "workstream_status": meta.get("workstream_status"),
                                "suggested_horizon_days": horizon,
                                "suggested": str(today + timedelta(days=horizon))})
        elif today >= after:
            stale.append({"path": rel, "type": ntype, "stale_after": str(after),
                          "days_overdue": (today - after).days,
                          "last_verified": latest_verified(meta)})
        elif after <= soon_cutoff:
            soon.append({"path": rel, "type": ntype, "stale_after": str(after),
                         "days_left": (after - today).days})

    stale.sort(key=lambda r: -r["days_overdue"])
    soon.sort(key=lambda r: r["days_left"])
    missing.sort(key=lambda r: (r["type"], r["path"]))

    report = {"as_of": str(today), "soon_window_days": args.soon,
              "stale": stale, "due_soon": soon, "missing_stale_after": missing,
              "trust_tiers": tiers, "unverified": unverified_notes}

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(f"brain freshness — {args.bundle}  (as of {today})")
        print(f"  stale: {len(stale)}   due within {args.soon}d: {len(soon)}   "
              f"missing stale_after: {len(missing)}")
        print(f"  trust: {tiers['human-reviewed']} human-reviewed, "
              f"{tiers['machine-confirmed']} machine-confirmed, "
              f"{tiers['unverified']} unverified")
        for r in stale:
            v = f", last verified {r['last_verified'][:10]}" if r["last_verified"] else ", never verified"
            print(f"  ! STALE     {r['path']}  ({r['days_overdue']}d overdue, "
                  f"stale_after {r['stale_after']}{v})")
        for r in soon:
            print(f"  · due soon  {r['path']}  (in {r['days_left']}d, {r['stale_after']})")
        for r in missing:
            ws = f"/{r['workstream_status']}" if r["workstream_status"] else ""
            print(f"  ? missing   {r['path']}  ({r['type']}{ws} — policy suggests "
                  f"{r['suggested']})")

    return 1 if (args.fail_on_stale and stale) else 0


if __name__ == "__main__":
    sys.exit(main())
