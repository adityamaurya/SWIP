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

| Step | Deliverable |
|---|---|
| 1 | `OverlayPermissionScreen` in Flutter: explain, then `ACTION_MANAGE_OVERLAY_PERMISSION`. Off by default, with a Settings toggle |
| 2 | `SwipBubbleService` — foreground service, draggable bubble, edge snap, opacity/size settings |
| 3 | The suppression rules from §2, with a test for each |
| 4 | `BubbleScannerOverlay` — CameraX + ML Kit, the morph animation |
| 5 | Result card, and the hand-back into the app |
| 6 | Data-safety declaration and the store listing sentence above |

Steps 1–3 are the ones that decide whether this ships. Steps 4–5 are the ones
that decide whether anyone loves it.
