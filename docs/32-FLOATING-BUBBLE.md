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

Still not built from §4: the **delete target**, and the circle→camera
shared-element morph. The morph cannot be done as written while the scanner is
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
