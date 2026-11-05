#!/usr/bin/env python3
"""Read-only audit of an Obsidian vault: structure, junk and link health. Prints names and counts, never the text of a note.

Usage: vault_audit.py <vault> [--deps <dir> ...]
--deps also lists which files under those folders name a top-level vault folder, so you can see what a move would break.
"""
from __future__ import annotations

import argparse
import collections
import os
import re
import subprocess
import time
from pathlib import Path

SKIP = {".obsidian", ".trash", ".stversions", ".stfolder", ".git", "node_modules"}
WIKILINK = re.compile(r"!?\[\[([^\]|#]+)")
MD_LINK = re.compile(r"\]\((?!https?:|obsidian:|mailto:|#)([^)#]+\.md)\)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("vault", type=Path)
    parser.add_argument("--deps", nargs="*", default=[], type=Path)
    args = parser.parse_args()
    vault = args.vault.expanduser()
    now = time.time()
    files = []
    for root, dirs, names in os.walk(vault):
        dirs[:] = [d for d in dirs if d not in SKIP]
        files += [Path(root) / n for n in names]
    notes = [f for f in files if f.suffix == ".md"]
    print(f"{len(files)} files, {len(notes)} notes, {sum(f.stat().st_size for f in files) / 1e6:.0f} MB")

    print("\nTop level")
    for path in sorted(vault.iterdir()):
        if path.name in SKIP or path.name.startswith("."):
            continue
        if path.is_dir():
            inside = [f for f in files if path in f.parents]
            newest = max((f.stat().st_mtime for f in inside), default=now)
            print(f"  {path.name}/  {len(inside)} files, {sum(f.stat().st_size for f in inside) / 1e6:.1f} MB, last change {int((now - newest) / 86400)}d ago")
        else:
            print(f"  {path.name}  (loose file, {path.stat().st_size // 1024} KB)")

    print("\nLikely junk")
    print("  conflicts:", [str(f.relative_to(vault)) for f in files if "sync-conflict" in f.name or ".conflict." in f.name][:20])
    print("  empty notes:", [str(f.relative_to(vault)) for f in notes if f.stat().st_size < 5][:20])
    print("  empty folders:", [str(Path(r).relative_to(vault)) for r, d, n in os.walk(vault) if not d and not n and not SKIP & set(Path(r).parts)][:20])
    repeated = [name for name, count in collections.Counter(f.stem.lower() for f in notes).items() if count > 1]
    print("  same note name twice (a [[link]] to it is ambiguous):", repeated[:20])

    stems = {f.stem.lower() for f in notes} | {f.name.lower() for f in files}
    total = broken = with_path = 0
    broken_by_folder: collections.Counter = collections.Counter()
    linked: set[str] = set()
    relative = 0
    for note in notes:
        text = note.read_text(encoding="utf-8", errors="ignore")
        relative += len(MD_LINK.findall(text))
        for raw in WIKILINK.findall(text):
            target = raw.strip()
            total += 1
            with_path += "/" in target
            last = target.rsplit("/", 1)[-1].lower().removesuffix(".md")
            if last in stems:
                linked.add(last)
            else:
                broken += 1
                broken_by_folder[note.relative_to(vault).parts[0]] += 1
    print(f"\nLinks: {total} wikilinks, {with_path} with a path (these break on a move), {broken} broken {dict(broken_by_folder.most_common(6))}, {relative} relative Markdown links")
    print(f"Notes nobody links to: {sum(1 for f in notes if f.stem.lower() not in linked)}")

    if args.deps:
        print("\nFiles that name a top-level folder")
        for path in sorted(vault.iterdir()):
            if path.name in SKIP or path.name.startswith(".") or not path.is_dir():
                continue
            found = subprocess.run(["grep", "-rlF", "--exclude-dir=node_modules", "--exclude-dir=.git", "--exclude-dir=venv", path.name, *map(str, args.deps)],
                                   capture_output=True, text=True, check=False).stdout.split("\n")
            found = [f for f in found if f]
            if found:
                print(f"  {path.name}: {len(found)}, e.g. {found[:3]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
