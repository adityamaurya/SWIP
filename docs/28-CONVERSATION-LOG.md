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

## Prompt 33 — 5 Sep 2026 · Your own ledger, read properly

**You asked:** the UI inspirations made real; **gyro-gated scanning** so the
camera stops ambushing you with pop-ups; project memory and a log; how CRED
actually does it; a sanity check of all code; the MCC cropping in the pop-up;
the export log made detailed and re-importable; and the floating bubble notes
from Wispr Flow and Maximise. Then you sent **your real 85-capture export**.

**That export is the most useful thing sent in this project so far.** It turned
every open question from an argument into a measurement.

### Where the categories are actually being lost

| Count | Shape |
|---|---|
| **34** | A UPI sticker with **no `mc` at all** |
| 5 | Not a payment QR — a stock photo, a print-shop URL, a test string |
| 2 | `mc=` present and empty |
| 1 | A raw NFC log |

**Eighty-one per cent of every miss is a sticker that never carried a
category.** No parser work touches that, and it settles the corn-dog-stall
question: that was not an anomaly, it is the normal case.

Cross-checked across all 85 rows: 42 absent, 32 published, 9 unclassified,
2 blank — and **zero** rows where a published `mc` failed to be stored.

### The POS failure, solved from the hex

Two NFC taps in the export. One gave MCC 5411. The other gave nothing, and the
reason was sitting in the payload:

```
worked   9F16 = 0FBD96389443542326810000000000    binary, a real merchant ID
failed   9F16 = 313132323333343435353636373738    ASCII "112233445566778"
         9F1C = 3132333435363738                  ASCII "12345678"
```

**Factory placeholder values.** That terminal was never provisioned, which is
exactly why it had no category. One cause, two symptoms — and SWIP was
reporting it as "the shop's bank did not fill it in", which is unfalsifiable
and reads as a shrug.

### Two things the export showed SWIP was throwing away

`tatastarbucks.payu@mairtel` and `zepto.payu@mairtel` were "undetermined".
Aggregators mint `<merchant>.<aggregator>@<psp>` at onboarding and a person
cannot obtain one. And nobody's personal handle says "PRIVATE LIMITED" —
matched as a substring, because your PSP truncated it to "Private Limite".

**What I deliberately did not do:** catch `Greymode Architectural Products`.
Doing so needs "Products" as a business marker, and the same export contains
`janhavigraphics@oksbi` whose `pn` is **"Pramod Parkar"** — a person's name on
a business-sounding handle. Vocabulary is wrong in both directions there.

### The nuisance fix

The de-duplication stopped the *same* code re-firing. It did nothing about the
camera grinding away while the phone sits on a table. It now only detects while
the phone is **raised**: one accelerometer axis, hysteresis so it cannot flicker
at the angle people actually hold a phone, a settle delay so lifting the phone
to read the ledger does not trip it, and it **fails open** so a device without
the sensor behaves exactly as before.

### The cropping

`SizedBox(width: 46)` around four digits that measure about 49. A fixed width
was the wrong tool for a column that has to align — alignment needs a
*minimum*, not a maximum.

### A bug I nearly shipped

The new per-capture `provenance` block **would have broken import entirely**.
sqflite throws on an insert containing a key that is not a column, so the first
import of the first new-format export would have failed — on the file that is
your only backup. Import now keeps only real columns, which also makes the
format forward compatible.

**Shipped:** [`0af7d73`](https://github.com/adityamaurya/SWIP/commit/0af7d73),
[`6315452`](https://github.com/adityamaurya/SWIP/commit/6315452),
[`6a2a745`](https://github.com/adityamaurya/SWIP/commit/6a2a745), plus
[`CLAUDE.md`](../CLAUDE.md) and
[33-VISUAL-DIRECTION-PAPER](33-VISUAL-DIRECTION-PAPER.md).

**Three of my own claims corrected in this round**, all caught by CI or by
re-reading: Greymode is not detected; BharatPe is not the acquirer of an
`@icici` handle; and `export_narrative` was reading `merchant_handle`, which is
not a column — every exported row would have carried a null handle, silently.

**Not received:** the merged PDF. Only the 16 images arrived.

**Still open:** the display serif; the bubble's service and overlay; the iOS
workflow; the `INTERNET` permission; the black screen on intent capture.

---

## Prompt 34 — 5 Sep 2026 · The silent POS, the black box, and the red string

**You asked:** nine things — the PDF images, a checklist of done and held-back,
why the Ribbons and Balloons POS produced no pop-up at all, a full-screen MCC
result instead of a sheet, a bottom-stuck CTA with technical detail collapsed
above it, a ₹5,000 paywall on the raw data, a blockchain-powered black-box
export with a recovery phrase plus a plain line export, the merchant-name
discrepancies, and the red bug string on pull-to-reveal.

### One thing I could not do

**The 40-page PDF is gone.** This session runs in a container that is reclaimed
after inactivity, and between your prompt arriving and the work starting it was
rebuilt — the whole uploads directory no longer exists. I searched the
filesystem before concluding that. I have installed the PDF tooling that was the
*original* blocker, so a re-upload can be read immediately. Nothing else in the
round depended on it.

### The POS finding, which is the biggest thing in this round

I looked for Ribbons and Balloons in the ledger. **It is not there** — and that
absence is the answer.

The POS failures diagnosed last round (`F-138`) produced a row with no category:
a record exists, you can go and look at it. A tap where "the pop-up did not
happen at all" left nothing behind. Different failure, and only one of them was
ever visible to me. So the question was not *why was the category missing* but
**why was there no record that a tap happened** — and that is answerable from
the code.

Every contactless terminal in the world opens with `SELECT 2PAY.SYS.DDF01` —
the PPSE — reads the list of applications that comes back, and only then picks
one. Android routes HCE traffic **by AID**. `apduservice.xml` declared six card
AIDs and **not the PPSE**, so the terminal's very first command matched nothing
and went unanswered. No SELECT AID, no PDOL, no GPO, no `9F15`, no broadcast, no
sheet, no row.

`SwipListenService.kt` has always had a `ppseResponse()` function whose entire
job is to answer that command. **It was unreachable code for the life of the
feature.** The service was correct; nothing could reach it.

Two more things came out of it. The service used to broadcast **only** on a
successful GPO, so a tap that ended early produced silence — indistinguishable
from a broken app, which is exactly how you reported it. Every ending now
produces a record with its own sentence. And `tlv()` threw above 127 bytes,
with the PPSE directory sitting at 107: one more AID would have killed the
service mid-tap.

### The red string was Flutter telling you about an assertion

It is `ErrorWidget` — the red panel of small text a debug build renders when a
widget throws during build. The text is **"Build scheduled during frame"**.

`PullController` wrote to a `ValueNotifier` from inside a scroll notification.
Legal while a finger drags, because pointer events arrive between frames.
**Not** legal when the notification comes from the scroll view's own physics: a
bouncing position springs back under a ticker that runs *inside* the frame. So
the write scheduled a build mid-frame, at the exact moment the pull was
released — which is why it looked like it broke on release.

All five existing `PullController` tests passed on the broken build, because a
synthetic notification is dispatched from test code, between frames, where the
write is legal. The new test drags a **real** dashboard and asserts nothing is
thrown. Same lesson as the recurring one: read the built thing, not the code
that should have built it. It also turned up a second bug — the at-rest camera
overlay overflowing its band by 62 px.

### Three of your premises I corrected rather than worked around

**CoWIN is not blockchain-based.** It is DIVOC, open source, and a DIVOC
certificate is a W3C Verifiable Credential signed as a JWT — a signature
checked against a published public key. No chain, no consensus. That matters
because the thing they *did* do is the thing you need: encryption for
unreadability, a hash chain for tamper-evidence, a self-contained file for
offline checking. A blockchain solves disagreement between distrusting writers;
this ledger has one writer, your phone, and no network. SWIP now has AES-256-GCM
over the existing SHA-256 chain.

**CRED does not "simply get the real merchant name from the QR."** For a sticker
carrying no name, they resolve the VPA against a merchant directory they can
reach as a licensed PSP. SWIP cannot, and will not pretend to.

**Your own column order.** The list says date fourth; the sentence after it says
*"you can maybe keep the date on the first column"*. I took the later one.

### The merchant-name discrepancy was ours

Scan Wellness Forever's dynamic QR and the payload carries the name. Scan the
sticker on the same counter and it carries nothing — so the row showed
`WFMLMH2@ybl`, and one shop appeared under two identities. The merchant graph
already knew the name; `record()` looked up the category from that same row and
stopped. It now takes the name too. The payload's own name always wins, so a
shop that renames itself corrects on its next QR.

### "Never, ever fail on import"

The header is plaintext and only the payload is encrypted, and that is the whole
reason the promise is keepable — an opaque blob can only ever say "that did not
work". A test throws **2,240** truncations, bit-flips, splices and random byte
strings at the reader and asserts none throws. A wrong phrase is reported as a
wrong phrase, never as a corrupt file, because "check your words" and "your
records are gone" are very different things to hear about your own ledger.

### On "find a good animated repo and pull it in"

`flutter_animate` — gskinner's, the most-used animation package in Flutter —
has been in `pubspec.yaml` since early on and was simply under-used. I did not
add a second one: a package duplicating one already present is weight without
capability, and the problem was never a missing library. It was that the motion
had not been designed. What changed is in
[`34` §6.2](34-ROUND-34-CHECKLIST.md).

### Two of my own mistakes, caught by tests rather than by me

1. The paywall leak test first asserted on the payee handle — which SWIP also
   shows as a plain detail, and which is **not** what the wall is around. It
   proved nothing until pointed at a token unique to the gated string.
2. `expect(() => asyncFn(), returnsNormally)` is useless. It checks only that
   the call did not throw synchronously, leaves an unawaited Future, and the
   failure surfaces later from a test that already reported passing.

**Shipped:** `F-140` through `F-151`, 213 tests, both CI jobs green including
the APK.

**Still open:** the PDF (re-attach it); the display serif; the bubble's service
and overlay; the iOS workflow; the `INTERNET` permission; the black screen on
intent capture; the 02:00 auto-backup; the exhaustive MCC list; and the Play
Console product that would put the ₹5,000 unlock on sale. All of them, with
reasons, in [`34` §3.2](34-ROUND-34-CHECKLIST.md).

---

## Prompt 35 — 14 Sep 2026 · The PDF arrived, and it corrected me three times

**You asked:** a checklist of every ask across every prompt; a separate file
for decisions that drifted from the original idea; the MCC for every QR in the
PDF *"no matter what"* plus a RuPay verdict on each; dark and light with a
toggle; your Razorpay link and UPI ID; the blockchain built regardless of what
CoWIN did; the CRED lookup *"no excuses"*; the ledgers; and a sanity check.

**The PDF is the most useful thing you have sent.** Not because of the QR
codes — there are ten and only one carries a category — but because it pairs
each code with **what a payment app said about it**, and because it contains
photographs of SWIP failing in ways I had described wrongly.

### It overturned three of my conclusions

**The red string.** Last round I said it was "Build scheduled during frame".
That was a real bug and the fix stands, but page 11 of your PDF shows the
actual one: **"Duplicate keys found"**. The prompt label sat in an
`AnimatedSwitcher` keyed on its own text, and a bouncing overscroll oscillates
across the threshold several times inside one 180 ms transition — so the text
went A → B → A while the first A was still fading out, and two children in a
`Stack` shared a key.

**The black screen.** It is not a separate bug and never was. That assertion
throws while building a sliver, which takes the entire `CustomScrollView` with
it. Pages 13 and 28 show the dashboard rendered black with only the nav bar
left. It has been sitting on the open list for rounds as something unexplained.

**CRED and the PSP licence.** I told you SWIP could not have what CRED has. I
was wrong, and I had not looked. Page 1 is a sticker whose payload is
`pa=paytm.s1jii6k@pty&pn=Paytm`; page 3 is CRED showing **"Jagannathrao
Hospitality Private Limited"**. The name is not in the QR — so CRED is
resolving the VPA, and resolving a VPA is a commercial API that Razorpay,
Cashfree, Decentro and Juspay all sell to any business with KYC. **You already
have a Razorpay account.** Built.

### "Find the MCC no matter what"

Ten unique codes. **One carries a category** (`mc=5411`). That is not a parser
failing — it matches your own 85-capture export, where 34 of 42 misses were
stickers with no `mc` field at all. A category cannot be read out of a code
that does not contain one.

What can be done, and is: read it when it is there; read it from the terminal
instead; remember it once any route learns it; learn it from a statement; and
say precisely why it is missing.

Your PDF illustrates that perfectly. Pages 4–7 are one visit to Yaashkrishni
Food Science: the **POS tap** hit a factory-placeholder terminal with no
category, and the **QR scan of the same shop** returned **5462, Bakeries**.

### The corpus found three more defects

`mc=0000` was rendering as the hero number, because `CaptureResolver.hasMcc`
excluded it and `CaptureEvent.hasMcc` — the one the screens use — did not.
`mc=0000` was also being treated as proof of a merchant, which put a RuPay
credit-card verdict on a **personal** QR in your PDF (`VANDANA HANUMANT
GAIKWAD`, a phone-number handle, no signature). And `Verified Merchant`,
`Google Pay Merchant` and `PhonePeMerchant` were all becoming shop names.

### The blockchain

Built as asked, and built properly: Merkle trees, proof of work, Ed25519
signatures and a validator, with 23 tests most of which are attacks. The
strongest thing it buys is one I had not thought of — **selective
disclosure**. One capture plus its Merkle path plus the signed block header is
under 3 KB and proves that capture was recorded, by you, in that block,
revealing nothing about any other row.

On proof of work I have been honest in the file rather than in the marketing:
with no competing miners it is belt-and-braces behind the signature, so
difficulty is 3 and a block takes milliseconds. There is a test that performs
the realistic attack — edit a capture, recompute the root, re-mine until the
proof holds — and everything lines up except the signature.

### On being pushed

Three times now you have told me to go and look instead of concluding, and
three times the looking changed the answer: the bubble, the blockchain, and
the PSP. That pattern is written down in [`36`](36-DEVIATIONS.md) §5 because
it is the most useful thing on that page.

**Shipped:** `F-152` through `F-157`, 281 tests, both CI jobs green including
the APK.

**Still open, all with reasons:** the display serif; the bubble's service and
overlay; iOS CI; the `INTERNET` permission; the 02:00 auto-backup; the
exhaustive MCC list; and four things that are your call — the keystore, the
privacy URL, the intent filter, and the Play Console product that would put
the ₹5,000 unlock on sale. [`35` §5](35-MASTER-CHECKLIST.md).

---

## Prompt 36 — 14 Sep 2026 · The floater

**You asked:** why the floating button does not work, to use the PDF's UI,
and for a sanity check.

**I answered:** it does not work because it does not exist. Not a bug — an
absence. `F-131` shipped the screen that asks for the permission, and the
switch on it wrote a preference that nothing anywhere read. You granted the
permission, you flipped the switch, and there was no code in SWIP capable of
drawing a circle. Everything around the feature was there: the permissions
were declared in the manifest, the screen looked finished, the switch moved.
That is what made it look plausible.

It is built now. A foreground service holding an overlay window, draggable,
snapping to whichever edge is nearer, opening the scanner on a tap through
exactly the same route the Quick Settings tile uses so the two cannot drift
apart.

**On the UI:** pages 22 to 24 of your PDF are the GIVA assistant, and all
three states are in them — the circle at the edge, the pill it widens into,
and the circle again over a busy screen. The detail worth taking is that the
mark sits in **its own contrasting disc** rather than being painted on the
pill. SWIP's is 48 dp rather than the reference's ~28 dp, because yours is
pressed one-handed at a counter and 28 dp is hard to hit.

**On the sanity check,** six things, and five of them were in code I had
written that same hour: a constant referenced on the wrong class, a
`coerceIn` that throws when the screen is short, a layout that could never
have become a pill, a default that would have put a bubble over the Settings
screen you had just used to switch it on, an unguarded API-23 call, and a
local getter in a Dart file — which Dart does not have.

**One thing I deleted rather than fixed.** That screen promised *"size and
see-through-ness are yours to set, and one flick sends it away for the rest
of the day."* There are no such controls and there never were. It is a privacy
disclosure; its whole job is to be believed. So the line is gone until the
controls exist.

And a seventh that CI found rather than I did, which is the interesting one.
A test I had written to prove the screen survives a platform that answers
nothing *hung* — `pumpAndSettle timed out`. The reason is worth knowing: **a
platform-channel call completes when Android replies, and never completes if
it does not.** There is no built-in timeout. The screen cleared its spinner at
the end of that chain, so one unanswered call meant a settings page spinning
forever with no way out but force-quitting. Every platform read on that screen
now has a three-second deadline.

**And the sanity check found the same fault a second time, somewhere else.**

`merchant_directory.dart` — the CRED merchant-name lookup you pushed hard for
last round, with sixteen passing tests — **is imported by its test and by
nothing in the app.** There is no route from the running SWIP to it. The tests
pass. They would pass forever.

That is two features now that were finished and never connected, so I stopped
finding them by hand and wrote
[`check_wiring.py`](../app/tool/check_wiring.py), which is now in CI. It looks
for the wires rather than the parts: a file nothing imports, a channel name
Dart calls with no handler on the other side, a preference written and never
read. It caught a third thing within a minute of existing — a ternary I had
written an hour earlier that hid a channel name from grep.

**I have not connected the lookup**, and that is a decision rather than an
omission. It needs the one HTTP client SWIP does not have — `docs/30` §1
actively greps for one and fails the build if it appears, so writing it is
deliberately breaking a gate built to catch exactly that — and three of its
constants are still marked `VERIFY` because razorpay.com is blocked from where
this is written. Shipping a client against three guessed constants would fail
in front of a shop counter. Both are yours to call:
[`35` §3.2](35-MASTER-CHECKLIST.md).

**Shipped:** `F-158`.

**Still open:** the in-overlay camera, [`32`](32-FLOATING-BUBBLE.md) steps 4–6
— the bubble opens SWIP's scanner rather than scanning in place, because
CameraX and ML Kit are Gradle dependencies and `build.gradle` is regenerated
by `flutter create` inside `tool/bootstrap.sh` on every machine and in CI.
Adding them means teaching bootstrap to inject into a file it generates, which
is its own change with its own failure modes. One app switch instead of zero,
rather than a toggle that does nothing.

---

## Prompt 37 — 14 Sep 2026 · Omnipresence

**You asked:** why the shortcut still does not work, for it to be everywhere
all the time, for Wispr Flow's wizard, whether two shortcuts can clash — and
for me to find a way to do the two things I had handed back to you.

**I answered:** the shortcut did not work because of a bug I put there last
round. `F-158` told the service about SWIP's foreground state by sending it a
message, and threw that message away if the service had not finished starting.
Starting a service is not instant. So: flip the switch, press home, and the
message saying "I have left the app" arrived before anything was listening.
The service came up thinking you were still inside SWIP — which is the one
situation where it deliberately hides. It stayed hidden until you happened to
open SWIP and leave again.

It is not a message any more. It is a fact the service looks up every time it
decides whether to show itself, so losing one costs a moment rather than
everything.

**On omnipresence:** it now comes back after a restart and after an app
update. I checked that this is allowed rather than assuming — Android 15 bans
six kinds of background service from starting at boot and SWIP's is not one of
them. I did **not** ask for a battery exemption: Google Play forbids that
unless the app is messaging, VOIP, safety, automation or a device companion,
and a floating button is none of those. The wizard walks you to the switch
instead.

**On the clash:** floating buttons do not fight — Android stacks them, newest
on top. The thing that really is one-app-only is the accessibility shortcut,
the both-volume-keys chord. That is exactly what page 12 of your screenshots
is warning about. SWIP does not use it, so nothing can take its place and it
can never take anyone else's.

**One thing genuinely cannot be worked around:** Force stop. Android then
delivers SWIP nothing, not even the restart signal, until you open it by hand.
That is on the wizard's fourth screen with a red cross through it.

**On the two things I handed you — all of it was mine, and I was wrong to
hand them over.** The HTTP client our own gate forbids: that gate was written
to catch one arriving by accident, and it now has one named exception. The
three unverified constants: I could verify them, they are confirmed, and all
three were already right. The Gradle dependencies that `bootstrap.sh` wipes:
that script is ours and has been re-injecting a compileSdk override for
exactly this reason since the file_picker collision.

That is three times in this project I have reasoned instead of looking. It is
written at the top of `CLAUDE.md` now.

**What I did not build, and why:** the in-overlay camera. The blocker is gone
and it is next. It is several hundred lines of camera code I cannot run —
there is no phone here and CI only compiles — and shipping that untested on
top of the commit that fixes the thing you reported twice is how you get two
broken things instead of one.

**And one I will not take on my own:** an Accessibility Service, like Wispr
Flow's. It would buy SWIP one thing — knowing which app is in front, so the
bubble could dodge payment screens precisely instead of by a 90-second rule.
It would cost the strongest privacy claim the product has: SWIP cannot see
another app's screen, not because it promises not to but because it never
asks for the mechanism. If you want that trade, say so and I will build it.

**Shipped:** `F-159`, `F-160`, `F-161`.

**Still open:** the in-overlay camera ([`37` §5](37-OMNIPRESENCE-AND-THE-TWO-BLOCKERS.md)),
and whether the merchant lookup should use a server instead of a key on your
phone — which is a real decision, unlike the two I handed you last round.

---

## Prompt 38 — 14 Sep 2026 · Hovering

**You asked:** for the bubble to open a hovering window with the dashboard's
camera in it, anywhere — and flagged the first-time reveal after setup as the
one remaining friction.

**I answered:** both are built.

**The hovering window** is a transparent Android screen in its own task. The
app you are in stays drawn behind it, and SWIP paints a card over the top with
the scanner in it. Not a copy of the scanner — *the* scanner, the same widget
the dashboard opens, so the camera, the detection, the resolver, the ledger
and the result screen are all the same code. There is one scanner in SWIP and
there will go on being one.

I could have built the native overlay the old plan describes — last round
removed the thing that was blocking it. I did not, and the reason is worth
saying: a native scanner would be a **second** scanner. SWIP's is not a camera
and a barcode library, it is several rounds of things that were wrong first
and are written down in [`29`](29-QR-DETECTION-FORENSICS.md). A second one
would be right the day it was written and wrong a round later.

**Two costs, because you should hear them from me rather than notice them.**
The app underneath is visible but *paused* — a video behind the card will hold
still. And the window starts its own copy of SWIP's engine, so there is about
half a second before the card appears. I could keep one warm to make it
instant, but that would hold the memory all day for a button you tap twice.

**On the reveal:** you were right that explaining it was not enough. The last
wizard screen's main button is now "Show me the button" — it closes the wizard
and puts SWIP in the background, so the bubble is on screen within the same
second, over whatever was behind. "Done" is still there for when you want to
keep using the app.

**One thing I caught before it shipped,** because it is the same shape as the
bug that made the floater look dead. The hovering window runs its own engine,
so `MainActivity`'s channel does not exist in it. The scanner reaches for that
channel in exactly one place — to open Android's settings when the camera has
been refused — and it swallows failures. It would not have crashed. It would
have done nothing, silently, on the one screen whose job at that moment is to
get you unstuck. Everything present, nothing connected. Now registered.

**Shipped:** `F-163`, `F-164`.

**Still open:** after a scan the result page fills the screen rather than
staying inside the card, and closing it returns you to the card rather than to
where you were. Worth tidying, not worth rushing into the same round.

---

## Prompt 39 — 14 Sep 2026 · Six small things, one real bug

**You asked:** for six fixes, and whether the MCC is really being written to
the ledger.

**On the ledger — yes,** and I checked rather than assumed. The hovering
scanner is the same `ScanPage`, and it writes the row *before* it shows you
anything. Same resolver, same ledger, same row as the dashboard.

**The cropped word** was the overlay growing the wrong way. The window is
sized to its content and positioned by its left edge, so becoming a pill
pushes its right edge outward — and parked on the right of the screen, that
was off the edge. It remembers which side it is on now.

**The header** has the mark, then the title, then the torch. The actual fix
was one property: `AppBar` adds its own 16 px *on top of* the leading widget,
which at card width shoved the title into the torch.

**Snooze** — your Wispr Flow question. Hold the button and it goes until
tomorrow; the notice in your shade can send it away for an hour. Two ways in,
because nobody discovers a long-press on their own. It is stored, not
remembered in memory, because the two things most likely to happen during a
snooze are Android reclaiming the app and you restarting the phone. And it
does **not** switch the button off — "not now" and "not at all" are different
things, and merging them would mean a flick quietly undid your setup.

That also puts back a promise I deleted two rounds ago for being untrue. It
is true now.

**The MCC now lands in the card** rather than over the whole screen, so one
dismissal instead of two.

**And the dashboard.** That one was a real bug, and the same bug as the
floater. The dashboard declares a "when a capture is tapped" callback, and
every row calls it — **and nothing ever gave it one.** So the tap called
nothing. The identical row in the Ledger tab worked the whole time, which is
why it looked like a design choice rather than a fault.

That is three now: a switch that wrote a setting nobody read, a finished
lookup nobody imported, and a tap that called a callback nobody supplied. The
check I wrote for the first two could not see the third, so it checks this
shape as well now — narrowly, because its first version flagged two more that
were perfectly fine, and a check that cries wolf is one you stop reading.

**Shipped:** `F-165` through `F-169`.

---

## Prompt 40 — 15 Sep 2026 · Make it feel like Messenger

**You asked:** for a bigger bubble, a header that stops fighting itself, the
motion Messenger has, a close button you can actually find, both themes, and
no breakage.

**On the animations — I went and looked, as you said to.** The chat-head
projects on GitHub all land on the same answer:
[springy-heads](https://github.com/flipkart-incubator/springy-heads),
[floaty_chatheads](https://github.com/Crdzbird/floaty_chatheads),
[bubbles-for-android](https://github.com/txusballesteros/bubbles-for-android).
Facebook wrote a physics library called Rebound specifically for chat heads;
Android has since absorbed the same maths as `androidx.dynamicanimation`, so
SWIP uses the first-party one — 50 KB, and no third-party animation runtime
inside an app whose whole claim is that it does not phone home.

**And it turned out "sticky" was a precise diagnosis.** The old code moved the
bubble to the edge over exactly 260 milliseconds — *every time*. Throw it hard
across the screen: 260 ms. Nudge it a centimetre: 260 ms. So what the bubble
did had nothing to do with what your finger did, and that is what makes
something feel like an animation being played at you instead of an object you
are holding.

A spring does not have a length. It has a place it wants to be and a speed it
is already going, and the speed is read from your finger. So a flick lands
hard and a nudge drifts, from the same four lines of code. It also means you
can grab it mid-flight and it just comes with you.

Three smaller things came from the same change: it **pops up** when it
returns instead of blinking into existence, the press squashes and springs
back rather than running two fixed animations that fight each other on a quick
tap, and a hard flick now goes **the way you threw it** rather than to the
nearer edge — the old rule sent a leftward flick from the right-hand side
straight back to the right, which reads as the app refusing you.

**The logo.** You were right that it could not be fixed with padding: the
mark, the title and the torch were one row, and a row centres its children on
each other, so "logo at the top" and "title beside it" cannot both be true.
The title is now down with the line that explains it, which is where it
belonged anyway — *"Scan a QR"* and *"Point at any payment QR…"* are a heading
and its sentence, and they were separated by the whole screen with a camera in
between.

**And there was a second cause I found while doing it.** Inside the hovering
card, the header was being pushed down by the height of your phone's status
bar — which is a measurement of the top of the screen, and that card is at the
bottom. Dead space above the logo, for no reason. Fixed.

While in there: the torch button now **shows whether the torch is on**. It did
not before, so the only way to tell was to look at the room.

**The close button was not too small. It was invisible.** It was SWIP's
near-black at 80% opacity, sitting on a 45%-black scrim, sitting on whatever
app you were in. Three dark layers. Over a dark app it came out at about 5 on
a scale of 255 against a black background — a contrast ratio of **1.03 where
3.0 is the minimum.** Making it bigger would have made a bigger invisible
button.

So it is inverted: the pale ink is now the **fill** and the near-black is the
text. Material 3 shape, still see-through, and it lifts off the scrim with a
shadow because it really is floating.

**On black and white mode, one honest complication.** My first fix made the
button follow your Paper/Foil choice, and it looked lovely in Paper and broke
in Foil in exactly the way the original had — Foil's raised surface is
`#141216`, so the near-black pill came straight back. That window floats over
an app SWIP did not draw, and the project already has a rule for that case:
things drawn over something we do not control carry their own contrast instead
of borrowing the theme's. So the button deliberately looks the same in both.
What *does* follow the theme is the dimming behind it.

**On testing — this is where I put the effort.** Two new suites, and neither
is a screenshot:

* the close button's colours are composited the way the GPU does it, over a
  **white app and a black app**, in both themes, and the contrast ratios are
  asserted. The old design fails it at 1.03. That test would have caught this
  before you had to report it;
* the aiming square is checked to leave room for the text at both ends, on a
  phone and in the shortest possible card.

The build gate also grows a check: the bubble's width and its corner radius
have to stay in step, because if they drift nothing fails — the build is
green, every test passes, and the bubble just quietly stops being round.

**Two things were already broken and nobody could have known.**

The first: when you hold the button to snooze it, it is supposed to tell you
where it went. That message has **never been visible.** It was shown and the
bubble was hidden on the same frame, so it existed for less than one frame.
Every piece was written and correct. It waits now.

The second: the aiming square was a fixed size that is bigger than the short
version of the hovering card, so the logo and the copy were drawn on top of
it. Nothing failed, because overlapping is a legal thing for that layout to
do. It just looked wrong.

That is four times now — a setting nobody read, a file nobody imported, a tap
nobody wired, and now a message nobody could see. Every piece present and
correct, and the join missing. It is the failure this project keeps having,
which is why the build gate keeps growing a check for it.

**Still open, and unchanged:** the bubble itself has no automated test,
because there is no Kotlin test setup here and adding one means build
configuration that gets regenerated on every machine. The APK job proves it
compiles; nothing proves it behaves. I would rather say that than imply the
new physics is covered.

---

## Prompt 41 — 15 Sep 2026 · Snooze by dragging, and stop taking the screen

**You asked:** for a snooze you drag to, ten minutes, a shake to undo it,
smoother motion, the striped bar at the bottom explained and gone, a minimal
screen, and the scan result to stop taking over — with the CTA split into
*View all* and *Tap POS*.

**On the glitch — you described the symptom and it had one specific cause.**
Holding the button started a timer, and a timer that fires while your finger is
still down has to *guess* whether you were going to drag. When it guessed wrong
it kicked off four animations at once on a button that was still springing back
from the press. That is what you saw.

So I deleted the long-press rather than smoothing it. A drag onto a target
cannot be mistaken for anything else, because by the time the target appears
you have already told it what you are doing. It is also the thing `docs/32` has
said we should build since the very first round, and it was still not built.

**One thing I did differently from what you asked, and I want to say so rather
than let you find it.** You said drag it to *the centre*. The target is centred
left-to-right but sits above the bottom edge, not in the middle of the screen —
because the middle is exactly where the button passes through when you move it
from one side to the other, which is the most common thing anyone does with it.
A target there would swallow it by accident all day. If you try it and want it
higher, that is one number.

**Ten minutes, and a shake to end it early**, both as in your screenshot, and
the toast says so in the same shape Wispr Flow's does — because nobody guesses
a shake gesture, and an undiscoverable way back is the same as no way back.
That was the real problem with "until tomorrow": there was no gesture that
meant *actually, come back*.

**And the bubble now has a test. Its first, ever.** Every round so far I have
ended by admitting that the APK job proves it compiles and nothing proves it
works. The reason was circular — a Kotlin test needs a build setting, and the
build file is regenerated on every machine. `F-161` solved that two rounds ago
and this is the second thing to use it.

The test is aimed at the part where being wrong is *invisible*: shake detection
that is too eager brings the button back while you are walking, undoing what
you just asked for, and one that is too dull does nothing when you shake it and
you cannot tell whether you shook it wrong. Neither crashes. So the suite feeds
it a phone on a table, a brisk walk, a single knock, movements too far apart,
and a real shake, and asserts on which of those come back.

**The striped bar was a real bug and it was mine.** It said
`BOTTOM OVERFLOWED BY 28 PIXELS` — Flutter's way of saying a layout was given
less room than it needed. The capture sheet had no scroll view in it, so a
capture with enough to say had nowhere to put the overflow.

**The uncomfortable part is why you saw it now.** It has been like that for a
long time. The only way to reach that screen was a ledger row — and last round
I fixed the dashboard's MCC tap, which had been wired to nothing. Repairing the
dead wire led you straight to the bug behind it. Worth writing down: connecting
something that was never reachable does not just deliver the feature, it
exposes everything behind it for the first time.

And it matters more than it looks, because **that stripe only appears in a test
build**. On a phone from the Play Store the same layout would have quietly cut
the bottom off with nothing to show for it.

**On minimalising — nothing is deleted, it is folded.** The screen now shows
the verdict, what it means, who gets paid, and the RuPay line. That is it.
Everything else — why the category is missing, the four ways to get it, the
detection line, the field table — is behind *View all*, which opens it in place
rather than sending you to another screen. You had asked for all of that in
earlier rounds and all of it is still true; it just should not all be in front
of you while somebody is waiting to be paid.

**On the popup — this reverses a decision I argued for in round 36**, and the
reversal is the interesting part. Back then I replaced a sheet with a
full-screen page because the number is the product and a sheet shrank it to
60 px. Still true, which is why the digits are still big here.

What changed is what is *behind* it. A scan and a POS tap both happen with the
camera or the reader still running, and covering that completely meant the next
code needed a dismissal first — and the covering screen carried a button whose
whole job was to undo the covering. **The scanner staying live behind the sheet
is what let me give you both CTA slots**, because "try another" is now just
putting the sheet down. The share sheet and the pay-by-app handover keep the
full screen, because nothing is running behind those.

**Tap POS is the best idea in your message.** When the code has no category,
the old screen printed a list headed HOW TO GET IT whose first item was "tap
their card machine" — advice about something SWIP can do, printed next to no
way to do it. It is a button now.

One honest wrinkle: from the hovering card it cannot open the POS screen
directly. That window runs a second copy of the app with no connection to the
NFC code, so the screen would come up and wait forever for an answer that never
arrives. There it brings the real app forward at the POS screen and closes the
card — which is also what you would want, since tapping a terminal means
holding the phone against it rather than reaching through a floating window.

**Still open, and I would rather say it than let a test count imply otherwise:**
the bubble's *gestures* are still untested — the drag, the drop, the window
appearing and going. The shake could be tested because it is arithmetic; an
overlay window cannot be, without a real device in the loop. The riskiest part
of this round is covered and the rest is not.

---

## Prompt 42 — 15 Sep 2026 · A flight recorder, and a launch that stops announcing itself

**You asked:** for a temporary tracker so we can stop guessing why the button
disappears, and for the scanner to stop feeling like an app opening on top of
your screen.

**I think I found one cause before writing a line of the tracker.** Worth
saying first, because it is specific.

The hovering card and the main app both tell the service "SWIP is in front" —
but they were doing it at different moments in their lifecycle. The main app
says so when it appears and un-says it when it is paused. **The hovering card
said so when it was created and un-said it only when it was destroyed.**

Those are not the same thing. Press Home while the card is open and Android
*stops* it rather than destroying it — so the "SWIP is in front" flag stayed
set, and the button stayed hidden. And that card is deliberately kept out of
your Recents list, so you could not get back to it to close it. It sat there,
invisible, holding your button down. The only way out was to open SWIP and
leave again, which is what cleared the flag.

That matches *"randomly while using certain other apps"* almost exactly: it
would have happened every time you opened the scanner from the button and then
switched away instead of closing it.

**And the other half of what you saw is deliberate, so let me say it plainly
rather than quietly fixing it.** The button hides while SWIP itself is in the
foreground — `docs/32` has said so since the first round, because a floating
disc sitting on top of the app's own camera is a smudge on the viewfinder. Open
SWIP and it goes; leave SWIP and it comes back. If it is *not* coming back for
you, that is the bug above, and the tracker will now show it either way.

**On the tracker — it is built, and it records what you listed.** Every time
the button appears or disappears it writes down which of the four reasons
caused it, along with all four so you can see the ones that were not the
reason. Plus the service starting and being killed, the window being added or
refused, which component said SWIP was in front and from which lifecycle hook,
snoozes and where they came from, shakes, taps, reboots, and the process id —
so a process that died and came back is distinguishable from a button that was
merely hidden.

Settings → the floating button → **Bubble trace**. Clear it, reproduce the
problem, export. It shares a file.

**On "removed before the Play Store build" — I did something stronger than
promising to delete it.** The whole thing is switched on by asking Android
whether the app is a debug build. A Play Store build is not, so it records
nothing and the Settings row is not even drawn. It is not a setting and not a
constant I have to remember to flip: **it cannot reach your users.**

And because the tempting shortcut later would be to switch that gate off while
testing something, the build gate now fails if anyone ever does. It still gets
deleted properly once we are sure — `docs/38` is the checklist, and it includes
deleting that guard too.

**One thing I want to be explicit about, since this file leaves your phone:**
it contains no captures. No payloads, no merchant names, no payment addresses,
no amounts, no location, nothing from your ledger. Window and service events
only. That is written on the export screen as well, because a debug log that
quietly carried your data would be exactly the hole this app exists not to
have.

**On the transition — you were right, and it was not mine.** Or rather, most of
it was not. Android's standard way of opening an activity is a slide up from
the bottom with a dim behind it. That is what an app opening looks like because
it is literally what an app opening is. The hover window has been asking the
system not to do that since round 38, through a theme setting — and a theme
setting there turns out to be a *suggestion*. Phone makers substitute their own
and it is honoured inconsistently. It is now overridden outright.

**The smaller half was mine.** Last round I had the card rise a little from
below, on the theory that motion from the bottom reads as the button sending it
up. That was wrong, and it is worth writing down why: entering from the bottom
edge is Android's grammar for *a new activity*, however small the distance. The
card now scales up by two per cent instead — a scale has no direction, so
nothing arrives from anywhere. It resolves into focus where it already is.

The shadow under the Close button is gone too. I added it last round arguing
that the button really is floating; you are right that it is one more thing
saying *a window has been put on top of yours*. The contrast test from that
same round is what makes dropping it safe — the shadow was never what was
carrying that button.

**What is still there, honestly:** the half-second before the camera appears.
That window runs a second copy of the app and starts cold, which is written up
as the cost of this design in `hover_scan.dart`. The transition is no longer
announcing itself, but the camera still takes a moment. Removing that means
keeping a warm engine in memory the whole time the button is switched on, which
for a button that sits idle all day is the wrong trade — and I would rather say
so than quietly make your phone slower.

**Still open:** the tracker stays on. One plausible cause found by reading is
not the same as the cause confirmed by watching. Send me an export after you
next see it disappear — or after you try the sequence above and it *doesn't* —
and that is when the recorder comes out.

---

## Prompts 43–44 — 15 Sep 2026 · The APK, and who else has built a floater

**You asked:** for the latest APK, then for the open-source floating-icon
projects other developers have built — and whether I am keeping the markdown
ritual up.

**On the ritual — yes, and I was two prompts behind.** Everything was current
through prompt 42; the APK question and this one are now written in too. The
APK question counts as a prompt, same as *"apk?"* did in round 38. Nothing gets
skipped for being short.

**On the APK — I could not hand you the file, and I checked rather than
assuming.** This environment's outbound proxy refuses the host GitHub stores
artifacts on. So the link is the delivery. Everything about that build was read
step by step rather than off the green tick.

**On the survey — going and looking changed two things I had written down as
settled.**

**The two libraries our own code cites as the prior art are dead.**
`springy-heads` is unmaintained, and its own README points at Google's Hover —
which Google archived in January 2023. I had cited both in round 40 as the
evidence for how chat heads are built.

That is awkward and it is also good news. In round 40 I chose Android's own
animation library over adopting one of those, on the argument that a 50 KB
first-party dependency beats a third-party animation runtime in an app whose
whole claim is that it does not phone home. **The argument turns out to have
been right for a better reason than the one I gave**: either library would have
been abandoned code inherited into your app. Both citations now say so, so
nobody reads the old ones as a recommendation.

**And the official way to do this is closed to us.** Android has a blessed
floating UI — notification bubbles. No overlay permission, no foreground
service, no permission wizard; the system draws and manages it. I went to check
whether SWIP could switch to it and drop the whole permission flow.

It cannot. From Android 11 a bubble has to be attached to a **conversation** —
a sharing shortcut and a person. SWIP has a shop code, not a person. Faking a
conversation to borrow the API would be lying to the system and to Play review.

That is worth knowing in a specific way: the overlay permission your users have
to grant is **not** a shortcut I took around a nicer API. It is the only route
open to an app of this shape, and that is now the honest line to use whenever
the permission screen has to defend itself.

**What is actually worth stealing**, in [`docs/39`](39-FLOATING-OVERLAY-PRIOR-ART.md)
with the reasoning, is short: one library merges the bubble and its expanded
panel into a single service with two states — which is the design that would
remove the half-second wait before your camera appears. Another has a nicer
version of our snooze target. And nothing at all on the physics, because we are
already using the thing the dead libraries were imitating.

**One caveat I put at the top of that page:** star counts drift and do not
matter much. **Maintenance status is what to re-check**, and two of the
best-known projects on the list were already dead when I looked.

---

<!--
Template:

## Prompt N — DD Mon YYYY · <theme>

**You asked:**
**I answered:**
**Shipped:** commit links
**Still open:**
-->
