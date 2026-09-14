#!/usr/bin/env python3
"""`F-162` — every link in the docs points at something that exists.

WHY THIS EXISTS
---------------
`CLAUDE.md`'s standing rule is that every claim gets a link to the file,
commit or source it came from, and that the owner is never left "blind with
words". A link that 404s is worse than no link: it looks like evidence and
isn't, and the reader only finds out by clicking.

Five had rotted before anyone checked — two pointing into `app/assets/brand/`,
which is gitignored (the real file is in the top-level `brand/`), and three at
files deleted when features were removed.

The fix for a dead target is NOT to delete the sentence. `docs/21`, `docs/28`
and `docs/CHANGELOG` are append-only by rule. It is to correct the path, or
say plainly that the file is gone and when.

    cd app && python3 tool/check_links.py
"""

from __future__ import annotations

import pathlib
import re
import sys

# Run from app/, check the repository.
ROOT = pathlib.Path(__file__).resolve().parent.parent.parent

LINK = re.compile(r'\[[^\]]+\]\(([^)#][^)]*)\)')


def main() -> int:
    targets = sorted(ROOT.glob("docs/*.md")) + [ROOT / "CLAUDE.md", ROOT / "README.md"]
    broken: list[str] = []
    checked = 0

    for md in targets:
        if not md.exists():
            continue
        checked += 1
        for match in LINK.finditer(md.read_text()):
            # Strip any #anchor: this checks that the file exists, not that a
            # heading inside it does.
            target = match.group(1).split("#")[0].strip()
            if not target or target.startswith(("http://", "https://", "mailto:")):
                continue
            if not (md.parent / target).resolve().exists():
                broken.append(f"{md.relative_to(ROOT)} → {target}")

    if broken:
        print("BROKEN DOC LINKS\n")
        for b in broken:
            print(f"  • {b}")
        print(
            "\nCorrect the path, or — if the file is genuinely gone — say so in "
            "the text and unlink it.\nDo NOT delete the sentence: the ledgers "
            "are append-only."
        )
        return 1

    print(f"LINKS OK ({checked} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
