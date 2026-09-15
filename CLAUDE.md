# SWIP — project memory

Read this first, every session. It is the short version of everything that has
already been decided, gone wrong, or been ruled out, so none of it has to be
rediscovered.

---

## What SWIP is

An Android-first Flutter app that shows a shop's **merchant category code (MCC)
before you pay**, so you know which card to use. Owner: Aditya Maurya, a product
designer who does not write code — so **explain the reasoning, not just the
result**, and never leave a claim without a link to where it is written down.

There is **no server, no account, no analytics**. The ledger is local SQLite.
That is the product's main security property and its main marketing claim; do
not add a network dependency without saying so out loud.

---

## Standing rules — these do not expire

| Rule | Detail |
|---|---|
| Branch | `claude/swip-mcc-tracking-app-unc1nl`. **Never push elsewhere without explicit permission** |
| Pull requests | **Only when explicitly asked** |
| Push | `git push -u origin <branch>`; retry 4× on network failure with 2/4/8/16 s backoff |
| CI | **Read the logs yourself after every push, including the APK job.** Two builds were once reported green while the APK job had failed |
| Links | Every claim gets a link to the file, commit or source it came from. Never leave the owner "blind with words" |
| Ledgers | A changelog entry per prompt, a prompt ledger with every prompt **verbatim and timestamped**, and a conversation log of the answers. **Never delete a row from any of them** |
| Before every build | Run [`docs/30-PRE-LAUNCH-PARAMETERS.md`](docs/30-PRE-LAUNCH-PARAMETERS.md) §1 |

### Pre-push checks that exist because something got through

```bash
cd app
python3 tool/check_balance.py   # unbalanced brackets — a stray `Text(` once broke the parse
python3 tool/check_const.py     # `const X(… .withValues(…))` is not constant
python3 tool/check_wiring.py    # code that is finished, correct and unreachable
python3 tool/check_links.py     # doc links that point at nothing
bash    tool/check_secrets.sh   # a key that must never reach the repository
```

`check_wiring.py` exists because **four times** a feature was built, tested and
never connected — the floating bubble's switch wrote a preference nothing read
(`F-131`), and `merchant_directory.dart` is imported by its test and nothing
else (`F-157`), and `DashboardPage.onOpenEvent` was declared and called by
every recent row while **nothing ever passed one**, so tapping an MCC on the
dashboard did nothing (`F-169`), and the bubble's long-press snooze peeked a
goodbye message and hid the window **on the same frame**, so a promise made in
`F-167` had never once been drawn (`F-170`). None is catchable by a test: every
piece works, and what is missing is the wire.

The fourth is the one the gate cannot see at all — nothing is unimported,
unhandled, unread or unsupplied; the fault is the *ordering* of two correct
calls. So it is a reading habit rather than a check: **when a feature's whole
value is that the user sees something, ask what else runs on that frame.**

It checks five shapes — unimported files, method-channel names against
`MainActivity.kt` in both directions, preference keys written but never read,
widget callbacks that a widget invokes as `name?.call(` while no caller
supplies one, and the bubble's diameter against `swip_bubble_bg.xml`'s corner
radius (which must stay exactly half, or the circle becomes a rounded square
with nothing failing). That last rule is narrow on purpose: a never-passed callback
with a `??` fallback, or one handed to an `InkWell`, is a working default and
is **not** flagged. Exceptions live in the file and each needs a written
reason.

---

## Themes

`F-155`. **Two grounds: Paper (light) and Foil (dark), toggled in Settings,
defaulting to the phone.** `SwipColors.*` are static getters over
`SwipPalette.active`, which is written in exactly one place — `SwipApp.build`
— and `MaterialApp` is keyed on the choice so a switch rebuilds the tree once.

A colour token is therefore **not a compile-time constant**. `const Foo(color:
SwipColors.bg)` will not compile, and that is expected rather than a mistake to
undo.

`onCamera*` deliberately does **not** follow the palette. There is a test.

---

## The one paid surface

`F-146`. **Exactly one thing in SWIP costs money: viewing the raw payload
in-app, ₹5,000, one-time.** Never behind it: the category, the merchant, the
RuPay outlook, the ledger, and **both exports including the encrypted backup**,
which contains the payloads in full because it is the user's own data.

A **donation buys nothing, including this.** They are separate transactions and
must never be merged — a donation that confers a benefit stops being a donation,
with the GST consequences in [`docs/27-DONATIONS.md`](docs/27-DONATIONS.md) §2.

The product does not exist in the Play Console yet, so today every device sees
"not on sale yet".

---

## Declined, and staying declined

* **The cashback-arbitrage donation mechanism** — a donor swipes ₹40,000, gets
  ~₹38,000 back, keeps the card cashback. The cashback is paid by an issuer who
  believes it funded a retail purchase. Recorded once in
  [`docs/27-DONATIONS.md`](docs/27-DONATIONS.md) §3 with what replaces it. The
  owner has reaffirmed the request; everything else in that feature is built.
* **A plan to avoid GST.** The accurate position was given instead: a genuine
  donation with no quid pro quo is not a supply at all under CBIC Circular
  116/35/2019.
* **Scraping the LinkedIn profile photo** — it is behind an auth wall. The
  colophon falls back to a monogram; dropping `brand/avatar.jpg` in fixes it.

---

## Hard-won technical facts

Each of these cost a broken build or a broken screen. Do not re-derive them.

| Fact | Consequence |
|---|---|
| `mobile_scanner`'s `DetectionSpeed.noDuplicates` is a **single-slot** memory cleared only by `stop()`/`dispose()` | Never use it. The same code twice emits nothing — this is why a force-quit "fixed" scanning |
| `material.dart` exports `ValueNotifier` but **not** `ValueListenable` | Import `foundation.dart` explicitly |
| `ScrollNotification.context` is **non-nullable** | Notification tests need a real element tree, so `testWidgets` not `test` |
| `NotificationListener` hears **descendants only** | A pull-to-reveal inside a scroll view can never fire |
| `CrossAxisAlignment.stretch` in a sliver → tight infinite constraint → kills the whole `CustomScrollView` | This is what turned the dashboard black |
| Riverpod's `when` shows `loading` on a **reload** by default | `skipLoadingOnReload: true`, or the camera is torn down after every capture |
| `.withValues()` is a method call | It cannot appear inside a `const` block |
| `app/assets/brand/` is **gitignored**; `bootstrap.sh` copies top-level `brand/` | New brand assets go in `/brand/` |
| Camera overlays must use `onCamera*` colours, never `bg`/`textPrimary`/`gold500` | The feed is an arbitrary image; the app ground is white |
| **Android routes HCE by AID, and every terminal opens with `SELECT 2PAY.SYS.DDF01`** | The PPSE AID `325041592E5359532E4444463031` must be registered in `apduservice.xml` or a tap does **nothing at all**. `F-140` — it was missing for four months and `ppseResponse()` was unreachable code |
| Writing to a `ValueNotifier` from a scroll notification is legal under a finger and **illegal under bouncing physics** | The spring-back runs inside the frame → "Build scheduled during frame" → the red `ErrorWidget`. Defer with `SchedulerBinding` when not idle. `F-141` |
| `check_balance.py` counts brackets; it **cannot see grouping** | It passed a file where `FittedBox(` was never closed. `flutter analyze` is the authority, and it is in the gate |
| sqflite caches open databases **by path**, and `openInMemory()` always uses `:memory:` | Two tests silently share one database. `SwipDatabase.close()` in `tearDown`. `F-150` |
| `expect(() => asyncFn(), returnsNormally)` checks **only the synchronous part** | It leaves an unawaited Future; the failure surfaces later from a test that already passed. Await it |
| **CoWIN is not blockchain-based** | DIVOC issues W3C Verifiable Credentials signed as JWTs. The premise correction was right; **the conclusion was not** — the owner reaffirmed and a real chain was built (`F-156`), and its Merkle tree buys selective disclosure, which a flat hash chain cannot |
| An `AnimatedSwitcher` keyed on **text that can return to a previous value** collides | A bouncing overscroll crosses a threshold several times inside one 180 ms transition → two `Stack` children share a key → *"Duplicate keys found"*. Key on a monotonic counter, and add hysteresis. `F-152` |
| **That assertion throws inside a sliver, which black-screens the whole `CustomScrollView`** | The red panel and the "black screen on intent capture" were always the same bug. `F-152` |
| `CaptureResolver.hasMcc` excluded `'0000'`; `CaptureEvent.hasMcc` did not | The screens use the **event** one, so an unclassified merchant rendered `0000` as the hero number. Two getters of the same name disagreeing is the shape to look for. `F-154` |
| **`mc=0000` is not proof of a merchant** | PhonePe mints `mc=0000&mode=02` on *personal* QRs. The discriminator is the `sign=` block. `F-154` |
| A `MethodChannel` future completes when the platform replies, and **never completes if it does not** | There is no built-in timeout. A screen that clears its spinner at the end of an `await` chain therefore spins forever, and in a widget test there is **no engine at all**, so every un-mocked call hangs — `pumpAndSettle timed out` is the symptom, not a slow test. `.timeout()` every platform read. `F-158` |
| A broadcast is the wrong shape for a **fact that is either true or false right now** | `F-158` sent foreground state as a broadcast and dropped it when the service was not yet `running` — and `startForegroundService` returns long before `onStartCommand`. Flip switch → press Home → the message arrived with nothing listening, and the bubble hid itself permanently. Shared state the service **reads** on every decision. `F-159` |
| A `ListView` only builds what is near the viewport | Copy below the fold does not merely fail to be *visible* — it is not in the tree, so `find.textContaining` cannot see it. Widget tests asserting on wording need a tall test surface. `F-159` |
| A screen with **no spinner** lets `pumpAndSettle` return while timers are pending | "A Timer is still pending even after the widget tree was disposed." The bubble settings test passes the same case only because its spinner keeps scheduling frames. Advance the clock explicitly, repeatedly if the timeouts are sequential. `F-159` |
| A switch that stores its own state instead of asking the platform **cannot be wrong on screen** | Which is why nothing caught the dead floating bubble for four months: the screen set a boolean and displayed the boolean it had set. Assert on what reaches the channel, never on what the widget remembers. `F-158` |
| A **fixed-duration interpolator cannot feel native**, however good the easing | A flick and a nudge take the same time, so the motion is unrelated to the gesture. That is what "sticky" describes. `androidx.dynamicanimation` — `SpringAnimation` has no duration, only a rest position and a **start velocity** read from a `VelocityTracker`. `F-170` |
| **Every setter in `androidx.dynamicanimation` returns the object** | So Kotlin synthesises no property for it. `spring = …`, `stiffness = …`, `dampingRatio = …` and `friction = …` all fail to compile; call `setSpring(…)`, `setStiffness(…)` and so on. They look like they should work, which is the trap. `F-170` |
| A `DynamicAnimation` **keeps its start velocity after `cancel()`** | `endAnimationInternal` clears the start *value* and leaves the velocity. A press after a cancelled kick inherits the kick. Zero it explicitly — and note the mirror of this: a start velocity is read **only at `start()`**, so setting one on a running spring is silently ignored. `F-170` |
| **Reuse one `SpringAnimation` per property; never rebuild it** | `animateToFinalPosition` on a running spring keeps its position *and velocity* and re-aims. A fresh animation starts from a standstill, which is the visible stutter. `F-170` |
| `FlingAnimation` whose start is **outside** its own min/max ends immediately | So a bubble already dragged off-screen stays there. Spring to the nearest legal position in that case instead. `F-170` |
| An `AppBar` is **one row**, so "logo at the top" and "title beside it" are contradictory | No padding fixes that. Move the title out of the bar. `F-171` |
| **A `SafeArea` inside a card near the bottom of the screen is measuring the wrong thing** | The phone's status-bar inset is a fact about the top of the display. `MediaQuery.removePadding(removeTop: true)` around the card's content. `AppBar` has the same bug, invisibly, because its `SafeArea` is internal. `F-171` |
| A **`Stack` is entitled to overlap its children**, so a layout that is wrong throws nothing | A fixed 260 px reticle inside a 320 px card was drawn under the copy at both ends. Nothing failed and no test could see it. Size to the surface with a `LayoutBuilder`, and assert the arithmetic. `F-171` |
| **"Not prominent enough" is usually a contrast failure, not a size one** | Near-black at 80% on a 45% black scrim over a dark app composites to **1.03:1**. A bigger version is a bigger invisible button. Composite the layers and check the WCAG ratio — `test/hover_chrome_test.dart`. `F-172` |
| Chrome over an arbitrary app must **not** follow the palette | Same rule as the camera overlays, and it bites the same way: `SwipColors.surfaceRaised` is paper-white in Paper and `#141216` in Foil, so following the theme puts the invisible pill back in one ground. `F-172` |
| **CRED does not need a PSP licence to show a merchant name** | Resolving a VPA is a commercial API (Razorpay, Cashfree, Decentro, Juspay) sold to any business with KYC. No API returns the **MCC** — that lives in the acquirer's switch, which is why CRED writes *"may not"*. `F-157` |

**The recurring mistake, twice over: checking the source instead of the
artifact.** Read the built thing, not the code that should have built it.

**The other recurring mistake: concluding instead of looking.** Three times —
the floating bubble, the blockchain, and CRED's PSP licence — I reasoned from
what I already believed, said it could not be done, and was overruled by the
owner telling me to go and check. Each time the checking changed the answer.
Before writing "that is not possible", go and look. `docs/36` §5.

**And its worse form: labelling something "the owner's call".** Three more —
the HTTP client our own gate forbids, three Razorpay constants, and CameraX
surviving `bootstrap.sh` — were not positions I argued, they were things I
handed over, which is how a wrong conclusion avoids being argued with at all.
All three were mine to solve and none needed a decision from anybody.
**Before writing "that is your call", check whether it is a genuine trade-off
or just something not yet tried.** `docs/36` D-42..D-44.

**And the quietest variant: a spec this project wrote, that the build drifted
from, that nobody re-read.** `docs/32` §4 asked for a 56 dp bubble with
"velocity-aware edge snapping". The build shipped 48 dp with a fixed 260 ms
interpolator that never read a velocity, and stayed that way for four months
until the owner felt it. **Before calling a feature finished, re-read the page
that specified it.** `docs/36` D-47.

---

## Domain facts that drive the product

* **P2M** merchants have an MCC and can take a RuPay credit card on UPI.
  **P2PM** (small-merchant) have **neither** — NPCI does not permit credit card
  on UPI there. "This shop has no category" and "my RuPay card is greyed out"
  are one fact seen twice.
* A **static Paytm sticker carries no MCC at all** — often just
  `pa` and `pn`. No app can read one out of it, CRED included.
* **`mc=` present-and-empty** is a bank that built a merchant QR and left the
  category blank. Different from absent, and worth saying.
* **Netbanking has no MCC.** Not a card transaction, so there is nothing to read.
* The MCC **is** in the 3-D Secure `AReq` during a card payment, but that is
  server-to-server and never reaches the phone.
* CRED writes **"MERCHANT MAY NOT ACCEPT RUPAY CC"** — the word *may* is the
  tell that they are inferring too. Match that hedge; never claim more.

---

## Where things are written down

| Topic | File |
|---|---|
| Every prompt, verbatim, timestamped | [`docs/21-PROMPT-LEDGER.md`](docs/21-PROMPT-LEDGER.md) |
| What was built each round | [`docs/CHANGELOG.md`](docs/CHANGELOG.md) |
| What was *answered* each round | [`docs/28-CONVERSATION-LOG.md`](docs/28-CONVERSATION-LOG.md) |
| Why the QRs would not scan | [`docs/29-QR-DETECTION-FORENSICS.md`](docs/29-QR-DETECTION-FORENSICS.md) |
| The build gate | [`docs/30-PRE-LAUNCH-PARAMETERS.md`](docs/30-PRE-LAUNCH-PARAMETERS.md) |
| iOS and `.ipa` | [`docs/31-IOS-AND-IPA.md`](docs/31-IOS-AND-IPA.md) |
| The floating bubble, its physics and the goodbye nobody saw | [`docs/32-FLOATING-BUBBLE.md`](docs/32-FLOATING-BUBBLE.md) |
| Visual direction | [`docs/33-VISUAL-DIRECTION-PAPER.md`](docs/33-VISUAL-DIRECTION-PAPER.md) |
| Account recovery | [`docs/25-CONTINUITY.md`](docs/25-CONTINUITY.md) |
| The round-34 checklist, PPSE forensics, CRED vs SWIP | [`docs/34-ROUND-34-CHECKLIST.md`](docs/34-ROUND-34-CHECKLIST.md) |
| **Omnipresence, the shortcut-clash answer, and the two blockers** | [`docs/37-OMNIPRESENCE-AND-THE-TWO-BLOCKERS.md`](docs/37-OMNIPRESENCE-AND-THE-TWO-BLOCKERS.md) |
| **Every ask from every prompt, with status** | [`docs/35-MASTER-CHECKLIST.md`](docs/35-MASTER-CHECKLIST.md) |
| **Every deviation from the original idea** | [`docs/36-DEVIATIONS.md`](docs/36-DEVIATIONS.md) |

---

## Style

Long doc comments that explain **why**, especially where the reason is
non-obvious or where a previous attempt failed. The owner reads the code as
documentation. A comment that only restates the line beneath it is noise; a
comment that records why the obvious approach does not work is the most valuable
thing in the file.
