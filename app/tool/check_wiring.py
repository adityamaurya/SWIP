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

  0. a widget callback declared, called, and never passed by any caller;
  1. a Dart file in `lib/` that nothing in `lib/` imports;
  2. a method-channel name called from Dart with no handler in either
     `MainActivity.kt` or `SwipHoverActivity.kt`, or a handler nothing calls;
  3. a `SharedPreferences` key written but never read, or read but never
     written;
  4. the bubble's diameter and its background's corner radius drifting apart;
  5. the temporary bubble trace losing its "debug builds only" gate.

The fourth is a different animal from the first three and belongs here for the
same reason they do. `swip_bubble_bg.xml` is a rounded rectangle whose radius
is exactly **half** the bubble's size — that is what makes the collapsed state
a true circle and the expanded state a true pill, with no code choosing between
them. Change one number and nothing fails: the build is green, every test
passes, and the bubble quietly becomes a rounded square. `F-170` moved both
from 48/24 to 56/28, and the only thing that would have caught a half-done
version of that is this.

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

# `F-175`. The **second** engine's channel handler.
#
# SWIP runs two Flutter engines: `MainActivity` is the app, `SwipHoverActivity`
# is the transparent window the floating bubble opens. Both register
# `in.swip.app/nfc`, and they do NOT register the same methods — the hovering
# one answers only what a window with no NFC and no `MainActivity` state can
# honestly answer.
#
# This check compared Dart's calls against `MainActivity` alone, so a method
# that only the hovering window handles (`openTapScreen`) would have been
# reported as a call into nothing. Which is the gate crying wolf about
# correctly wired code — and a gate that cries wolf stops being read, which is
# the lesson `check_secrets.sh` already taught this project.
KOTLIN_HOVER = ROOT / "android/app/src/main/kotlin/in/swip/app/SwipHoverActivity.kt"
BUBBLE_KT = ROOT / "android/app/src/main/kotlin/in/swip/app/SwipBubbleService.kt"
BUBBLE_BG = ROOT / "android/app/src/main/res/drawable/swip_bubble_bg.xml"
TRACE_KT = ROOT / "android/app/src/main/kotlin/in/swip/app/BubbleTrace.kt"

# ── declared exceptions ─────────────────────────────────────────────────
#
# Each entry needs a reason, and the reason has to be a decision rather than
# an oversight. If you cannot write one, that is the check working.

UNIMPORTED_OK: dict[str, str] = {
    # F-157's entry lived here for one round. It is gone because the file is
    # wired now (F-160) — which is the only way an entry should ever leave
    # this dict. Deleting an exception because it is inconvenient is how the
    # check stops meaning anything.
}

PREFS_WRITE_ONLY_OK: dict[str, str] = {}

CALLBACKS_OK: dict[str, str] = {}

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

    # The union of BOTH engines' handlers. See KOTLIN_HOVER above for why
    # there are two, and why comparing against one of them reported correctly
    # wired code as broken.
    handled = set()
    for source in (KOTLIN, KOTLIN_HOVER):
        if not source.exists():
            continue
        handled |= set(re.findall(r"""^\s+"([a-zA-Z]\w*)"\s*->""",
                                  source.read_text(), re.MULTILINE))

    # NOTE: a channel name has to be a plain literal at the call site to be
    # seen here — `invokeMethod<bool>(on ? 'a' : 'b')` is invisible to this,
    # and was, the first time this file ran. That is a constraint worth
    # keeping rather than regexing around: a method name hidden inside an
    # expression is one a grep cannot find, and so is one a person reading the
    # file cannot find either. Write the two branches.

    problems = []
    for name in sorted(called - handled):
        problems.append(
            f"Dart calls '{name}' on the method channel and neither "
            f"MainActivity.kt nor SwipHoverActivity.kt has a handler for it. "
            f"The call returns nothing, forever.")
    for name in sorted(handled - called):
        problems.append(
            f"'{name}' is handled in Kotlin and no Dart calls it. "
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


def check_callbacks() -> list[str]:
    """A widget callback that is declared, called, and never passed.

    `F-169`. `DashboardPage` declared an `onOpenEvent`, and both the hero
    capture and every recent row called it on tap. **Nothing ever passed one.**
    So the callback was null and tapping an MCC on the dashboard did nothing,
    while the identical row in the Ledger tab worked because that file wires
    it. Third time this shape has turned up, and the first three checks in this
    file all miss it: the file IS imported, no channel is involved, and no
    preference is written.

    The test is deliberately narrow, because the alternative is false alarms
    and a gate that cries wolf stops being read (see `check_secrets.sh`):

      * only nullable callback fields whose names begin `on`;
      * only classes that are constructed **somewhere** in `lib/` — a class
        nobody builds is a different problem and this cannot tell which;
      * a callback passed at *any* one construction site counts as wired. Some
        screens legitimately supply a handler and others legitimately do not;
      * and — the sharp part — **only callbacks the widget invokes as
        `name?.call(`**.

    That last rule is what makes this worth having rather than noisy. The
    first version of this check flagged two more, and both were fine:
    `CaptureSheet.onPrimary` falls back to `?? maybePop()`, and
    `LedgerRow.onLongPress` is handed to an `InkWell`, where null means "no
    long press" and nothing is lost. A null there is a working default.

    `name?.call(` is different. It is a widget acting on a user's tap by
    invoking a callback that is not there, so the tap does nothing at all and
    nothing anywhere says so. That is exactly what `DashboardPage.onOpenEvent`
    did, and it is always a bug.
    """
    declared: dict[str, list[tuple[str, str]]] = {}  # class -> [(field, file)]

    for f in dart_files():
        text = f.read_text()
        rel = f.relative_to(ROOT).as_posix()
        current: str | None = None
        for line in text.split("\n"):
            cls = re.match(r"^(?:abstract\s+)?class\s+(\w+)", line)
            if cls:
                current = cls.group(1)
                continue
            if current is None:
                continue
            # `final VoidCallback? onX;` / `final void Function(T)? onX;`
            m = re.match(r"^\s+final\s+.*\?\s+(on[A-Z]\w*)\s*;\s*$", line)
            if m and ("Function" in line or "Callback" in line):
                declared.setdefault(current, []).append((m.group(1), rel))

    # Collect the argument text of every construction site, per class.
    passed: dict[str, set[str]] = {}
    built: set[str] = set()

    for f in dart_files():
        text = f.read_text()
        for cls in declared:
            for m in re.finditer(rf"\b{cls}\(", text):
                # Skip the constructor's own declaration, `const Foo({`.
                start = m.end()
                if text[start:start + 1] == "{":
                    continue
                depth, i = 1, start
                while i < len(text) and depth:
                    if text[i] == "(":
                        depth += 1
                    elif text[i] == ")":
                        depth -= 1
                    i += 1
                args = text[start:i]
                built.add(cls)
                for name in re.findall(r"(\bon[A-Z]\w*)\s*:", args):
                    passed.setdefault(cls, set()).add(name)

    problems = []
    for cls, fields in sorted(declared.items()):
        if cls not in built:
            continue
        for field, rel in fields:
            if field in passed.get(cls, set()):
                continue
            if f"{cls}.{field}" in CALLBACKS_OK:
                continue
            # Only the harmful shape: the widget invokes it on a user action
            # and there is no fallback, so the action silently does nothing.
            if f"{field}?.call(" not in (ROOT / rel).read_text():
                continue
            problems.append(
                f"{rel}: {cls}.{field} is declared and never passed by any "
                f"caller in lib/. If something calls it, it calls null. "
                f"**This is how tapping an MCC on the dashboard did nothing "
                f"for months.** Wire it, remove it, or add "
                f"'{cls}.{field}' to CALLBACKS_OK with a reason.")
    return problems


def check_bubble_radius() -> list[str]:
    """The bubble's corner radius must stay half its diameter.

    `buildBubble` sets `val size = dp(56f)` and `swip_bubble_bg.xml` carries
    `<corners android:radius="28dp" />`. Neither file mentions the other except
    in a comment, and a comment is not a check — which is exactly the situation
    that produced every other entry in this file.
    """
    if not BUBBLE_KT.exists() or not BUBBLE_BG.exists():
        return [f"{BUBBLE_KT.name} or {BUBBLE_BG.name} is missing"]

    # Anchored to `buildBubble`, not searched across the file.
    #
    # `F-173` added a snooze target with its own `val size = dp(72f)`, earlier
    # in the file than the bubble's, and an unanchored search matched that
    # one — so the gate demanded a 36 dp corner radius and failed a build over
    # a number it had read off the wrong widget. A check that can be pointed at
    # the wrong thing by an unrelated edit is worse than no check, because it
    # fails loudly and for a reason that is not true.
    kotlin = BUBBLE_KT.read_text(encoding="utf-8")
    builder = kotlin.find("private fun buildBubble")
    size = (re.search(r"val size = dp\((\d+(?:\.\d+)?)f\)", kotlin[builder:])
            if builder >= 0 else None)
    radius = re.search(r'<corners android:radius="(\d+(?:\.\d+)?)dp"',
                       BUBBLE_BG.read_text(encoding="utf-8"))

    # A pattern that stops matching is a check that silently passes forever,
    # so an unreadable number is a failure rather than a shrug.
    if not size:
        return ["could not find `val size = dp(…f)` inside `buildBubble` in "
                "SwipBubbleService.kt — the bubble radius check is no longer "
                "checking anything"]
    if not radius:
        return ["could not find `<corners android:radius=\"…dp\">` in "
                "swip_bubble_bg.xml — the bubble radius check is no longer "
                "checking anything"]

    want = float(size.group(1)) / 2
    got = float(radius.group(1))
    if abs(want - got) > 1e-6:
        return [f"the bubble is {size.group(1)} dp across, so "
                f"swip_bubble_bg.xml's corner radius must be {want:g} dp — it "
                f"is {got:g} dp, which makes the collapsed bubble a rounded "
                f"square instead of a circle"]
    return []


def check_trace_gate() -> list[str]:
    """`F-176`. The temporary bubble trace must stay impossible to ship.

    `BubbleTrace` records the floating button's whole lifecycle so a
    disappearance can be read rather than guessed at. It is **debugging
    apparatus**, it is meant to be deleted once the cause is found, and in the
    meantime the one thing that must stay true is that a Play Store build
    records nothing.

    That is not enforced by a note in a checklist. `enabled()` is written in
    terms of `FLAG_DEBUGGABLE`, which the build system sets on a debug APK and
    never on a release one — so the guarantee is a property of the artifact
    rather than of anybody's memory.

    This check exists because the obvious "temporary" shortcut is to swap that
    for `true` while chasing something on a release build, and then to ship it.
    Nothing would fail. The log would simply start following users around.

    When the trace is deleted, delete this check with it — a rule guarding a
    file that no longer exists is the next thing to quietly stop meaning
    anything. `docs/38-BUBBLE-TRACE.md` lists both.
    """
    if not TRACE_KT.exists():
        # Already removed. Nothing to guard, and that is the expected end
        # state rather than a problem.
        return []

    text = TRACE_KT.read_text(encoding="utf-8")
    gate = re.search(r"fun enabled\([^)]*\)[^\n]*=\s*\n?([^\n]*\n[^\n]*)",
                     text)
    if gate is None:
        return ["BubbleTrace.enabled() is not where it was — the check that "
                "keeps the temporary trace out of a release build can no "
                "longer see it. Fix this check, or delete both (docs/38)."]
    if "FLAG_DEBUGGABLE" not in gate.group(1):
        return ["BubbleTrace.enabled() no longer tests FLAG_DEBUGGABLE. The "
                "temporary bubble trace would ship to Play Store users and "
                "nothing else would fail. See docs/38-BUBBLE-TRACE.md."]
    return []


def main() -> int:
    problems = (check_unimported() + check_channel() + check_prefs()
                + check_callbacks() + check_bubble_radius() + check_trace_gate())
    if problems:
        print("WIRING PROBLEMS\n")
        for p in problems:
            print(f"  • {p}\n")
        return 1
    print("WIRING OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
