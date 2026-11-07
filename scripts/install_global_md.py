#!/usr/bin/env python3
"""Put templates/CLAUDE.global.md into ~/.claude/CLAUDE.md without touching anything that is not ours.

The managed block sits between <!-- bryhadyr:begin ... --> and <!-- bryhadyr:end -->. Re-running replaces that block in place;
without one, the block is appended together with the section below it in the template (the table of directions, which is yours to fill and is never replaced). Everything else in the target stays as it was, line ends included.
A begin marker without an end marker (or the other way round) is refused: nothing is written.

Usage: install_global_md.py [--lang uk] [--dry-run] [target]      (target defaults to ~/.claude/CLAUDE.md)
Works with plain python3 on Linux, macOS and Windows (Git Bash / py).
"""
import argparse
import os
import re
import sys

BEGIN = "<!-- bryhadyr:begin"
END = "<!-- bryhadyr:end -->"
HERE = os.path.dirname(os.path.abspath(__file__))


def merge(old, block, extra=""):
    """Return (new text, what happened). `old` uses \\n line ends."""
    n_begin, n_end = old.count(BEGIN), old.count(END)
    if n_begin != n_end or n_begin > 1:
        raise SystemExit("refused: expected one '%s' and one '%s' in the target, found %d and %d" % (BEGIN, END, n_begin, n_end))
    m = re.search(re.escape(BEGIN) + r".*?" + re.escape(END), old, re.S)
    if m:
        new = old[: m.start()] + block + old[m.end():]
        how = "replaced the managed block"
    else:
        new = (old.rstrip("\n") + "\n\n" if old.strip() else "") + block + "\n"
        if extra:
            new += "\n" + extra + "\n"      # the part below the block is yours: written once, never replaced
        how = "appended the block"
    return new, how


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("target", nargs="?", default=os.path.join(os.path.expanduser("~"), ".claude", "CLAUDE.md"))
    ap.add_argument("--lang", choices=["en", "uk"], default="en")
    ap.add_argument("--dry-run", action="store_true", help="print the result instead of writing it")
    args = ap.parse_args()

    src = os.path.join(HERE, "..", "templates", "CLAUDE.global.md" if args.lang == "en" else "CLAUDE.global.uk.md")
    with open(src, encoding="utf-8") as f:
        text = f.read().strip("\n")
    cut = text.index(END) + len(END)
    block, extra = text[:cut], text[cut:].strip("\n")
    old, crlf = "", False
    if os.path.exists(args.target):
        with open(args.target, encoding="utf-8", newline="") as f:
            raw = f.read()
        crlf = "\r\n" in raw          # keep the file's own line ends
        old = raw.replace("\r\n", "\n")

    new, how = merge(old, block, extra)
    if new == old:
        print("already up to date: " + args.target)
        return
    if args.dry_run:
        sys.stdout.buffer.write(new.encode("utf-8"))     # bytes: a Windows console may not be UTF-8
        return
    os.makedirs(os.path.dirname(os.path.abspath(args.target)), exist_ok=True)
    with open(args.target, "w", encoding="utf-8", newline="") as f:
        f.write(new.replace("\n", "\r\n") if crlf else new)
    print(how + ": " + args.target)


if __name__ == "__main__":
    main()
