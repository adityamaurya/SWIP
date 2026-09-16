# 32 — The floating scan bubble

> *"i am sharing you wispr flow uis screenshots as to how it creates shortcut on
> screen and when we tap on it starts its recording … i want the user to have
> this handy entirely on screen everytime and just tap it a small camera window
> pops he scans and gets the qr code as an animation just how a message comes on
> bubble of facebook Messenger"*

This is buildable on Android, and it is the single highest-leverage feature left
— because SWIP's whole premise is *"know before you pay"*, and today that
requires leaving the checkout you are standing in.

It is also the feature most likely to get the app rejected, and the one I
previously declined. That decision is reversed here, with the reasons.

---

## 1. Why I said no before, and why the answer changes

In `F-115` I built a Quick Settings tile instead of an overlay, and the argument
was: `SYSTEM_ALERT_WINDOW` is the most invasive permission Android grants, an
app holding it can draw over your bank, and Play reviews it accordingly.

**All of that is still true. What changed is the evidence.**

Wispr Flow — a shipping, popular, Play-listed app — does exactly this, and your
screenshots show precisely how it stays on the right side of the line:

| What Wispr Flow does | What it buys them |
|---|---|
| The bubble is **off by default** and the app explains it before asking | The permission is never a surprise |
| "To use Flow in any app, allow **Display over other apps** via Settings" — a screen whose only job is to explain, then a **Go to Settings** button | Play's own recommended pattern for a special permission |
| A long, specific disclosure: *"We do not appear in sensitive fields, such as credit card forms or password fields"* | The single most important sentence for review |
| Bubble **size and opacity** are user settings | The user controls the intrusion |
| It says plainly which data it uses and that you can turn it off anytime | Data-safety alignment |

So the permission is grantable. The condition is that the app is **specific
about where it will and will not appear**, and honours it.

There is one difference that matters, and it is in SWIP's favour: Wispr Flow
also needs an **Accessibility Service** (to insert text into other apps), which
is a far heavier ask — your screenshots show Android's full "Allow full control
of your device?" warning. **SWIP does not need accessibility at all.** It draws
a bubble and opens its own camera. It never reads the screen, never types, never
touches another app's content.

That makes SWIP's version of this feature *strictly less invasive than the
reference*, which is a good position to be reviewed in.

---

## 2. The rule SWIP commits to, and enforces in code

Copied in spirit from Wispr Flow's disclosure, and narrowed:

> **The SWIP bubble never appears over a payment.**

Concretely, the bubble hides itself when:

* a UPI app, a bank app or a payment sheet is in the foreground;
* the screen is secure (`FLAG_SECURE`), which is what banking apps set;
* the keyguard is showing.

The first of those is the one that needs care: detecting the foreground app
*normally* requires usage-access or accessibility, and SWIP is not asking for
either. So it is done the other way around — **SWIP hides the bubble whenever it
did not put itself there**, using only signals it already owns:

* the bubble is hidden for 90 seconds after SWIP hands off a `upi://` intent,
  because that is exactly when a payment app is on screen;
* the bubble is hidden while the screen is locked (`ACTION_SCREEN_OFF`,
  `ACTION_USER_PRESENT`);
* a single tap on the bubble's edge dismisses it for the session.

This is deliberately conservative: it errs towards the bubble being absent. An
absent bubble costs one extra tap. A bubble over a PIN pad costs the app.

---

## 3. What it is made of

| Piece | Android API | Notes |
|---|---|---|
| The bubble | `WindowManager` + `TYPE_APPLICATION_OVERLAY` | 56 dp circle, draggable, snaps to the nearest edge like Messenger |
| Staying alive | A **foreground service** with a low-priority notification | Required since Android 8; the notification is the honest cost |
| Permission | `SYSTEM_ALERT_WINDOW`, requested via `ACTION_MANAGE_OVERLAY_PERMISSION` | Cannot be granted by a normal dialog. Needs the explain-then-send-to-Settings screen |
| The camera window | A second overlay, ~240 dp, `CameraX` + ML Kit barcode | **Not Flutter.** A Flutter engine in an overlay is heavy and slow to start; this must open in well under a second |
| The result | Overlay card, animated in, showing the four digits and the RuPay verdict | Same logic as the in-app sheet, via a small shared Kotlin model |
| Handing back | Tap the card → opens SWIP with the payload | The full sheet, the ledger row, the merchant graph |

### Why the camera window is native and not Flutter

This is the one architectural decision worth arguing. A `FlutterEngineGroup`
overlay is possible and would let the existing Dart sheet be reused. It is also
~400–700 ms to first frame on a mid-range phone, and this feature lives or dies
on feeling instant. So the overlay is CameraX + ML Kit in Kotlin, and it does
**only** the scan; every payload is handed to Dart for resolution, so there is
exactly one MCC parser in the codebase and it is the tested one.

---

## 4. The animation, since that is what was actually asked about

> *"major fascinating is how they have perfected the floating shortcut and the
> animation"*

Four states, and the transitions between them are the whole feature:

1. **Resting** — 56 dp, snapped to an edge, 70 % opacity, the SW/P slash only.
2. **Pressed** → the circle scales to 0.92 and back over 120 ms. Nothing else.
   The delay before the camera opens is the thing to hide, and a press
   animation is how you hide it.
3. **Opening** — the circle *becomes* the camera window: a shared-element
   morph, circle → rounded rect, 280 ms on `easeOutCubic`, with the camera
   preview fading in at 40 % through. It must read as one object changing
   shape, not two objects swapping.
4. **Result** — the card rises 12 dp with the four digits, then the whole thing
   collapses back to the circle after 4 s or on tap-away.

Messenger's chat head is the drag model to copy: velocity-aware edge snapping,
and a delete target that appears at the bottom on drag. Wispr Flow's bubble is
the *presence* model: always there, never in the way, low opacity until touched.

### What was actually built, and the gap `F-170` closed

**This section was right and the implementation drifted from it, in the two
places that mattered most.** Worth recording plainly, because the correction
took a round of the owner's time that a re-read of this page would have saved.

| §4 said | `F-158` shipped | `F-170` |
|---|---|---|
| 56 dp | **48 dp** | 56 dp |
| "velocity-aware edge snapping" | `OvershootInterpolator`, `duration = 260` — **velocity was never read** | `VelocityTracker` → `SpringAnimation` |
| Pressed: 0.92 over 120 ms | as written | a scale spring, because a tap shorter than 120 ms made the two fixed animations fight |

The middle row is the one the owner felt. *"Too much sticky type
experience"* is an exact description of a fixed duration: the bubble took
260 ms to reach the edge whether it was flicked across the screen or nudged a
centimetre, so the motion was unrelated to the gesture that caused it.

A `SpringAnimation` has no duration to set — only a rest position, a stiffness,
a damping ratio and a **start velocity**, which comes straight from the
`VelocityTracker` watching the finger. That is the whole difference between an
object you are holding and an animation being played at you.

`androidx.dynamicanimation` is the library, chosen after reading what the
open-source chat heads do:
[springy-heads](https://github.com/flipkart-incubator/springy-heads) (Flipkart,
spring physics), [floaty_chatheads](https://github.com/Crdzbird/floaty_chatheads)
(Facebook Rebound — the library Facebook wrote *for* chat heads),
[bubbles-for-android](https://github.com/txusballesteros/bubbles-for-android),
[Android-ChatHead](https://github.com/henrychuangtw/Android-ChatHead). They all
reach for the same idea; Android has since absorbed it first-party, which is
~50 KB and no third-party animation runtime in an app that does not phone home.

**Re-checked in prompt 44, and the check changed the argument.**
`springy-heads` is unmaintained and its README points at
[google/hover](https://github.com/google/hover), which Google **archived in
January 2023**. The two best-known chat-head libraries are both dead. Taking
either would have meant inheriting abandoned code, so a decision made on
dependency-weight grounds turns out to have been the right one for a second
reason nobody knew at the time. The full survey — including the living
alternatives, the Flutter overlay plugins SWIP did *not* take, and why the
official Bubbles API is closed to this app — is
[`docs/39`](39-FLOATING-OVERLAY-PRIOR-ART.md).

Three behaviours came with it that §4 had not asked for and Messenger has:

* **Pop-in.** The bubble spends most of its life hidden — behind a payment,
  behind SWIP, behind a snooze — so the moment it *returns* is the moment
  anyone sees, and it was a hard cut. It springs up from 60 % now.
* **Direction beats distance.** Above `scaledMinimumFlingVelocity` the throw
  picks the edge. The old midpoint rule sent a leftward flick from the
  right-hand half straight back to the right, which reads as the app refusing
  the gesture.
* **Interruptible.** Grab it mid-flight and the finger wins; the springs are
  cancelled on touch-down and re-aimed rather than rebuilt, so they keep their
  velocity.

`F-173` built the target from §4, as a **snooze** target rather than a delete
one — see §12. Still not built: the circle→camera shared-element morph. The morph cannot be done as written while the scanner is
a separate transparent Activity with its own Flutter engine — see §10.

---

## 5. Play policy, precisely

`SYSTEM_ALERT_WINDOW` is a **special permission**, not a dangerous one. Google
does not forbid it; it requires that it be justified by the core functionality.

The declaration SWIP makes:

> SWIP shows a floating button so you can check a shop's category code without
> leaving the app you are in — which is the entire purpose of the app, and is
> useless if you have to switch away from the checkout to do it. The button
> opens SWIP's own camera. SWIP never reads the contents of other apps, never
> requests accessibility access, and hides the button whenever a payment app is
> in the foreground.

The last sentence is the one that gets it approved, and it is only true if §2 is
actually implemented.

**On iOS this feature cannot exist at all** — no overlay API — see
[31-IOS-AND-IPA §2.4](31-IOS-AND-IPA.md).

---

## 6. Build order

| Step | Deliverable | State |
|---|---|---|
| 1 | `OverlayPermissionScreen` in Flutter: explain, then `ACTION_MANAGE_OVERLAY_PERMISSION`. Off by default, with a Settings toggle | **Done** `F-131` |
| 2 | `SwipBubbleService` — foreground service, draggable bubble, edge snap | **Done** `F-158` |
| 3 | The suppression rules from §2 | **Done** `F-158` |
| 4 | The scanner, over other apps | **Done** `F-163` — but **not** as `BubbleScannerOverlay`. See §10 |
| 5 | Result card, and the hand-back into the app | ◑ the result opens full-screen rather than inside the card. `F-163` |
| 6 | Data-safety declaration and the store listing sentence above | Open, and it is a Play Console task rather than a code one |

Opacity and size controls were listed against step 2 and are **not built**.
The line promising them has been removed from the screen rather than left
standing — see §8.

---

## 7. Why step 1 shipped and nothing happened for four months

This is the part worth keeping, because the failure was invisible from every
angle except the one nobody looked from.

`F-131` delivered step 1 completely and well: the screen explains the
permission before asking for it, which is the thing that decides whether a
`SYSTEM_ALERT_WINDOW` request is ever granted. The manifest declared
`SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE` and
`FOREGROUND_SERVICE_SPECIAL_USE`. The Settings screen had a switch. The switch
worked — it moved, and it stored its answer.

**It stored it in `SharedPreferences['swip.bubble.enabled']`, and nothing in
the project ever read that key.** There was no service, no overlay, no window,
and nothing registered in the manifest to draw one. The permission was
granted, the switch went on, and Android was never asked to draw anything.

Two things hid it:

* **The permissions were already declared.** Everything around the feature
  existed, which is what made it look finished from the manifest.
* **The switch could not be wrong.** It set a boolean and displayed the boolean
  it had set. A screen that is its own source of truth is internally consistent
  no matter what the platform is doing, so no test could catch the gap — and
  none did.

The fix for the second one is structural rather than a bug fix: the wish now
lives with `SwipBubbleService`, the screen asks over the method channel, and
`bubble_settings_test.dart` asserts on **what reaches the channel** rather than
on what the widget remembers.

---

## 8. The promise that was removed

The bubble screen used to say:

> *"Size and see-through-ness are yours to set, and one flick sends it away for
> the rest of the day."*

There are no such controls and there never were. It is deleted rather than
kept pending, because that screen is a privacy disclosure whose entire job is
to be believed, and a line it does not keep costs more than the feature it
describes would have been worth.

The three lines that remain are each enforced somewhere that can be read:

| Line | Enforced at |
|---|---|
| Never over a payment | `MainActivity.forwardUpiIntent` and `openExternal` signal `ACTION_PAYMENT_STARTED`; the service goes quiet for 90 s |
| Never while locked | `ACTION_SCREEN_OFF` in `SwipBubbleService`'s receiver |
| Cannot read your screen | Structural — SWIP requests no Accessibility Service, so there is no mechanism |

Two were added, because they are true and were being discovered rather than
told: the ongoing notification Android requires, and that the bubble does not
survive a reboot until SWIP is next opened.

---

## 9. Why the camera was not in the overlay, and what happened instead

This section used to say the in-overlay camera was blocked because CameraX and
ML Kit are Gradle dependencies and `android/app/build.gradle` is regenerated by
`flutter create` inside [`tool/bootstrap.sh`](../app/tool/bootstrap.sh).

That was true, and it was **my problem rather than the owner's** — the script
doing the regenerating is in this repository, and §4b2 of it had been
re-injecting a `compileSdk` override for the same reason since the file_picker
collision. `F-161` added `SWIP_GRADLE_DEPS`, which ends the blocker.

`res/` **is** restored by bootstrap (lines 70–80 of that script), which is why
the drawables, strings and the hover theme are safe.

---

## 10. What was built instead, and why it is better

`F-163` did not build `BubbleScannerOverlay`. With the blocker gone, that was
a free choice, and this is the reasoning.

**A native overlay scanner would be a second implementation of scanning.**

SWIP's scanner is not a camera and a barcode library. It is
[`ScanPage`](../app/lib/features/capture_qr/scan_page.dart) plus the aim
detector, the `noDuplicates` single-slot trap in [`CLAUDE.md`](../CLAUDE.md),
the resolver, the merchant graph, the ledger write and the result screen —
several rounds of behaviour, most of it recorded in
[`29`](29-QR-DETECTION-FORENSICS.md) *because it was wrong first*. A Kotlin
twin of all that would be correct on the day it was written and would drift
from the original by the round after, in ways nobody would notice until a
shop's code read differently depending on which surface you scanned it from.

So the scanner is **hovered rather than re-made**:
[`SwipHoverActivity`](../app/android/app/src/main/kotlin/in/swip/app/SwipHoverActivity.kt)
is a transparent Activity in its own task, and
[`hover_scan.dart`](../app/lib/features/bubble/hover_scan.dart) paints a card
over the app underneath with `ScanPage` **itself** inside it.

### The three things that make it transparent

None is optional, and getting any one wrong produces a **black card rather
than an error**:

| | Where |
|---|---|
| `windowIsTranslucent` + a transparent window background | `res/values/swip_hover_styles.xml` |
| `BackgroundMode.transparent` | `SwipHoverActivity.getBackgroundMode()` |
| `Scaffold(backgroundColor: Colors.transparent)` | `hover_scan.dart` |

Android decides translucency **when the window is created**, which is why this
is a separate Activity rather than a mode of `MainActivity`.

### What it gives up

**The app underneath is visible but paused.** A true overlay window would not
pause it — a video behind the card will hold still. For a two-second glance at
a QR while somebody waits to be paid, that is worth far less than having one
scanner instead of two.

**It runs a second Flutter engine**, started cold on each tap: roughly half a
second before the card appears, and some tens of megabytes while it is open.
Both end when the window closes. A cached warm engine would remove the delay
and pay that memory *the whole time the bubble is switched on*, which for a
button that sits idle all day is the wrong trade.

### Still rough

After a successful scan the result page fills the screen rather than staying
inside the card, and dismissing it returns to the card rather than to the app
underneath. Two dismissals where one would do. Worth tidying; not worth
rushing into the round that first made the window work.

---

## 11. The goodbye that nobody had ever seen

`F-167` gave the bubble a long-press snooze and, in the same commit, a promise:

> *"Say so, in the bubble itself, in the moment before it goes. A button that
> silently disappears when held reads as a bug."*

The string exists (`swip_bubble_snoozed`), the `peek()` call is there, the
handler runs. **It has never been visible.** The handler peeks the message and
then calls `applyVisibility`, which finds the snooze in storage and sets the
window `GONE` — on the same frame. The pill was shown and taken away before a
single frame had been drawn with it in.

Reordering the two calls does not fix it: `snooze()` also broadcasts, and the
receiver arrives a few milliseconds later and hides the bubble anyway. The only
place that can honour "say goodbye first" is the method that does the hiding,
so `show()` now refuses to hide while a `goodbyeUntil` deadline is in the
future and re-checks when it passes.

**This is the same shape as `F-131`, `F-157` and `F-169` — the fourth time.**
Every piece present, correct and tested; the join missing. `check_wiring.py`
cannot see this one either: nothing is unimported, no channel is unhandled, no
preference is unread, no callback is unsupplied. What is wrong is an ordering
between two method calls in the same file, both of which do exactly what they
say.

The general lesson, which is the useful part: **whenever a feature's value is
that the user *sees* something, ask what else runs on that frame.** Three of
the four were caught by a gate written after the fact; this one was caught by
reading the sequence out loud.

---

## 12. Snooze, rebuilt — `F-173`

> *"the snooze button ux is unfurnished, on holding the launcher icon it
> gltiches and is not smooth animating… we need snoozing mechanism where in i
> drag and drop the launcher icon to the center… it should snooze for 10mins by
> default and if I shake the phone it should be back"*

### The glitch had a cause, and it was the gesture

A long-press timer fires **under a finger that may still be about to drag**, so
it has to guess what the gesture will become. When it guessed wrong the handler
ran a text peek, a re-anchor spring and a scale kick — on a view whose press
spring was still settling. Four animations, one view, one frame.

So the long-press is **deleted rather than smoothed**. A drag onto a target
cannot be mistaken for anything else, because by the time the target appears
the gesture has already declared itself. §11's goodbye machinery survives
intact; it now protects the swallow animation rather than a line of text.

### The shape

| | |
|---|---|
| **Appears** | when a drag is recognised — not on touch-down, or a tap would flash it for a frame every time the scanner opened |
| **Where** | horizontally centred, above the bottom edge |
| **Armed** | when the bubble's **centre** is within 64 dp of the target's centre; the target grows to 1.3, the bubble shrinks to 0.7, and the phone buzzes once |
| **Dropped** | the bubble is sprung into the target and scaled to nothing |
| **Says** | a system toast: how long, and how to end it early |

**Distance between centres, not rectangle intersection.** A 56 dp bubble and a
72 dp target touch corners long before the gesture looks like a drop, so
intersection arms far too eagerly and the bubble cannot be dragged past the
bottom of the screen without snoozing.

### Why not the true centre of the screen

The prompt says *"to the center"*, and horizontally that is exactly what this
is. Vertically it sits above the bottom edge, and that is a correction worth
stating rather than making quietly:

**The middle of the screen is where the bubble passes through on almost every
ordinary drag.** Moving it from one side to the other — the most common thing
anyone does with it — goes straight through the centre. A target there would
swallow it constantly by accident. Every chat-head implementation puts the
target near the bottom for this reason, and it is also where a thumb already
is.

### A crescent, not Messenger's X

Messenger's target carries an X because dropping a chat head there **closes the
conversation**. SWIP's closes nothing — the button hides for ten minutes and
comes back on its own. An X would promise a destruction that does not happen,
and the first person to drop the bubble expecting it gone for good would have
been told something untrue by an icon.

### Ten minutes, and the way back

*"Until tomorrow"* is replaced, and the length is the smaller half of that
change. **A snooze until tomorrow had to be undone** — there was no gesture
meaning *actually, come back*, so the only way out was to open SWIP and find a
switch. Ten minutes ends by itself, which is what makes it safe to offer as a
one-handed drag rather than something to be sure about.

Shake to end it early is `SensorManager`, registered **only while snoozed**. A
floating button that listens to the accelerometer all day is a battery
complaint; one that listens for the ten minutes it is deliberately hiding is
not. `applyVisibility` arms and disarms it, because that method already reads
the snooze from storage on every broadcast and nudge — anywhere else would be a
second source of truth for the same fact.

### The first thing about this bubble that is tested

[`ShakeDetector`](../app/android/app/src/main/kotlin/in/swip/app/ShakeDetector.kt)
has **no Android imports at all**, which is what lets it run on the JVM in CI.
Every round before this one ended by admitting the APK job proved the bubble
compiled and nothing proved it behaved.

It is aimed where being wrong is invisible. Too sensitive and the bubble
returns while the user is walking — undoing something they deliberately asked
for. Too dull and shaking does nothing, and they cannot tell whether they shook
it wrong or the feature is broken. Neither throws, logs or fails a build.

The algorithm is deliberately not *"is the phone moving"*: a single spike
cannot be told from a drop or a jog. A sample over 2.3 g is a **hit**; three
hits inside 1,200 ms is a shake; and a 150 ms debounce stops one swing counting
several times, which is the bug that makes naive detectors fire when you set
the phone on a table.

**Still not tested:** the drag, the swallow, the target's window lifecycle.
`ShakeDetector` was extractable because it is arithmetic; a `WindowManager`
overlay is not, without instrumentation and a device.

---

## 13. Why it disappeared — `F-178`, and the recorder that found it

> *"sometimes, the launcher icon disappears. This seems to happen either when
> you open the SWIP app or randomly while using certain other apps."*

**Two different things, and only one of them was a bug.**

### The half that is by design

§2. The bubble is never over SWIP's own scanner — a disc on the app's own
viewfinder is a smudge on it. Opening SWIP hides the button; leaving brings it
back. That is `appInForeground`, working.

### The half that was a bug

`MainActivity` has always claimed and released the foreground flag in
`onResume` / `onPause`. `SwipHoverActivity` claimed it in **`onCreate`** and
released it in **`onDestroy`**.

Those are not a pair. Press Home with the hovering card open and Android
*stops* the Activity rather than destroying it, so:

1. `onDestroy` never runs;
2. `appInForeground` stays `true`;
3. `applyVisibility` hides the bubble on every later evaluation;
4. and the card is `excludeFromRecents`, **so the user cannot get back to it to
   close it.**

Alive, invisible, unreachable, holding the button down. The only escape was
opening SWIP and leaving again, because `MainActivity.onPause` clears the same
flag — which is exactly the workaround somebody would stumble into and then be
unable to explain.

### The fix, in two parts

| | |
|---|---|
| `onResume` / `onPause` | The claim and its release in the **same** pair of hooks |
| `finish()` in `onStop` | A window nobody can navigate back to should not survive backgrounding while holding a camera and a second Flutter engine |

`onStop`, not `onPause`: a permission dialog pauses this Activity without
stopping it, and finishing the card out from under the camera prompt would be a
new bug in place of the old one.

### The general shape, which is the part worth keeping

**Two components reporting the same fact through different lifecycle hooks will
disagree, and the disagreement will be silent.** Nothing throws when a flag is
set and never cleared — the only symptom is a feature that stops working for
reasons nobody can reproduce on demand.

### And the recorder stays on

[`docs/38`](38-BUBBLE-TRACE.md). `BubbleTrace` writes every visibility decision
with its reason and all four inputs, so the next report comes with a file
instead of a description. **One plausible cause found by reading is not the same
as the cause confirmed by watching**, and the honest way to close this is an
export showing the bubble surviving the sequence that used to kill it.

It is gated on `FLAG_DEBUGGABLE` and cannot reach a Play Store build, and it
gets deleted once the cause is confirmed.

---

## 14. Where it comes back to — `F-180`

> *"once it gets snoozed but again after opening recent app launcher it
> reappears into the center of the screen"* — prompt 47, with a screenshot of
> the bubble sitting in the middle of a web page

### What was actually happening

**The bubble did not travel to the middle of the screen. It had been parked
there, invisibly, since the moment it was snoozed.**

[`swallow`](../app/android/app/src/main/kotlin/in/swip/app/SwipBubbleService.kt)
is the animation that makes the snooze gesture feel like a gesture: the bubble
is pulled into the target and shrinks to nothing. It does that by aiming the
same two springs every other move uses at the target's centre — and the target
sits at `heightPixels - targetSize - 132dp`, horizontally centred.

Then the window is hidden. **Nothing ever moved it back.** Ten minutes later
`applyVisibility` showed the window at the last coordinates anything had
written, which were the target's.

So the position was wrong the entire time it was hidden, and hidden is exactly
when nobody can see that it is wrong. The owner's screenshot puts the bubble at
centre-x, a little above the bottom third — which is the snooze target's own
coordinates, read off the screenshot and matched to the arithmetic.

### Why the fix is a remembered position and not a default one

Snapping to a fixed corner would have been one line and would have been the
same complaint with a different coordinate. This is a button the user drags to
where they want it; coming back from a snooze somewhere else is the bug either
way.

So `restY` records where the bubble settles — written from `windowY`'s setter,
which every settle, fling and re-anchor passes through — and `swallowed` gates
that recorder off for the duration of the swallow, because otherwise the
swallow's own frames would overwrite the place the bubble is meant to be
rescued from. X needs no memory: it is always one of two edges and
`parkedRight` already knows which.

`restorePark` runs from `show(true)` **while the window is still `GONE`**, and
assigns rather than springs. A spring there would start at bottom-centre and
fly across the screen in full view — a more elaborate version of the same bug.

### The arithmetic is now testable

[`BubblePark.kt`](../app/android/app/src/main/kotlin/in/swip/app/BubblePark.kt)
— pure Kotlin, no Android imports, same split as `ShakeDetector` and for the
same reason. Everything else about the bubble's position runs through
`WindowManager` and cannot be exercised without a device, so these numbers had
never been checked by anything.

`coerceIn(min, max)` **throws when `max < min`**, and every maximum here comes
from a live screen measurement. A freeform window or a foldable read while
closed can be shorter than the bubble plus its two gaps, and that exception
would be thrown from a touch handler on a window the user cannot dismiss.
`BubbleParkTest` has the degenerate screen as a test rather than a comment
claiming it was considered, plus a sweep over five screen heights and seven
remembered positions asserting the result is always inside the legal strip.

`snapToEdge`, `reanchor` and `restorePark` now share `edgeX` and `lowestY`.
They used to compute the bounds separately, which is survivable while two of
them run one after the other and invisible when the third runs ten minutes
later.

### The general shape

**A position written while a window is hidden is a position nobody can see is
wrong.** The same is true of any state changed during a transition out: the
next appearance is the first chance anyone has to notice, and by then the cause
is long gone from the screen and from memory.

---

## 15. The half that `F-180` missed — `F-184`

> *"there you go deepdive and find for any bug if there is any"* — prompt 49,
> with a fresh export

§14's fix was the round's deliverable, and the export sent to confirm it
contains this:

```
bubble.restored   x=18   y=1768
bubble.restored   x=18   y=1753
```

The phone is 2229 px tall. The snooze target sits at **y = 1770**.

So the X was right — 18 px is the left edge — and **the Y was the target**,
which is the exact thing §14 was written to stop. `F-180` had fixed half of it,
and the remaining half said the same wrong thing more quietly: not
bottom-*centre* any more, so the screenshot no longer looks obviously wrong.

### Why the recorder was still reading the swallow

`restY` is written from `windowY`'s setter, and `swallowed` was supposed to
gate that off for the swallow's duration. It did. What it did not cover is the
**drag that precedes the swallow** — the user's own finger, dragging the bubble
down onto the target, one `ACTION_MOVE` at a time, each one a perfectly
ordinary settle as far as the recorder is concerned.

By the time `swallow` starts and the gate closes, `restY` has already been
walked down to within a few pixels of the target by the gesture itself.

**The gesture that means *"put this away"* was also saying *"and remember this
is where it lives"*.** Those are two different statements and one drag was
making both.

### The fix

`DragAndTap` captures `preDragY` at `ACTION_DOWN`, next to the `startY` it
already records for the slop test — the position the bubble was resting at
*before the finger arrived*. `swallow(bubble, centre, undoY)` takes it and sets
`restY = undoY` as its first act, before a single frame of animation runs.

A drag that ends anywhere other than the target is unaffected: it settles
normally and the setter records where it settled, which is correct and is the
whole point of §14.

### The shape, which is §14's with one more turn

A position written while a window is hidden is a position nobody can see is
wrong — **and the frames immediately before it goes are part of "hidden"**, because
nobody is reading a coordinate during a gesture either. The interesting
question is not *"what happens while it is invisible"* but *"what was the last
thing to write this, and was that thing about where it lives or about where it
was going"*.

---

## 16. The fan, and the label that was lying — `F-185`

> *"Once you click the launcher icon, it is not bouncy enough. It opens as
> something called 'scanning.' It's actually not scanning, right?"*
>
> *"its also becoming square when I drag it closer it should become enlarge a
> bit and be corcle only not become rounded rectangle"* — prompt 49

**Two reports, one mechanism.**

### The label

Tapping the bubble called `peek()`, which made a `TextView` visible with the
word *"Scanning…"* in it and hid it again half a second later.

Nothing was scanning. `SwipHoverActivity` had not started, its second Flutter
engine had not started, and CameraX was some way behind that. The label existed
to fill the gap — which is a reasonable thing to want, and naming the gap
something it is not is not a reasonable way to do it. The owner spotted it
immediately, from the outside, with no access to the code.

### The circle

`swip_bubble_bg.xml` was a `rectangle` with `<corners android:radius="28dp"/>`,
and the bubble is 56 dp. A rounded rectangle whose radius is exactly half its
height **is** a circle — but only while it is square. Showing a word widened a
`WRAP_CONTENT` `LinearLayout`, and a 56 dp-tall row wider than 56 dp with a
28 dp radius is a pill.

So the rounded rectangle was never a styling choice, and no amount of adjusting
the radius would have fixed it. It was the label.

Deleting `peek()` removed the only thing that could change the view's width,
which is what allowed the drawable to become `android:shape="oval"` — **round
by construction**, rather than by two numbers being kept in agreement forever.
`check_wiring.py`'s rule changed with it, from a radius-versus-diameter
comparison to a shape check. That is stronger: a number can drift and a shape
cannot.

### What the tap does instead

Two discs spring out from the bubble, 68 dp apart, staggered 45 ms, while the
bubble's own glyph cross-fades to a cross:

| | |
|---|---|
| **Scan a code** | The hovering scanner, as before |
| **Tap a card machine** | Straight to the in-app POS screen |

SWIP has had two capture vectors since `F-140` and the bubble only ever offered
one of them. The fan is not decoration — it is the second door, which existed
and had no handle out here.

It closes on a second tap, on either choice, on a drag, when the bubble hides,
and on a 6 s idle timeout. That last one matters more than it sounds: this is a
window over somebody else's app, and a menu left open on top of a payment
screen is exactly the intrusion [§2](#2-the-rule-swip-commits-to-and-enforces-in-code)
promises not to be.

---

## 17. Feeling the edge — `F-186`

> *"can you add haptic feedback for the bubbles? Whenever I move it to either
> of the ends"*

A `HapticFeedbackConstants.CLOCK_TICK` on the edge spring's **end listener**,
not on the finger's release.

That distinction is the whole design. Buzzing when the finger lifts is feedback
about the finger — which the finger already knows about, because it is the
thing that just moved. Buzzing when the bubble **lands** is feedback about the
bubble, which by then is somewhere off under a thumb and has no other way to
report that it arrived.

Skipped when the animation is `canceled`: a cancelled snap is one the user
grabbed again mid-flight, and it never landed. A tick there would be the phone
insisting something finished when the user can see it did not.

### The listener has to be able to remove itself

`DynamicAnimation.OnAnimationEndListener` is added to a long-lived, reused
spring ([§4](#4-the-animation-since-that-is-what-was-actually-asked-about) —
never rebuild one), so a listener added on every snap and never removed is a
leak that fires N times on the Nth snap.

Removing it needs a reference to itself, which a lambda passed straight as an
argument does not have. So it is a SAM conversion held in a `var` declared one
line above, assigned, then added — and its first act when it runs is
`removeEndListener(tick)`.
