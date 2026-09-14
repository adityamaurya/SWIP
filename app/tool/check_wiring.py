#!/usr/bin/env python3
"""`F-158` — find code that is built, correct, tested, and unreachable.

WHY THIS EXISTS
---------------
Twice now a feature has been finished and then not connected, and both times
nothing noticed for months.

  * **The floating bubble.** `F-131` shipped the permission screen and a
    switch. The switch wrote `SharedPreferences['swip.bubble.enabled']` and
    **no code in the project ever read that key.** There was no service and
    nothing registered in the manifest. The permission was granted, the switch
    went on, and Android was never asked to draw anything.

  * **The merchant-name lookup.** `F-157` shipped `merchant_directory.dart`
    with sixteen passing tests, and **nothing in `lib/` imports it.** The
    tests all pass. They would pass forever.

Neither is the kind of failure a test suite catches, because in both cases
every piece works. What is missing is the wire between them, and a wire that
does not exist has nothing to assert on.

So this checks the wires themselves, in the three shapes the project uses:

  1. a Dart file in `lib/` that nothing in `lib/` imports;
  2. a method-channel name called from Dart with no handler in
     `MainActivity.kt`, or a handler nothing calls;
  3. a `SharedPreferences` key written but never read, or read but never
     written.

Exceptions are declared below **with a reason**, because "known and accepted"
and "nobody noticed" look identical from the outside, and the whole point of
this file is to tell them apart.

    cd app && python3 tool/check_wiring.py
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
KOTLIN = ROOT / "android/app/src/main/kotlin/in/swip/app/MainActivity.kt"

# ── declared exceptions ─────────────────────────────────────────────────
#
# Each entry needs a reason, and the reason has to be a decision rather than
# an oversight. If you cannot write one, that is the check working.

UNIMPORTED_OK = {
    "lib/data/sources/merchant_directory.dart":
        "F-157. Built and deliberately not connected: wiring it needs the one "
        "HTTP client docs/30 §1 greps for and fails the build on, and three "
        "constants still marked VERIFY. Both are the owner's call — "
        "docs/35 §3.2.",
}

PREFS_WRITE_ONLY_OK: dict[str, str] = {}

PREFS_READ_ONLY_OK = {
    "swip.bubble.enabled":
        "F-158. F-131's dead key, kept only so a wish made in that build is "
        "honoured once and then deleted. Never written again.",
}


def dart_files() -> list[pathlib.Path]:
    return sorted(LIB.rglob("*.dart"))


def check_unimported() -> list[str]:
    """A file nothing imports is a file nothing runs."""
    imported: set[str] = set()
    for f in dart_files():
        text = f.read_text()
        for m in re.finditer(r"""(?:import|export)\s+'([^']+)'""", text):
            target = m.group(1)
            if target.startswith("package:swip/"):
                imported.add(
                    (LIB / target[len("package:swip/"):]).as_posix())
            elif not target.startswith(("dart:", "package:")):
                imported.add((f.parent / target).resolve().as_posix())

    problems = []
    for f in dart_files():
        rel = f.relative_to(ROOT).as_posix()
        # `main.dart` is the entry point; nothing imports it by design.
        if rel == "lib/main.dart":
            continue
        if f.as_posix() in imported or f.relative_to(ROOT.parent).as_posix() in imported:
            continue
        if rel in UNIMPORTED_OK:
            continue
        problems.append(
            f"{rel} is imported by nothing in lib/. It cannot run. "
            f"Wire it, delete it, or add it to UNIMPORTED_OK with a reason.")
    return problems


def check_channel() -> list[str]:
    """Dart calling into a void, or Kotlin answering nobody."""
    if not KOTLIN.exists():
        return []

    called = set()
    for f in dart_files():
        for m in re.finditer(
                r"""invoke\w*Method(?:<[^>]*>)?\(\s*'([a-zA-Z]\w*)'""",
                f.read_text()):
            called.add(m.group(1))

    handled = set(re.findall(r"""^\s+"([a-zA-Z]\w*)"\s*->""",
                             KOTLIN.read_text(), re.MULTILINE))

    # NOTE: a channel name has to be a plain literal at the call site to be
    # seen here — `invokeMethod<bool>(on ? 'a' : 'b')` is invisible to this,
    # and was, the first time this file ran. That is a constraint worth
    # keeping rather than regexing around: a method name hidden inside an
    # expression is one a grep cannot find, and so is one a person reading the
    # file cannot find either. Write the two branches.

    problems = []
    for name in sorted(called - handled):
        problems.append(
            f"Dart calls '{name}' on the method channel and MainActivity.kt "
            f"has no handler for it. The call returns nothing, forever.")
    for name in sorted(handled - called):
        problems.append(
            f"MainActivity.kt handles '{name}' and no Dart calls it. "
            f"Dead platform code.")
    return problems


def check_prefs() -> list[str]:
    """A preference written and never read is a switch that does nothing."""
    keys: dict[str, tuple[set[str], set[str]]] = {}

    for f in dart_files():
        text = f.read_text()
        # Resolve `static const prefKey = 'x'` style indirection so a key
        # referenced through its constant is still seen.
        consts = dict(re.findall(
            r"""(?:static\s+)?const\s+(\w+)\s*=\s*'([^']+)'""", text))

        for verb, group in (("w", r"set"), ("r", r"get")):
            pattern = (rf"""\.{group}(?:Bool|String|Int|Double|StringList)"""
                       rf"""\(\s*(?:'([^']+)'|([\w.]+))""")
            for m in re.finditer(pattern, text):
                literal, ref = m.group(1), m.group(2)
                key = literal
                if key is None and ref is not None:
                    key = consts.get(ref.split(".")[-1])
                if key is None or not key.startswith("swip."):
                    continue
                w, r = keys.setdefault(key, (set(), set()))
                (w if verb == "w" else r).add(f.relative_to(ROOT).as_posix())

    problems = []
    for key, (writes, reads) in sorted(keys.items()):
        if writes and not reads and key not in PREFS_WRITE_ONLY_OK:
            problems.append(
                f"'{key}' is written in {', '.join(sorted(writes))} and read "
                f"nowhere. **This is the exact shape of the dead floating "
                f"bubble.** A switch that stores an answer nobody asks for "
                f"does nothing at all.")
        if reads and not writes and key not in PREFS_READ_ONLY_OK:
            problems.append(
                f"'{key}' is read in {', '.join(sorted(reads))} and never "
                f"written. It will always be the default.")
    return problems


def main() -> int:
    problems = check_unimported() + check_channel() + check_prefs()
    if problems:
        print("WIRING PROBLEMS\n")
        for p in problems:
            print(f"  • {p}\n")
        return 1
    print("WIRING OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
