# 34 — The checklist: everything done, everything held back

> *"Whatever you guys have done as of now and whatever you have held up from
> all the prompts that I have given you in the past three prompts, create a
> checklist first. Execute it first, and if it is failing in execution, find a
> way through it."*

This is that checklist. It covers prompts 32, 33 and 34, it says which of the
two states every item is in, and where something is still open it says **why**
rather than leaving it off the page.

---

## 0. The one thing that could not be done, stated first

**The 40-page PDF is gone and I could not read it.**

The file lived at
`/root/.claude/uploads/…/1c84b316-1000112700.pdf`. This session runs in a
container that is reclaimed after a period of inactivity, and between the
prompt arriving and the work starting the container was rebuilt — the whole
`uploads` directory no longer exists on disk. I went looking for it across the
filesystem before concluding that.

What I could do instead, and did:

* installed the PDF and image tooling that was the *original* blocker
  (`pymupdf`, `opencv`, `pillow`), so a re-upload can be read immediately;
* answered the scanning question from the evidence that **is** in the
  repository — the decoded QRs in [`29-QR-DETECTION-FORENSICS`](29-QR-DETECTION-FORENSICS.md),
  the 85-capture measurement in [`real_ledger_test.dart`](../app/test/real_ledger_test.dart),
  and the Kotlin HCE service, which turned out to contain the actual answer to
  the POS half of the question (§2).

**Re-attach the PDF and I will read every image in it.** Nothing else in this
round depends on it.

---

## 1. Why the application failed while scanning — the short version

Four distinct causes, and they are not variations of one thing. Three were
already known and fixed; the fourth is new this round and is the big one.

| # | Cause | Affects | Status |
|---|---|---|---|
| 1 | `DetectionSpeed.noDuplicates` is a single-slot memory | QR — the same code twice emits nothing | Fixed, `F-122`. [Forensics §2](29-QR-DETECTION-FORENSICS.md) |
| 2 | 81 % of misses are stickers carrying **no `mc` at all** | QR — nothing to read | Not a defect. [Measured](../app/test/real_ledger_test.dart) |
| 3 | Factory-placeholder terminals (`112233445566778`) | POS — a tap that reads nothing | Fixed, `F-138` |
| 4 | **The PPSE AID was never registered** | POS — *a tap that does nothing at all* | **Fixed this round, `F-140`** |

---

## 2. The Ribbons and Balloons POS, and every other silent tap

> *"There were multiple POS fails wherein what happened was I tried to go ahead
> near the POS, but the pop-up did not happen at all. Why did that go through?"*

### 2.1 First, what the ledger says — and what it does not

I went looking for Ribbons and Balloons in the ledger. **It is not there.**
Neither is any other row for a tap that produced nothing.

That absence *is* the finding. The POS failures already diagnosed (`F-138`)
were taps that produced a row with no category — a record exists, and you can
go and look at it. A tap where "the pop-up did not happen at all" left nothing
behind: no row, no sheet, no log. The two are completely different failures and
only one of them was ever visible to me.

So the question is not *why was the category missing*. It is **why was there no
record that a tap happened**, and that is answerable from the code.

### 2.2 The cause: a terminal's first command had nowhere to go

Every contactless POS terminal in the world opens the conversation the same
way. Not with Visa, not with RuPay:

```
SELECT 2PAY.SYS.DDF01
```

`2PAY.SYS.DDF01` is the **PPSE** — the Proximity Payment System Environment.
The terminal selects it, reads the list of payment applications that comes
back, and only then picks one and selects it properly.

Android routes host-card-emulation traffic **by AID**, against the AIDs
declared in [`apduservice.xml`](../app/android/app/src/main/res/xml/apduservice.xml).
Until this round that file declared six AIDs — Visa, Mastercard, RuPay, Amex,
JCB, UnionPay — and **not the PPSE**. So the terminal's very first command
matched nothing in Android's routing table and went unanswered.

Nothing downstream ever ran:

```
terminal:  SELECT 2PAY.SYS.DDF01   →  (nothing. no service is registered for this AID)
                                       ✗ no SELECT AID
                                       ✗ no PDOL
                                       ✗ no GET PROCESSING OPTIONS
                                       ✗ no 9F15
                                       ✗ no broadcast, no sheet, no ledger row
```

The cruellest detail is that
[`SwipListenService.kt`](../app/android/app/src/main/kotlin/in/swip/app/SwipListenService.kt)
**has always had a `ppseResponse()` function** whose entire job is to answer
that command, complete with a hand-built FCI listing all six AIDs. It was
unreachable code for the life of the feature. The service was correct; nothing
could reach it.

The AID is the ASCII of the name, in hex:

| `2` | `P` | `A` | `Y` | `.` | `S` | `Y` | `S` | `.` | `D` | `D` | `F` | `0` | `1` |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 32 | 50 | 41 | 59 | 2E | 53 | 59 | 53 | 2E | 44 | 44 | 46 | 30 | 31 |

→ `325041592E5359532E4444463031`, now the **first** entry in the aid-group.

**Verified against a working implementation**, not from memory: the
[AndroidCrypto HCE credit-card sample](https://github.com/AndroidCrypto/Android_HCE_Emulate_A_CreditCard)
registers `hcePpse` first in its payment aid-group, before the Visa and
Mastercard AIDs. Google's
[Host-based card emulation guide](https://developer.android.com/guide/topics/connectivity/nfc/hce)
describes the by-AID routing that makes it necessary.

### 2.3 The other two ways to get silence, which are still live

Fixing the routing does not make every tap produce something, so the app no
longer relies on it doing so.

| Ending | What happened | What SWIP now says |
|---|---|---|
| `read` | Selected, PDOL answered | The category, or why there is none |
| `noGpo` | Selected, then the terminal ended the exchange before asking | *"This terminal stopped halfway"* — ask the cashier to key the amount first |
| `noSelect` | The field opened and closed without a SELECT reaching us | *"The terminal never reached SWIP"* — another app holds the contactless slot |

`noSelect` is the important one, because it is usually **fixable by the user**
and it was previously indistinguishable from a broken app. Android routes the
contactless field to whichever app holds the default-payment slot; on any phone
with Google Wallet set up, that is Wallet.
[`MainActivity`](../app/android/app/src/main/kotlin/in/swip/app/MainActivity.kt)
calls `setPreferredService()` to claim the field, but **only while the Tap
screen is in the foreground**. Walk up to a terminal with SWIP in your pocket
and the tap goes to Wallet, silently.

And the third: `requireDeviceUnlock="true"` means Android will not route to the
service at all with the screen locked. Kept — a ledger writable through a
locked phone in someone else's hand is a privacy problem — but now written
down rather than discovered.

### 2.4 The change that matters most

Until this round the HCE service broadcast **only** on a successful
`GET PROCESSING OPTIONS`. Every other ending produced no broadcast at all.

That is now inverted: **every tap produces a record**, including the two that
carry no data. Silence is the worst thing this feature can do, because it is
indistinguishable from the app being broken — which is precisely how it was
reported. It is also the only way the ledger can ever answer *how often does
this actually work*, which is the largest open question in the product
([`03-RESEARCH` §3.4](03-RESEARCH-MCC-CAPTURE.md)).

---

## 3. The checklist

### 3.1 Done this round (prompt 34)

| # | Ask | Where |
|---|---|---|
| ✅ | Why POS taps produced nothing at all | §2 above, `F-140`, `F-143` |
| ✅ | Full-screen MCC result instead of a pop-up, on double-tap **and** POS | [`capture_result_page.dart`](../app/lib/widgets/capture_result_page.dart), `F-144` |
| ✅ | Bottom-stuck CTA: "Capture another" / "Try another" | Same file, `F-145` |
| ✅ | Technical details collapsed, at the very bottom, CTA below | Same file, `F-145` |
| ✅ | Paywall the raw data at ₹5,000 | [`raw_data_entitlement.dart`](../app/lib/features/paywall/raw_data_entitlement.dart), `F-146` |
| ✅ | Black-box export: encrypted, never fails on import | [`black_box.dart`](../app/lib/data/sources/black_box.dart), `F-147` |
| ✅ | Recovery phrase for the uninstall / key-reset case | [`recovery_phrase.dart`](../app/lib/features/backup/recovery_phrase.dart), `F-148` |
| ✅ | Plain line export: date, MCC, merchant, amount, newest first | [`ledger_lines.dart`](../app/lib/data/sources/ledger_lines.dart), `F-149` |
| ✅ | Merchant-name discrepancies | [`capture_repository.dart`](../app/lib/data/repositories/capture_repository.dart), `F-150`, and §5 below |
| ✅ | The pull-to-reveal red bug string | `F-141` — it was Flutter's `ErrorWidget`, see §6 |
| ✅ | Make the motion fluid | `F-151`, §6 |
| ⛔ | Read the images in the 40-page PDF | §0 — the file is gone. Re-attach it |

### 3.2 Carried forward from prompts 32 and 33 — still open

Every one of these is deliberate, and the reason is stated. None of them is
forgotten.

| Item | Why it is still open | Where it is specified |
|---|---|---|
| **Display serif for headlines** | A font file, a licence check and a `pubspec` entry. Held as its own commit on purpose: a palette flip is already the largest visual diff this project has taken, and stacking a type change on it makes a bad outcome impossible to bisect | [`33` §3.2](33-VISUAL-DIRECTION-PAPER.md) |
| **The floating bubble's service and overlay** (steps 2–6) | Step 1 shipped (`F-131`). Steps 2–6 are a foreground service, a `WindowManager` overlay, the suppression rules and a CameraX scanner — a native Android feature of real size, and the suppression rules in §2 of that doc are what decide whether it passes review at all | [`32` §6](32-FLOATING-BUBBLE.md) |
| **iOS CI (Stage 1–2)** | Needs a macOS runner at 10× minutes. The plan is written and costed; it is a decision about the budget, not about the code | [`31` §3](31-IOS-AND-IPA.md) |
| **The `INTERNET` permission** | Diagnosed: the comment justifying it referenced a feature deleted in `F-89`. Two candidates remain (Flutter's debug VM service, `geocoding`) and **the fix must be tested on a device** — guessing breaks either the debug build or the place labels | [`30` §4.1](30-PRE-LAUNCH-PARAMETERS.md) |
| **Black screen on intent capture** | Reported, not yet reproduced. Needs a device with a UPI app installed to trigger the handover | — |
| **02:00 daily auto-backup** | Now cheap to build, because `F-147` gives it something safe to write. It was not safe to schedule an automatic export of a plain-text ledger | — |
| **Exhaustive MCC list** (RuPay + Mastercard + Visa + international) | The table is real but not complete. A data task, not a code task | [`23`](23-MCC-DETECTION-MATRIX.md) |
| **Space pass** (`33` §3.3) | Partly overtaken: the full-screen result is built to the new spacing. The dashboard is not | [`33` §3.3](33-VISUAL-DIRECTION-PAPER.md) |
| **Keystore, privacy-policy URL, release log audit** | Blocking a store release, not a debug APK | [`30` §4](30-PRE-LAUNCH-PARAMETERS.md) |
| **`upi://pay` intent filter: keep or drop** | Your decision. It is the app's one untrusted input | [`30` §4.4](30-PRE-LAUNCH-PARAMETERS.md) |
| **UPI ID + Razorpay link** | **On hold at your instruction**, consciously | [`27`](27-DONATIONS.md) |

### 3.3 Declined, and still declined

| Item | Why |
|---|---|
| The cashback-arbitrage donation mechanism | A donor swipes ₹40,000, gets ~₹38,000 back, keeps the card cashback. The cashback is paid by an issuer who believes it funded a retail purchase. [`27` §3](27-DONATIONS.md) records it, and what replaces it. Everything else in that feature is built |
| A plan to avoid GST | The accurate position was given instead: a genuine donation with no quid pro quo is not a supply at all under [CBIC Circular 116/35/2019](https://taxinformation.cbic.gov.in/) |
| Scraping the LinkedIn profile photo | Behind an auth wall. The colophon falls back to a monogram; dropping `brand/avatar.jpg` in fixes it |

---

## 4. "Blockchain-powered" — what CoWIN actually did

> *"It should be blockchain-powered… go through the research papers I have
> attached to you about when India issued COVID certificates."*

**India's COVID certificates are not on a blockchain**, and this is worth
knowing rather than working around, because the thing they *did* do is exactly
the thing SWIP needs.

They were issued through [DIVOC](https://divoc.digit.org), which is open
source. A DIVOC certificate is a
[W3C Verifiable Credential](https://www.w3.org/TR/vc-data-model/) carried as a
**JSON Web Token, signed with the national authority's private key**
([RFC 7519](https://datatracker.ietf.org/doc/html/rfc7519)). Verifying one
means checking a signature against a published public key. No chain, no
consensus, no distributed ledger. The
[DIVOC certificate specification](https://divoc.digit.org/platform/divocs-verifiable-certificate-features-2.0/divocs-native-covid-19-certificate-specification)
says so, and so does the
[Linux Foundation Public Health write-up](https://www.lfph.io/2021/10/13/divoc/).
The blockchain framing came from press coverage, not from the system.

Separating the properties from the word:

| What you asked for | What actually delivers it | In SWIP |
|---|---|---|
| Nobody can read it | Encryption | **AES-256-GCM**, `F-147` |
| Nobody can alter it undetected | A hash chain, or a signature | **SHA-256 chain**, `F-127`, already shipped |
| Checkable offline, forever | A self-contained file | The envelope, `F-147` |
| Many parties agree on one history | **Consensus — a real blockchain** | **Not needed.** One device, one writer, no network |

A blockchain solves disagreement between mutually distrusting writers. This
ledger has exactly one writer — your phone — and no network. Consensus would
add nothing you do not already have, and would cost the product's main
security property and main marketing claim: that nothing leaves the device.

What **is** genuinely blockchain-shaped, and has been since `F-127`, is the
hash chain: every record commits to the digest of the one before it, so
removing or editing any row invalidates every row after it. That is the
mechanism a blockchain is built out of, minus the part that only matters when
you cannot trust the writer.

### 4.1 The recovery phrase, and the edge case it exists for

> *"If he uninstalls and the key resets for the user, he could have maybe a
> phrase to get it unlocked."*

That edge case rules out the obvious design. A random key in the Android
Keystore would be destroyed on uninstall, along with the ability to open every
backup ever made — leaving a folder of files nothing on earth can read, having
believed there was a backup. Keystore keys are non-exportable and destroyed on
uninstall **by design**.

So the key is derived from something you hold:

```
key = PBKDF2-HMAC-SHA256(
        password:  <your twelve words> + "swip.blackbox.v1",
        salt:      <16 random bytes, in the file's own header>,
        rounds:    210,000 )
```

Which is exactly the construction asked for — *"a phrase… mixing a string from
the export file and a generic app string"*:

| Part | Where it lives | Job |
|---|---|---|
| The phrase | Your head, or a piece of paper | The secret |
| The salt | The file's plaintext header | Two backups of the same ledger never share a key |
| `swip.blackbox.v1` | Compiled into the app | Domain separation; a future format can never be opened with a key derived for this one |

Twelve words, [BIP-39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki),
128 bits of entropy. The format is borrowed — no wallet compatibility is being
claimed — because the checksum catches a single mistyped word **before** any
decryption is attempted, which is the difference between *"check your words"*
and *"your records are gone"*.

### 4.2 "It should never, ever fail on import"

The header is plaintext and only the payload is encrypted, and that is the
whole reason this promise is keepable. An opaque blob can produce exactly one
error — *"that did not work"* — and you cannot tell a wrong phrase from a
truncated download from a file that was never a SWIP export.

The guarantee is enforced rather than asserted:
[`black_box_test.dart`](../app/test/black_box_test.dart) throws **2,240**
truncations, bit-flips, splices and random byte strings at the reader and
asserts that not one of them throws, plus seventeen deliberately broken
envelope shapes at the decryptor. Older plain exports from before this format
still import — a backup format that cannot read the backups you already have is
not a backup format.

---

## 5. How CRED gets the merchant name, and what SWIP can copy

> *"I have noticed some discrepancies while capturing the merchant name. How
> Cred does it? It simply gets the real merchant name from the QR."*

### 5.1 The discrepancy was SWIP's, and it is fixed

Scan Wellness Forever's **dynamic** QR at the till and the payload carries
`pn=WELLNESS FOREVER MH 2`, so the capture is named. Scan the **static sticker**
on the same counter a minute later and there is no `pn` at all — so the row
showed `WFMLMH2@ybl`, and the ledger listed one shop under two
different-looking identities. That is the discrepancy.

The merchant graph already knew the name. It had been written on the first
capture and was sitting in `display_name`; `record()` looked up the *category*
from that same row and stopped. `F-150` backfills the name, the city and the
country from the same place. The payload's own name always wins, so a shop that
renames itself corrects on its next dynamic QR.

### 5.2 What CRED has that SWIP does not

The honest layer-by-layer, extending the table in
[`29` §4](29-QR-DETECTION-FORENSICS.md):

| Layer | CRED | SWIP |
|---|---|---|
| `pn=` from the QR | yes | **yes** |
| EMVCo tag 59 / 60 (merchant name, city) | yes | **yes** |
| Handle-shape inference (`SVCMERC…`, `…payu`, `@ptys`) | yes | **yes** |
| Your own capture history on this device | no | **yes** — `F-150` |
| **NPCI / acquirer merchant directory, as a licensed PSP** | **yes** | **no, and never** |
| Their own corpus across millions of payments | **yes** | no |

**The fifth row is the answer to "how does CRED do it".** It is not a cleverer
parse of the QR. A licensed PSP can resolve a VPA against the merchant
directory it has access to by virtue of being in the payments system, which is
how a name appears for a sticker that carries none. SWIP cannot obtain that
without becoming a PSP, and fabricating it by fuzzy-matching names would be
guessing dressed as inference — see
[`merchant_reconciler.dart`](../app/lib/data/sources/merchant_reconciler.dart)
for why merging two shops that are not the same is the single most damaging
thing this app could do.

The fourth row is the one SWIP can *earn*, and now does.

### 5.3 The names SWIP deliberately refuses

Worth restating, because it looks like a bug and is not:

| Payload | SWIP shows | Why |
|---|---|---|
| `pn=Paytm` | the handle | Paytm is the payment company, not the shop. Every Paytm sticker in the country says this — `F-42` |
| `pn=BharatPe Merchant` | the handle | A placeholder, not a name |
| `pn=SVCMERC00306934` | the handle | A merchant reference number echoed into the name field — `F-139` |

The plain line export (`F-149`) shows the **verbatim** name anyway, because
*"exactly captured"* means exactly captured — with SWIP's reading in brackets
beside it where the two disagree. Nothing is hidden; both are shown.

---

## 6. The red bug string, and the motion

### 6.1 What the red string actually was

> *"There's some red-colored bug-long string. It's not fluid enough."*

It is Flutter's `ErrorWidget` — the full-width red panel of small text that a
debug build renders in place of a widget that threw during build. The text
reads **"Build scheduled during frame"**.

The cause, reproduced in a test before it was touched:

`PullController` wrote to a `ValueNotifier` from inside a scroll notification.
That is legal when a finger is dragging, because pointer events arrive between
frames. It is **not** legal when the notification comes from the scroll view's
own physics: a bouncing scroll position springs back under a ticker, which runs
*inside* the frame, so the write scheduled a build mid-frame and tripped the
assertion — at the exact moment the pull was released, which is why the gesture
looked like it "broke on release".

Writes are now deferred to a post-frame callback when the scheduler is
mid-frame. A finger actually dragging still writes inline, so the rubber band
is untouched.

**Every one of the five existing `PullController` tests passed on the broken
build**, because a synthetic notification is dispatched from test code, i.e.
between frames, where the write is legal. The new test drags a *real*
dashboard past the end of its content and asserts nothing is thrown. This is
the same lesson as the recurring one in [`CLAUDE.md`](../CLAUDE.md): read the
built thing, not the code that should have built it.

A second bug fell out of the same test: the at-rest camera overlay was
overflowing the 208 dp band by 62 px, painting the yellow-and-black stripe over
the viewfinder (`F-142`).

### 6.2 The motion, and the "animation repo"

> *"Go and find some good animated repo on the internet, pull it in."*

The project already depends on
[`flutter_animate`](https://pub.dev/packages/flutter_animate) — gskinner's, and
the most-used animation package in the Flutter ecosystem. It is the repo that
would have been chosen; it has been in `pubspec.yaml` since early on and was
simply being under-used. **I have not added a second animation dependency**,
because a package that duplicates one already present is weight without
capability, and the problem was never a missing library. It was that the
motion had not been designed.

What changed (`F-151`), all of it argued in
[`33` §3.4](33-VISUAL-DIRECTION-PAPER.md)'s terms — *nothing moves unless it is
telling you something changed*:

| Change | Reason |
|---|---|
| The hint chevron breathes **six times and stops**, instead of forever | A thing twitching at the foot of the page while you read the paragraph above it is read as a fault, not an invitation. It restarts when you scroll back to the foot |
| The chevron **rotates** to point the other way across the last of the overshoot | Colour alone is a gradient with no edge in it — you cannot tell from a slightly darker grey whether you have pulled far enough. A chevron that has turned over has crossed something |
| The panel opens on `easeOutBack`, not `easeOutCubic` | It overshoots and settles, which is what a panel released under tension does — and this one is literally released from tension, so the motion describes the gesture rather than decorating it |
| Opening is **slower than closing** — 420 ms out, 260 ms back | Opening is the payoff and wants to be watched; closing is dismissal and wants to be over. Matching them makes the open feel hurried and the close reluctant, which is backwards, and is most of what "not fluid enough" describes |
| The sign-off lifts 8 px and fades as the panel rises | The page reads as one thing making room for another rather than two things stacked |
| The MCC's foil sweep is **capped at four sweeps** | `F-85` argued for repeating rather than sweeping once, and that still holds — but it was written when the number lived in a sheet people dismissed in seconds. `F-144` gave it a whole page, which people sit and read, and a highlight crossing the same four digits every 2.5 seconds forever is a strobe |

---

## 7. The paywall, and the line it has to stay on the right side of

> *"Someone might replicate our application, seeing the captured string from
> the POS, the URL… we put up maybe a paywall of nearly 5,000 to unlock it."*

**Behind the wall:** the verbatim payload — the full `upi://pay?…` string and
the full APDU trace of a POS exchange. That is the raw material somebody would
need to build a competing reader without doing the work of knowing what the
bytes mean.

**Never behind the wall**, and this half matters more:

* the category and its name;
* the merchant, the tier, the RuPay outlook, why a category is missing, and
  every route to finding one;
* every capture in the ledger;
* **both exports — including the encrypted backup, which contains the payloads
  in full.** It is your data. Holding it hostage would be indefensible, and the
  backup is encrypted to *your* key, not to SWIP's.

So the wall is around a **view**, not around data. What ₹5,000 buys is reading
the payload inside the app, which is the surface a competitor would actually
use.

Two implementation notes that are really design decisions:

* **The locked state shows the payload's shape, not a blur.** A blur is a
  rendering effect over a widget that still holds the string — a screenshot, a
  text-scale change or an accessibility reader recovers it. When locked, the
  payload is **not in the widget tree at all**, and
  [a test](../app/test/capture_result_page_test.dart) walks every `Text` and
  `SelectableText` to prove it. What is shown instead is *"UPI payment code ·
  72 characters · 6 fields"*, which tells you what you would get and lets you
  reconstruct nothing.
* **A donation is not this purchase.** `support_story.dart` used to say *"no
  part of SWIP is behind it"*, which would have become a lie the day this
  shipped. It now says a donation unlocks nothing *including this*. Keeping
  them apart is the GST boundary as well as the honesty one: a donation that
  confers a benefit stops being a donation — [`27` §2](27-DONATIONS.md).

**It is not on sale yet.** The product does not exist in the Play Console, there
is no signed build, and today every device sees *"This unlock is not on sale
yet. Everything else in SWIP works without it."*

---

## 8. What was verified, and how

Nothing in this round is asserted from memory where it could be checked.

| Claim | How it was checked |
|---|---|
| The PPSE AID must be registered | Read [Google's HCE guide](https://developer.android.com/guide/topics/connectivity/nfc/hce), then fetched a [working HCE payment app's `apduservice.xml`](https://github.com/AndroidCrypto/Android_HCE_Emulate_A_CreditCard) and confirmed `hcePpse` is registered first |
| CoWIN is not blockchain-based | [DIVOC's own specification](https://divoc.digit.org/platform/divocs-verifiable-certificate-features-2.0/divocs-native-covid-19-certificate-specification) and the [LFPH write-up](https://www.lfph.io/2021/10/13/divoc/) |
| The red string is "Build scheduled during frame" | Reproduced in a test by dragging the real dashboard, before changing a line |
| The at-rest overlay overflows by 62 px | Same test run, same output |
| PBKDF2 at 210,000 rounds costs ~956 ms | Benchmarked at 60k / 120k / 210k before choosing |
| The import never throws | 2,240 fuzzed inputs |
| The locked payload is not in the tree | Walked every text widget in a rendered page |
| Both CI jobs pass, **APK included** | [Run 58](https://github.com/adityamaurya/SWIP/actions/runs/34792136786), [run 59](https://github.com/adityamaurya/SWIP/actions/runs/34792702165) — both jobs, not just the rollup |

And two of my own mistakes, caught by the tests rather than by me:

1. The paywall leak test first asserted on the payee handle, which SWIP also
   shows as a plain detail and which is **not** what the wall is around. It
   proved nothing until it was pointed at a token unique to the gated string.
2. `expect(() => asyncFn(), returnsNormally)` is useless — it only checks the
   call did not throw *synchronously*, leaves an unawaited Future, and the
   failure surfaces later from a test that already reported passing.

---

## Sources

- [Android — Host-based card emulation](https://developer.android.com/guide/topics/connectivity/nfc/hce)
- [AndroidCrypto — HCE credit-card emulation sample](https://github.com/AndroidCrypto/Android_HCE_Emulate_A_CreditCard)
- [DIVOC — native COVID-19 certificate specification](https://divoc.digit.org/platform/divocs-verifiable-certificate-features-2.0/divocs-native-covid-19-certificate-specification)
- [Linux Foundation Public Health — DIVOC](https://www.lfph.io/2021/10/13/divoc/)
- [W3C — Verifiable Credentials Data Model](https://www.w3.org/TR/vc-data-model/)
- [RFC 7519 — JSON Web Token](https://datatracker.ietf.org/doc/html/rfc7519)
- [BIP-39 — mnemonic code for generating deterministic keys](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki)
- [OWASP — Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [`flutter_animate`](https://pub.dev/packages/flutter_animate)
- [`cryptography`](https://pub.dev/packages/cryptography), [`bip39`](https://pub.dev/packages/bip39), [`in_app_purchase`](https://pub.dev/packages/in_app_purchase)
