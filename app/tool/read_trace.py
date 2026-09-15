#!/usr/bin/env python3
"""`F-179` — read an exported bubble trace and say what happened. **Temporary.**

    python3 tool/read_trace.py SWIP_BubbleTrace_2026-09-15_14-02-11.jsonl

WHY THIS EXISTS
---------------
`F-176` built the recorder; this reads it. The two are one tool and they get
deleted together — `docs/38-BUBBLE-TRACE.md` §4 lists both.

The file is JSONL, one event per line, and perfectly readable by eye for about
thirty lines. A real report will be several hundred, most of them uninteresting,
with the two that matter somewhere in the middle. The question is always the
same — *the button vanished; what was the last thing that happened before it
did, and did it ever come back* — and answering it by scrolling is how the
answer gets missed.

So this does three things a person reading raw JSON would do slowly:

  1. prints the **visibility changes only**, with the reason and how long each
     hidden stretch lasted;
  2. flags a **process change**, because a new pid means the service was killed
     rather than the bubble hidden, and those are different bugs;
  3. looks for the **`F-178` signature** specifically — SWIP claimed the
     foreground and never released it — because that is the bug this whole
     apparatus was built to confirm or rule out.

Point 3 is the one worth being careful about. It is tempting to have a tool
that answers "yes, it was the bug I already fixed", so the check is written the
other way round: it reports the *claim without a release*, with timestamps, and
says nothing about whether that is the cause. A tool that confirms its author's
hypothesis is not evidence.

WHAT IT CANNOT TELL YOU
-----------------------
Whether the user was looking at the phone. The trace records what the service
decided, not what was on screen — a bubble can be `VISIBLE` and behind another
app's overlay. If the file says visible and the owner says it was not, that is
a real finding and not a contradiction to explain away.
"""

from __future__ import annotations

import json
import pathlib
import sys
from datetime import datetime

# Reasons `traceVisibility` can give, in the order the service evaluates them.
REASONS = {
    "visible": "on screen",
    "screenOff": "the screen was off",
    "paymentQuiet": "a payment was in progress (90 s)",
    "swipInForeground": "SWIP itself was in front",
    "snoozed": "snoozed",
}


def parse(path: pathlib.Path) -> list[dict]:
    """Read the file, skipping anything unparseable rather than dying.

    A trace can end mid-write — the process being killed is one of the events
    worth recording, and it is the one most likely to truncate the last line.
    Refusing to read the whole file because of that would throw away the
    evidence at exactly the moment it is most interesting.
    """
    events, broken = [], 0
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            broken += 1
    if broken:
        print(f"  ({broken} unreadable line(s) skipped — a truncated last line "
              f"is normal if the process was killed)\n")
    return events


def clock(event: dict) -> str:
    """Local wall time, to the second."""
    raw = str(event.get("t", ""))
    try:
        return datetime.fromisoformat(raw).strftime("%H:%M:%S")
    except ValueError:
        return raw[11:19] or "??:??:??"


def secs(ms: int) -> str:
    if ms < 1000:
        return f"{ms} ms"
    if ms < 90_000:
        return f"{ms / 1000:.0f} s"
    return f"{ms / 60_000:.1f} min"


def summarise(events: list[dict]) -> None:
    if not events:
        print("  The file is empty. Was the trace cleared and not reproduced?")
        return

    first, last = events[0], events[-1]
    pids = sorted({e.get("pid") for e in events if e.get("pid") is not None})
    start = next((e for e in events if e.get("e") == "process.start"), None)

    print("SPAN")
    print(f"  {clock(first)} → {clock(last)}   {len(events)} events")
    if start:
        v = start.get("v", {})
        print(f"  device  {v.get('device', '?')}   SDK {v.get('sdk', '?')}")
    print(f"  process {', '.join(str(p) for p in pids)}"
          + ("   ← more than one: the app was killed and restarted"
             if len(pids) > 1 else ""))
    print()


def timeline(events: list[dict]) -> None:
    """Visibility changes, plus the events that explain them."""
    print("WHAT HAPPENED")
    shown_at: int | None = None
    last_pid = None

    # Events that are worth a line even though they are not a visibility
    # change, because they are what *causes* one.
    loud = {
        "process.start", "service.create", "service.start", "service.destroy",
        "bubble.added", "bubble.removed", "bubble.addFailed",
        "snooze.set", "snooze.end", "drag.snoozed", "tap.openScanner",
        "boot.received", "hover.finishOnStop", "start.refused",
    }

    for e in events:
        name = e.get("e", "?")
        v = e.get("v", {}) or {}
        pid = e.get("pid")

        if last_pid is not None and pid != last_pid:
            print(f"  {clock(e)}  ── process changed ({last_pid} → {pid}): "
                  f"killed and restarted ──")
        last_pid = pid

        if name == "visibility":
            why = v.get("why", "?")
            if v.get("visible"):
                held = ("" if shown_at is None
                        else f"  (hidden for {secs(e['up'] - shown_at)})")
                print(f"  {clock(e)}  SHOWN{held}")
                shown_at = None
            else:
                shown_at = e.get("up")
                print(f"  {clock(e)}  HIDDEN — {REASONS.get(why, why)}")
        elif name == "foreground":
            print(f"  {clock(e)}  SWIP in front = {v.get('inFront')}"
                  f"   ({v.get('from', '?')})")
        elif name in loud:
            extra = ""
            if name == "snooze.set":
                extra = f"  for {secs(int(v.get('forMs', 0)))}, from {v.get('from')}"
            elif name == "service.start" and v.get("restarted"):
                extra = "  ← restarted by Android, not by the user"
            elif name == "bubble.addFailed":
                extra = f"  {v.get('error')}"
            print(f"  {clock(e)}  {name}{extra}")

    if shown_at is not None:
        print("  …and it was still hidden when the trace ended.")
    print()


def unreleased_foreground(events: list[dict]) -> None:
    """`F-178`: a foreground claim with no matching release.

    Reported as an observation with timestamps, **not** as a verdict. The bug
    this looks for is one I fixed by reading the code, and a tool that
    cheerfully confirms its author's hypothesis is not evidence.
    """
    print("FOREGROUND CLAIMS")
    claims = [e for e in events if e.get("e") == "foreground"]
    if not claims:
        print("  None recorded. If the bubble was hidden with reason "
              "'SWIP itself was in front', that is worth a second look: the "
              "flag was set before this trace started.\n")
        return

    # The last claim that no later line released. Walking the whole list rather
    # than stopping at the first unmatched one, because a claim released and
    # re-claimed is ordinary — the only interesting claim is the final one.
    open_claim = None
    for e in claims:
        v = e.get("v", {}) or {}
        open_claim = e if v.get("inFront") else None

    for e in claims:
        v = e.get("v", {}) or {}
        print(f"  {clock(e)}  {'claimed ' if v.get('inFront') else 'released'}"
              f"  by {v.get('from', '?')}")

    if open_claim is not None:
        v = open_claim.get("v", {}) or {}
        print()
        print(f"  ⚠ The last claim ({clock(open_claim)}, from "
              f"{v.get('from', '?')}) was never released in this file.")
        print("    While that is true the bubble stays hidden. Whether it is "
              "the cause depends on what the timeline above shows next — it "
              "is normal if SWIP was genuinely open when the export was taken.")
    print()


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip().splitlines()[2].strip())
        return 2

    path = pathlib.Path(sys.argv[1])
    if not path.exists():
        print(f"No such file: {path}")
        return 1

    print(f"\n{path.name}\n")
    events = parse(path)
    summarise(events)
    timeline(events)
    unreleased_foreground(events)
    return 0


if __name__ == "__main__":
    sys.exit(main())
