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
    """The bubble's ground must stay an oval.

    ## What this used to check, and why it changed

    `swip_bubble_bg.xml` was a **rectangle with a 28 dp corner radius**, which
    is a true circle only while the view is square. That was deliberate — the
    bubble could stretch into a pill, and a rectangle-with-radius becomes a
    correct pill on its own. So this rule read `val size = dp(56f)` out of
    `buildBubble` and demanded the radius be exactly half of it, because
    neither file mentioned the other except in a comment and a comment is not
    a check.

    `F-185` deleted the pill. The owner reported the shape it produced — *"it
    should be circle only not become rounded rectangle"* — and with the label
    gone there is nothing left that ever wants a non-square bubble.

    So the drawable is an `oval` now, and the rule that watched two numbers has
    become a rule that watches one word. **That is a stronger guarantee, not a
    weaker one:** a radius can drift out of step with a diameter, and an oval
    cannot stop being round.

    The check is kept rather than deleted because the failure it guards against
    is unchanged and still silent — a rounded square looks fine in a code
    review and wrong on a phone.
    """
    if not BUBBLE_KT.exists() or not BUBBLE_BG.exists():
        return [f"{BUBBLE_KT.name} or {BUBBLE_BG.name} is missing"]

    bg = BUBBLE_BG.read_text(encoding="utf-8")
    shape = re.search(r'android:shape="(\w+)"', bg)

    # A pattern that stops matching is a check that silently passes forever,
    # so an unreadable shape is a failure rather than a shrug.
    if not shape:
        return ['could not find `android:shape="…"` in swip_bubble_bg.xml — '
                "the bubble shape check is no longer checking anything"]
    if shape.group(1) != "oval":
        return [f'swip_bubble_bg.xml is a "{shape.group(1)}", not an oval. '
                "The floating button must be round at every width — `F-185`, "
                "after a pill-shaped tap state was reported as the bubble "
                "turning into a rounded rectangle. If a pill is genuinely "
                "wanted again, this rule goes back to comparing the corner "
                "radius against `buildBubble`'s diameter."]

    # Belt and braces: an oval with corners is a contradiction somebody has
    # half-finished, and Android silently ignores the corners.
    if "<corners" in bg:
        return ["swip_bubble_bg.xml is an oval but still declares <corners>. "
                "Android ignores it, so the file says two different things and "
                "only one of them is true."]
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


# ── 7. a widget test that renders a category, and never lets it finish ───────
#
# `F-180`. This is the third time the same test has been written wrong, and the
# rule it breaks has been in `CLAUDE.md` since `F-159`. So it stops being a
# reading habit and becomes a check.
#
# A capture **with** a category renders `_FoilCode`, whose gold sweep is
# `.animate(onPlay: (c) => c.repeat(count: 4))`. A single `t.pump()` starts that
# and never finishes it, so the test dies on *"A Timer is still pending even
# after the widget tree was disposed"* — pointing at the widget tree rather than
# at the assertion, which is why it reads as a mystery every time.
#
# `pumpAndSettle` is safe here precisely **because the repeat is bounded**. An
# unbounded one would hang instead, which is why this cannot be a blanket
# "always settle".
#
# ## Why the animated widgets are discovered rather than listed
#
# The first version of this check flagged any test mentioning `withMcc`, and it
# fired on eight tests in `capture_result_page_test.dart` that pass perfectly
# well — `CaptureResultPage` does not contain `_FoilCode`. A check that flags
# passing tests is worse than the bug it replaces, because the first thing
# anyone does with it is switch it off.
#
# So the set is computed: files whose source contains a bounded `repeat(count:`
# are the animated ones, their public widget classes are collected, and one hop
# outward catches the widgets that embed them. Two hops is enough for this tree
# and the set is printed in the failure so a wrong answer is visible rather than
# mysterious.
#
# ## What it cannot see, said plainly
#
# The test has to name the widget. A suite whose `harness()` builds it and whose
# tests only pass an event — which is exactly how `capture_result_page_test`
# is written — slips through. That is a **miss**, not a false positive, and it
# is the right way round for a check like this: a miss costs one CI round, and
# a check that flags passing tests gets switched off, which costs all of them.
SETTLE_EXCEPTIONS: dict[str, str] = {
    # "test name": "why this one genuinely does not need to settle"
}


def _bounded_repeat_widgets() -> set[str]:
    """Public widget classes whose tree contains a bounded `repeat(count:)`."""
    lib = ROOT / "lib"
    direct: dict[pathlib.Path, set[str]] = {}
    for path in lib.rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        if "repeat(count:" not in text:
            continue
        direct[path] = {
            m.group(1)
            for m in re.finditer(r"^class ([A-Z]\w+)", text, re.M)
            if not m.group(1).startswith("_")
        }

    names: set[str] = set()
    for found in direct.values():
        names |= found

    # One hop: a widget that builds an animated one animates too.
    for path in lib.rglob("*.dart"):
        if path in direct:
            continue
        text = path.read_text(encoding="utf-8")
        if not any(f"{n}(" in text for n in names):
            continue
        names |= {
            m.group(1)
            for m in re.finditer(r"^class ([A-Z]\w+)", text, re.M)
            if not m.group(1).startswith("_")
        }
    return names


def check_test_settles() -> list[str]:
    problems: list[str] = []
    tests = ROOT / "test"
    if not tests.is_dir():
        return problems

    animated = _bounded_repeat_widgets()
    if not animated:
        return problems

    for path in sorted(tests.glob("*.dart")):
        text = path.read_text(encoding="utf-8")
        if "withMcc" not in text:
            continue

        # Split on `testWidgets(` so each block is one test. Crude, and it does
        # not need to be more than that: the final block runs to end of file,
        # which can only produce a false positive, never a miss.
        for block in text.split("testWidgets(")[1:]:
            name = re.match(r"\s*['\"](.*?)['\"]", block)
            title = name.group(1) if name else "(unnamed)"
            if title in SETTLE_EXCEPTIONS:
                continue
            if "withMcc" not in block:
                continue
            if not any(f"{n}(" in block for n in animated):
                continue
            if "pumpAndSettle" in block or "elapse(" in block:
                continue
            problems.append(
                f"{path.name}: the test {title!r} builds a capture with a "
                f"category and never settles. `_FoilCode`'s sweep is "
                f"`repeat(count: 4)`, so a bare `pump()` leaves a timer "
                f"pending and the test dies on the widget tree rather than on "
                f"its assertion. Use `await t.pumpAndSettle()` — safe because "
                f"the repeat is bounded. See CLAUDE.md. "
                f"(Animated widgets found: {', '.join(sorted(animated))}.)"
            )
    return problems


def main() -> int:
    problems = (check_unimported() + check_channel() + check_prefs()
                + check_callbacks() + check_bubble_radius() + check_trace_gate()
                + check_test_settles())
    if problems:
        print("WIRING PROBLEMS\n")
        for p in problems:
            print(f"  • {p}\n")
        return 1
    print("WIRING OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
