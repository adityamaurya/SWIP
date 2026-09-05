# 28 — Conversation log

> *"whatever problems I am giving to you and you are replying to me, I need it
> all transcribed there with timestamps if possible. That is very important for
> me!"*

This file exists because the prompt ledger records **what you asked** and the
changelog records **what was built**, but neither records **what I told you** —
and some of the most valuable output of this project has been an answer rather
than a commit. The P2PM explanation, the 3-D Secure finding, the GST position:
all of that lived only in a chat transcript that dies with the account.

## The rule, from here

Every turn appends an entry below. Prompt in, reply out, what shipped. Nothing
is ever deleted or rewritten — a wrong answer gets a correction beneath it, not
an edit.

**Timestamps** are the commit timestamps, which are the only clock in this
system that cannot drift or be reconstructed wrongly. Where a turn produced no
commit, the date is given without a time.

---

## Prompt 26 — 10 Aug 2026 · "The dashboard is broken fully!"

**You asked:** why the dashboard rendered as nothing but a navigation bar; a
deep dive and sanity check; the MCC in the sheet to keep shimmering. Your second
point was cut off mid-sentence — *"Second, as per user experience on the MCC"* —
and was left open rather than guessed at.

**I answered:** one line I had added in the previous round,
`crossAxisAlignment: CrossAxisAlignment.stretch` on a `Row` inside a
`SliverToBoxAdapter`. A sliver hands its child unbounded height; `stretch` turns
that into a tight infinite constraint, which throws during layout and takes the
entire `CustomScrollView` with it — hence header, camera, tiles and list all
vanishing together.

I also said the thing that mattered more: `flutter analyze` cannot see a layout
error, every test in the project was a parser test, and I had been reporting a
green CI as a working app. That was the actual defect.

**Shipped:** [`4189598`](https://github.com/adityamaurya/SWIP/commit/4189598),
[`1dc3ece`](https://github.com/adityamaurya/SWIP/commit/1dc3ece),
[`ccef9c6`](https://github.com/adityamaurya/SWIP/commit/ccef9c6) — the fix, a
repeating foil shimmer, and `dashboard_layout_test.dart`, which lays the real
screen out at three widths and two text scales. It failed on its first run and
caught a **pre-existing** ledger-row overflow at 1.6× text scale that had
shipped in every build to that point.

---

## Prompt 27 — 11 Aug 2026 · Three routes, one language

**You asked:** confirmed QR scan, POS tap and app-redirect all work. Then
thirteen fixes — MCC not clickable, MCC cropping into the merchant name, remove
"Likely", only three route tags, remove the time toggle, clear the ledger badge,
remove Link and Manual everywhere, fix the reflowing filter copy, `NA` instead of
a dash — and the research question: **how to get an MCC from a card payment or
netbanking.**

**I answered:** four of the symptoms had causes worth naming. The MCC was
wrapped in an opaque `GestureDetector` with a null callback, so the most
obviously tappable thing in the row was the one dead spot in it. "Likely" was
assigned by default to every non-live vector. "Known" appeared because
`record()` **rewrote the vector** whenever the digits came from memory — two
different facts folded into one field.

On the research: the MCC **is** transmitted during a card payment — a required
field in the 3-D Secure `AReq` — but server-to-server, acquirer to issuer. The
OTP page carries merchant, amount and last-4, never the category. **Netbanking
has no MCC at all**, because it is not a card transaction; the right feature
there is a warning, not a capture. The dummy-card idea cannot work: a decline is
only visible to the issuer of the card used. The version that does work is SWIP
issuing its own virtual card and reading its own declines — a BIN sponsor, not a
sprint.

**Shipped:** [`e74a880`](https://github.com/adityamaurya/SWIP/commit/e74a880),
[`714d66b`](https://github.com/adityamaurya/SWIP/commit/714d66b) — all thirteen,
plus [24-CARD-AND-NETBANKING](24-CARD-AND-NETBANKING.md).

---

## Prompt 28 — 12 Aug 2026 · Icon, Play Store, donations, backup, privacy

**You asked:** a great deal at once — the logo not visible on the dashboard; the
camera collapse too sharp; remove the hand icon and use a dotted-grid ripple;
rows not expanding; remove "known"; two-line tags; remove "Verified"; em dashes
out; an accessibility shortcut like the Maximize app; the ledger not refreshing
after a scan; a BharatPe QR scanning with no result; padding above the ledger;
the QR needing a force-quit; onboarding checkbox replaced with "Got it"; remove
Upload Statements; an exhaustive MCC list; the settings colophon with your
LinkedIn; a donation section with a progress bar; a Play Store plan; export /
import hardening and a 02:00 auto-backup; a bottom sheet with a slogan and
pull-to-reveal; the app icon still being the Flutter default. Plus: **can Claude
Code still work on a private repo**, **how do I recover if I lose this account**,
and **a GST plan**.

**I answered, and one part I declined.** Built in batches. On the questions:

* **Private repo** — yes, access is the GitHub App installation, not public
  readability. But private repos get 500 MB of artifact storage on the Free
  plan and the APK is 87 MB at 90-day retention, so the sixth build of the
  month would have failed on quota. Fixed to 5 days before you switched.
* **Account loss** — the repository is the project; the account is only the
  tool. Add a second verified email today and the rest is a fallback.
* **GST** — better than the question assumed. A genuine donation with no quid
  pro quo **is not a supply at all** under CBIC Circular 116/35/2019. No scheme
  is needed; the donation just has to actually be a donation. Income tax is
  separate and does apply.
* **Declined:** the cashback mechanism — a donor swiping ₹40,000 and being
  returned ~₹38,000 so they keep the card cashback. Money moving both ways is
  consideration, so it is a supply, and the cashback is paid by an issuer who
  believes it funded a retail purchase. Recorded once in
  [27-DONATIONS §3](27-DONATIONS.md) with what replaces it.

**Shipped:** [`9a478d3`](https://github.com/adityamaurya/SWIP/commit/9a478d3),
[`d476b3c`](https://github.com/adityamaurya/SWIP/commit/d476b3c),
[`fcda523`](https://github.com/adityamaurya/SWIP/commit/fcda523).

**Two failures in this prompt, both mine, both worth keeping on the record:**

1. I reported two pushes as fine. `analyze` and the tests had passed; the **APK
   job had failed** and I stopped reading at the first green step. The cause was
   `` `in` `` — a Kotlin keyword — being backtick-escaped inside the `namespace`
   *string*, where escaping is meaningless, so `bootstrap.sh`'s rewrite could
   never match it.
2. The logo was invisible because I committed it to `app/assets/brand/`, which
   is **gitignored by design** — `bootstrap.sh` copies the top-level `brand/`
   into it. The file existed on my disk and nowhere a build could see.

Both are the same mistake: **I checked the source instead of the artifact.**

---

## Prompt 29 — 12 Aug 2026 · The things I had dropped

**You asked:** the launcher icon reduced to just the slash, thicker, and
reversed to black-on-gold; the Play Store pricing question (₹2 / ₹9 / ₹99, and
what you would net); **why pull-to-reveal was still not built despite being
asked for strongly**; the "Check, Pay, Get Rewarded" sign-off at the foot of the
home page; an empty-ledger state; the accessibility shortcut; a redesigned
donation flow with storytelling, haptics and an in-app browser; this log; and a
deep dive on the `DESIGN.md` specification.

**I answered:** you were right, and the pattern is worth naming rather than
apologising for. Across prompts 27–29 I ended several replies with a "queued"
list, and a queued item is not a built item. Three of these had been queued
twice. The fix is this file plus the ledger being updated **before** the reply,
not after.

**Shipped:** [`16044ed`](https://github.com/adityamaurya/SWIP/commit/16044ed) —
the icon reduced to a black slash on gold, the sign-off and pull-to-reveal with
haptics at the foot of the home scroll, the empty-ledger state, and
[`DESIGN.md`](../DESIGN.md) written to the Google Labs specification.

**Still open at the end of this prompt**, and honestly listed rather than
implied: the four scan bugs, the accessibility shortcut, the donation redesign,
export/import hardening and the 02:00 backup, the exhaustive MCC list, and the
onboarding "Got it" change.

---

## Prompt 30 — 14 Aug 2026 · The scan bugs, and Google Play Billing

**You asked:** continue; plus a new bug — an in-app purchase, choose UPI,
fingerprint check, then failure and a black screen, "despite selecting SWIP as
one of the apps". And: do all the rituals, re-check the MD files, sanity check.

**I answered — the scan bugs had one shared cause.** Not four bugs:

```dart
recent.when(loading: () => const _Booting(), ...)
```

Every capture bumps `ledgerRevisionProvider`. Riverpod treats a
watched-dependency change as a **reload**, and `when` shows `loading` on a
reload by default. So after every single scan the whole `DashboardPage` was
replaced by a spinner — which tears down `LiveViewfinder`, which disposes the
camera controller, which disposes the **process-wide** scanner platform.

That one default explains three reports at once: the ledger appearing not to
update until you switched tabs, the camera dying mid-session, and needing a
force-quit before a QR would scan again. `skipLoadingOnReload: true` keeps the
previous data on screen and the camera alive.

Second, related: `!_capturing` was in the camera's `active` gate, so every
ambient detection **stopped and restarted the camera** for the length of one
database write. Against a platform singleton holding one texture, that churn is
what wedges it — and an ambient scanner that stops the moment it finds something
is a contradiction in terms.

**On Google Play Billing:** SWIP cannot be a payment method there, and should
never appear as one. Play Billing runs its own UPI flow inside the Play Store —
it does not hand the payment to Android's UPI chooser, and it expects a
settlement callback from a registered PSP. SWIP is deliberately **not** a PSP:
it reads a category and stops. Any purchase routed to it will fail by
construction.

This is the cost of registering `upi://pay` in the manifest: it makes SWIP
*offerable* in places where choosing it breaks a real payment. Recorded here as
an open design question rather than silently patched — the options are to keep
the filter and always forward, or to drop it and rely on the share sheet and the
Quick Settings tile.

**Shipped:** the two scan fixes. The black screen itself is not yet reproduced
or fixed.

**Still open:** the black screen on intent capture, the donation redesign, the
02:00 backup, the exhaustive MCC list, the onboarding "Got it" change.

---

## Prompt 31 — 14 Aug 2026 · The pull that did nothing

**You asked:** the pull on the dashboard is not functional — *"as you can see
from the screenshot"*; witty three-phrase pull copy; "Made with love" to become a
heart; the avatar small and after the name; the name to become `a.r.my.`; a
narrated widget behind the pull, structured beautifully; the amount with a
gradient, first milestone 13 and second 39; donate by card and get rewarded;
donate by UPI with the UPI ID embedded; an explanation of *"what does P with CC
mean and now what does CPI mean"* narrated into the story; and more spacing, with
the pull at the very bottom rather than pinned to the footer.

**I answered — you were right, and it could never have worked.** Not a tuning
problem. `NotificationListener` catches notifications travelling **up** from its
descendants, and I had placed it *inside* the `CustomScrollView`, as one of its
slivers. The scroll view was its **ancestor**, so the listener sat there waiting
for news that could not reach it. It laid out perfectly, screenshotted
perfectly, and was inert.

Two further things were needed before an overscroll existed at all:

* **The page has to be scrollable even when the content fits.**
  `AlwaysScrollableScrollPhysics`, or a dashboard shorter than the screen
  reports no scroll activity whatsoever and the gesture is dead on exactly the
  phones with the most room.
* **The two physics report a pull in two completely different ways.**
  `ClampingScrollPhysics` (Android's default) refuses the movement and reports
  the refused distance as an `OverscrollNotification`. `BouncingScrollPhysics`
  *allows* it — `pixels` simply exceeds `maxScrollExtent` — and emits **no
  overscroll at all**. Handling only one of them works on half the devices it is
  tried on. And under bouncing physics the list springs back *before* the
  gesture ends, so a controller that decides on the live value at
  `ScrollEndNotification` opens nothing, ever. It now remembers the furthest
  point reached during the drag, which is the thing you actually did.

All three are covered by [`pull_controller_test.dart`](../app/test/pull_controller_test.dart),
including the spring-back case, because a gesture that looks right in a
screenshot and does nothing is the exact failure this project keeps repeating.

**On the goal bar:** it was `milestone + stretch = ₹52.5 lakh`, which put the
first marker a quarter of the way along. That is not the shape of the thing. It
is **one road to ₹39 lakh with a notch at ₹13.5 lakh** where the debt clears —
[`goal_bar.dart`](../app/lib/features/support/goal_bar.dart), foil gradient,
painted across the whole rail and clipped to the filled width so the same rupee
is never a different colour depending on the total.

**On `CPI`:** it does not resolve to anything NPCI publishes, and I have not
invented a definition for it. The terms that do resolve are in the story panel's
glossary — **P2M**, **P2PM**, **PPI** and **CC on UPI** — and the load-bearing
fact among them is that a **P2PM merchant has no MCC and cannot take a credit
card on UPI at all**. At a tea stall it is not that SWIP failed to read the code;
there is no code, and no card will reward you there. Full note in
[21-PROMPT-LEDGER § Prompt 31](21-PROMPT-LEDGER.md).

**On the photograph:** still not possible. A LinkedIn profile image sits behind
an authentication wall. The circle is built, sized to the font, and falls back to
a monogram — drop `brand/avatar.jpg` into the repo and it appears with no code
change.

**Shipped:** the pull wired up and tested, [`support_story.dart`](../app/lib/features/support/support_story.dart),
[`goal_bar.dart`](../app/lib/features/support/goal_bar.dart),
[`support_flow.dart`](../app/lib/features/support/support_flow.dart), the
colophon rebuilt with the heart and `a.r.my.`, and **prompts 28–31 written into
[21-PROMPT-LEDGER](21-PROMPT-LEDGER.md) verbatim with timestamps** — the ledger
had stopped at 27, which is the thing you asked twice to be kept current.

**Still open:** the UPI ID and Razorpay link (asked four times now), the in-app
browser for the payment page, the black screen on intent capture, the 02:00
backup, export/import hardening, the exhaustive MCC list, and the onboarding
"Got it" change.

---

## Prompt 32 — 5 Sep 2026 · The QRs that would not scan

**You asked:** an iOS plan and an `.ipa` pipeline; why several merchant QRs
would not scan; an export filename with date, exact time and a serial; a
pre-launch security and compliance file to run before every build; blockchain
integrity like CoWIN; the black-and-white theme; the Wispr Flow floating bubble;
CRED's language for merchant and RuPay detection; and the pull-to-reveal still
not working. Then, mid-turn: *"the pop up came but it failed on the catching the
mcc find the root reason and get it sorted and detect fail proof for future"*.

**I decoded every QR from your photographs before writing a line of code.** That
is the whole reason this round found anything, and it is written up in full in
[29-QR-DETECTION-FORENSICS](29-QR-DETECTION-FORENSICS.md).

### The scanner going dead was four words of configuration

`DetectionSpeed.noDuplicates`. Inside mobile_scanner's Android plugin there is a
**single-slot** memory:

```kotlin
private var lastScanned: List<String?>? = null
if (newScannedBarcodes == lastScanned) return@addOnSuccessListener
```

cleared only by `stop()` or `dispose()`. Point at the **same** code twice and
the second time emits nothing at all — no callback, no error. **That is your
force-quit**: killing the app nulled the slot. It also explains why it seemed
random, because a different code in between clears it.

### Three payloads, three different truths

| Where | What is actually in the QR |
|---|---|
| Shree Beauty Centre | `mc=` — **present and empty**. A bank built a merchant QR and left the category blank |
| Wellness Forever, Pine Labs box | `mc=5912` — the category was there all along |
| The corn-dog stall | `upi://pay?pa=paytm.s26upzx@pty&pn=Paytm` — **two fields, and no category to catch** |

**On the third one: nothing failed.** There is no MCC in that sticker, and no
app on any phone can read one out of it — CRED included. What CRED shows at that
same handle family is *"this merchant accepts RuPay payments"*, which is a
**tier flag, not a category**. CRED displays no MCC there either.

So "fail-proof" cannot mean "always find it in the QR". It now means **never
leave you at a dead end**: SWIP says why the category is missing and lists the
routes that would actually get it for that merchant, and offers none at all at a
small merchant, where nothing would work.

### How CRED does it, and the word that gives it away

CRED writes **"MERCHANT MAY NOT ACCEPT RUPAY CC"**. *May.* If they held an
authoritative flag they would say "does not". They are inferring — and at a
merchant they are sure about, the same app says plainly *"this merchant accepts
RuPay payments"*. SWIP now uses the same hedge in the same place, for the same
reason, and its one unhedged claim is the small-merchant tier, because that is
NPCI policy rather than a merchant's setting.

### On the blockchain

Both papers you sent use a distributed ledger because **the issuer and the
verifier do not trust each other**. SWIP has one party: you are both. A chain
would publish your spending permanently and world-readably, and would need a
network SWIP deliberately does not use. So SWIP takes the mechanism those papers
actually rely on — the hash chain — and leaves the network out. Exports carry a
SHA-256 chain and a seal; import verifies it and names the first record that
does not match. It is **tamper-evident, not tamper-proof**, and the code says so
rather than letting the word "blockchain" do work it cannot.

### The theme change broke the one screen nobody screenshots

Flipping the ground to white turned the camera scrim — which was `SwipColors.bg`
— into a **white fog over the viewfinder**, with black brackets on top. Camera
overlays now have their own constants that do not follow the app's ground.

**Shipped:** [`ceefbbf`](https://github.com/adityamaurya/SWIP/commit/ceefbbf),
[`f2acf31`](https://github.com/adityamaurya/SWIP/commit/f2acf31),
[`1f6c472`](https://github.com/adityamaurya/SWIP/commit/1f6c472),
[`4ac809e`](https://github.com/adityamaurya/SWIP/commit/4ac809e). Plus
[29-QR-DETECTION-FORENSICS](29-QR-DETECTION-FORENSICS.md),
[30-PRE-LAUNCH-PARAMETERS](30-PRE-LAUNCH-PARAMETERS.md),
[31-IOS-AND-IPA](31-IOS-AND-IPA.md) and
[32-FLOATING-BUBBLE](32-FLOATING-BUBBLE.md).

**Two things I got wrong in this round, both caught before they mattered:** a
first pass at the merchant handle patterns matched anything with a digit in it,
which would have called `john123@okaxis` a registered merchant — removed, with a
test. And a `const Icon(… .withValues(…))` failed analyze; there is now a
pre-push check for that shape.

**Still open:** the bubble's service and camera overlay (steps 2–6), the iOS CI
workflow, the `INTERNET` permission that has no justification, the black screen
on intent capture, the 02:00 backup, and the exhaustive MCC list.

---

<!--
Template:

## Prompt N — DD Mon YYYY · <theme>

**You asked:**
**I answered:**
**Shipped:** commit links
**Still open:**
-->
