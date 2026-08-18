# /// script
# requires-python = ">=3.9"
# ///
"""Reduce a Claude transcript to the text worth extracting facts from.

Drops tool results, diffs and base64 - they are the bulk of a .jsonl and carry
almost no durable facts. Truncates to a head+tail window so one enormous session
cannot blow the child's context; the truncation is announced in the output so the
extractor knows it saw a partial.

Usage: trim-transcript.py <path> [--max-chars N]
"""
import json, sys, pathlib

MAX = 60000
NOISE_PREFIXES = ("<tool_use_error", "diff --git", "Binary file", "data:image/")


def text_of(msg):
    c = msg.get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        return "\n".join(b.get("text", "") for b in c
                         if isinstance(b, dict) and b.get("type") == "text")
    return ""


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: trim-transcript.py <path> [--max-chars N]")
    path = pathlib.Path(sys.argv[1])
    cap = MAX
    if "--max-chars" in sys.argv:
        cap = int(sys.argv[sys.argv.index("--max-chars") + 1])

    parts = []
    raw = path.read_text(errors="replace")

    if path.suffix == ".jsonl":
        for line in raw.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue
            msg = ev.get("message") or ev
            role = msg.get("role") or ev.get("type")
            if role not in ("user", "assistant"):
                continue
            t = text_of(msg).strip()
            if not t or t.startswith(NOISE_PREFIXES):
                continue
            parts.append(f"{role.upper()}: {t}")
    else:
        parts.append(raw)

    body = "\n\n".join(parts)
    if len(body) > cap:
        head, tail = body[: cap // 2], body[-cap // 2:]
        body = (head
                + f"\n\n[... TRUNCATED {len(body) - cap} chars - this is a partial transcript ...]\n\n"
                + tail)
    sys.stdout.write(body)


if __name__ == "__main__":
    main()
