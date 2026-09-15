# 39 — Floating overlays: who else has built one

> *"can you go on internet and find the floater idea opensourced projects just
> surrounding the floating icon idea by dev people made, make a list of it and
> share the links"* — prompt 44

Searched and **verified on 15 Sep 2026**: every star count, licence and
maintenance note below was read off the repository page, not recalled. Star
counts move; the maintenance status is the part that matters and is the part
most likely to be stale when you read this.

---

## 1. The headline finding: the two most-cited chat-head libraries are both dead

`F-170` cited these in code and in [`32` §4](32-FLOATING-BUBBLE.md) as the prior
art behind SWIP's spring physics. Going back to look:

| Project | Stars | State |
|---|---|---|
| [flipkart-incubator/springy-heads](https://github.com/flipkart-incubator/springy-heads) | 368 | **Unmaintained.** Its README says so at the top and points at Hover |
| [google/hover](https://github.com/google/hover) | 2.6k | **Archived by Google, 10 Jan 2023.** Read-only |

Hover is the more interesting of the two and worth reading even archived: it is
a floating *menu* rather than a bubble — multi-section tabs, collapsed /
expanded / closed states, drag-and-dock with saved position, drag-to-close —
built on a state-pattern architecture. If SWIP's bubble ever grows a second
action beyond "scan", that is the design to read first.

**This retrospectively justifies a decision made for a different reason.**
`F-170` took `androidx.dynamicanimation` — Android's own spring and fling
animators — rather than adopting a chat-head library, on the grounds that a
first-party 50 KB dependency beats a third-party animation runtime in an app
whose selling point is that it does not phone home. It turns out both candidate
libraries were already abandoned. Taking either would have been inheriting dead
code.

---

## 2. Android, native views — the closest living analogues

| Project | Stars | Lang / Licence | Why it matters to SWIP |
|---|---|---|---|
| [dofire/Floating-Bubble-View](https://github.com/dofire/Floating-Bubble-View) | 263 | Kotlin · Apache-2.0 | **The closest thing to what SWIP built.** Draggable bubble, edge-snap animation, and an `ExpandableBubbleService` that transitions bubble → expanded panel — which is exactly SWIP's bubble → hovering card. Has `DYNAMIC_CLOSE_BUBBLE` and `FIXED_CLOSE_BUBBLE` behaviours, i.e. our snooze target, and both XML and Compose |
| [luiisca/floating-views](https://github.com/luiisca/floating-views) | 22 | Kotlin · MIT | Small, but the **design is the same shape as ours**: a main float, a *close float* you drag onto, and an expanded float with configurable `dimAmount` and tap-outside-to-close. Springs are declarative with `dampingRatio` and `stiffness` — the same two knobs `F-170` reached for |
| [txusballesteros/bubbles-for-android](https://github.com/txusballesteros/bubbles-for-android) | 1.5k | Java · Apache-2.0 | The classic. Has a configurable **trash layout** via `setTrashLayout()` — the ancestor of every drag-to-remove target since. 26 commits total; old, but no archive notice |
| [only52607/compose-floating-window](https://github.com/only52607/compose-floating-window) | 93 | Kotlin · Apache-2.0 | Global overlay windows built entirely in Jetpack Compose, with `Modifier.dragFloatingWindow()`, ViewModel support and a `LocalComposeFloatingWindow`. The modern-Android answer to the same problem |
| [hyuwah/DraggableView](https://github.com/hyuwah/DraggableView) | — | Kotlin | Just the dragging: wraps a view, overrides its touch listener. Useful as a reference for the gesture in isolation |
| [Breens-Mbaka/Floaty](https://github.com/Breens-Mbaka/Floaty) | — | Kotlin | Small floating widget; closes via a broadcast receiver |
| [javaherisaber/FloatingOverlayView](https://github.com/javaherisaber/FloatingOverlayView) | — | Kotlin | Minimal `SYSTEM_ALERT_WINDOW` overlay |

---

## 3. Flutter — the road SWIP did not take

These render **Flutter itself into an overlay window**. SWIP instead opens a
**transparent Activity** — [`32` §10](32-FLOATING-BUBBLE.md) and the header of
`hover_scan.dart` explain why — so this is the live alternative to a design
decision already made, and the trade-off is worth having written down.

| Project | Stars | Licence | Note |
|---|---|---|---|
| [X-SLAYER/flutter_overlay_window](https://github.com/X-SLAYER/flutter_overlay_window) | 146 | MIT | Android only. Runs a **separate Flutter entrypoint** (`@pragma("vm:entry-point")`) in the overlay. Click-through and focus flags, drag support, and a data channel between overlay and app |
| [jiusanzhou/flutter_floatwing](https://github.com/jiusanzhou/flutter_floatwing) | 183 | Apache-2.0 | Same idea, stated plainly: *"a Flutter engine that runs a widget via `runApp` and a view that is added to the Android window manager"* |
| [Crdzbird/floaty_chatheads](https://github.com/Crdzbird/floaty_chatheads) | — | — | Federated plugin, draggable chat heads with expandable Flutter panels. Cited in `F-170` as the Facebook Rebound reference |
| [pvsvamsi/SystemAlertWindow](https://github.com/pvsvamsi/SystemAlertWindow) | 130 | Apache-2.0 | Truecaller-style. Notable for **falling back to the native Bubbles API on Android 11+ and Android Go** rather than drawing an overlay — see §4 |

### What SWIP would gain, and lose, by switching

**Gain: a true overlay.** A `TYPE_APPLICATION_OVERLAY` window does not pause
the app behind it. SWIP's transparent Activity does — Android stops delivering
frames to the window underneath, so a video behind the hovering card holds
still. That is the one thing the current design gives up, and it is named as
such in `hover_scan.dart`.

**Lose: one scanner.** SWIP's card contains `ScanPage` *itself* — the aim
detector, the `noDuplicates` trap in `CLAUDE.md`, the resolver, the merchant
graph, the ledger write and the result sheet. These plugins each run a second
Flutter engine with a **separate entrypoint**, so the overlay's widget tree is a
different tree with different providers. It is buildable, and it would be a
second implementation of scanning that drifts from the first by the round after.

Not a reason to rule it out for ever — a reason it was not taken, recorded so
the next person does not re-derive it.

---

## 4. The official route, and why SWIP cannot use it

[Notification bubbles](https://developer.android.com/develop/ui/compose/notifications/bubbles)
are Android's *blessed* floating UI. No `SYSTEM_ALERT_WINDOW`, no foreground
service, no permission screen — the system draws and manages the bubble.

**SWIP does not qualify.** Read at source rather than taken from a summary,
because this claim is load-bearing enough to be in `CLAUDE.md`:

> *"If an app targets Android 11 (API level 30) or higher, a notification
> doesn't appear as a bubble unless it meets the conversation requirements."*
>
> *"If targeting Android 11 (API level 30) or higher, make sure the bubble
> metadata or notification references a sharing shortcut."*

SWIP has no conversations and no people; it has a shop code. Declaring a fake
sharing shortcut to borrow the API would misrepresent the app to the system and
to Play review.

### The pre-API-30 exception, and why it does not help

The first version of this section said flatly that bubbles are scoped to
conversations. **That is only true from API 30.** On API 29 and below the docs
list three ways in, and the third has nothing to do with conversations at all:

> * *"The notification uses `MessagingStyle` and has a `Person` added."*
> * *"The notification is from a call to `Service.startForeground`, has a
>   `category` of `CATEGORY_CALL`, and has a `Person` added."*
> * *"The app is in the foreground when the notification is sent."*

So on old Android any notification could bubble — **provided the app was in the
foreground.** Which is exactly inverted from what SWIP needs. The whole purpose
of the floating button is to be there when SWIP is **not** in front; `docs/32`
§2 goes further and hides it deliberately whenever SWIP *is*. The one legacy
loophole is open precisely in the state where SWIP does not want a bubble, and
closed in every state where it does.

So the conclusion stands and is now exact: the overlay permission is not a
shortcut taken around a nicer API — it is the only route open to this kind of
app, on every Android version, for two different reasons. Worth knowing when
the permission screen has to justify itself.

Samples, for reference:

* [googlearchive/android-Bubbles](https://github.com/googlearchive/android-Bubbles) — Google's own, archived
* [MonikaJethani/Todo_Bubbles](https://github.com/MonikaJethani/Todo_Bubbles)
* [iambaljeet/AndroidBubbleDemo](https://github.com/iambaljeet/AndroidBubbleDemo)

Browse further: [`github.com/topics/chat-head`](https://github.com/topics/chat-head),
[`github.com/topics/notification-bubbles`](https://github.com/topics/notification-bubbles),
[`github.com/topics/bubble`](https://github.com/topics/bubble)

---

## 5. What is worth stealing

Read in order of how much they would change:

1. **[dofire/Floating-Bubble-View](https://github.com/dofire/Floating-Bubble-View)'s
   `ExpandableBubbleService`.** SWIP's bubble → card transition is currently two
   windows and an Activity boundary. Theirs is one service with two states. If
   the half-second cold start of the second Flutter engine ever has to go, this
   is the shape that removes it.
2. **[luiisca/floating-views](https://github.com/luiisca/floating-views)'s close
   float.** Ours arms on distance between centres and grows to 1.3; theirs has a
   `closeBehavior` that can snap *the close float to the main float* rather than
   the other way round. A small idea and a nicer one.
3. **[google/hover](https://github.com/google/hover)'s state pattern.** SWIP's
   visibility logic is four booleans evaluated in one method — fine for four,
   and `F-176` exists because the *reason* among them was invisible. If a fifth
   arrives, read Hover's state machine before adding another `||`.
4. **Nothing about the physics.** `androidx.dynamicanimation` is what the
   abandoned libraries were approximating with Facebook Rebound. We are already
   on the thing they wanted.

---

## 6. Honest caveats

* Star counts are from 15 Sep 2026 and will drift. **Maintenance status is what
  to re-check**, and two of the best-known projects here are already dead.
* Where a star count is blank, the repository page did not surface one in the
  fetch; the link is still verified as existing.
* Everything in §2 and §3 draws over other apps and so needs
  `SYSTEM_ALERT_WINDOW`, plus a foreground service on modern Android — the same
  permission wizard SWIP built in `F-159`. None of them makes that go away.
