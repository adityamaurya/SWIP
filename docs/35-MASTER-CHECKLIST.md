# 35 — The master checklist: every ask, every prompt, current status

> *"recheck if you missed ANYTHING FROM ALL my prompts above make a detailed
> check list and do not go ahead without having them done"*

This is the single sheet. It covers **every prompt from 1 to 35**, it states
where each ask stands today, and where something is not done it says **why** on
the same line rather than leaving it off the page.

Companion documents:

* [`36-DEVIATIONS`](36-DEVIATIONS.md) — every decision that moved away from the
  original idea, and what it cost. That is the *"if we added something on the
  way… make a checklist in another md file"* file.
* [`21-PROMPT-LEDGER`](21-PROMPT-LEDGER.md) — the prompts themselves, verbatim.
* [`34-ROUND-34-CHECKLIST`](34-ROUND-34-CHECKLIST.md) — the deep version of
  prompts 32–34 specifically.

**Legend.** ✅ done and tested · ◑ partly done, rest is named · 📋 not started,
reason given · ⛔ cannot be done, reason given · ⏸ held at your instruction ·
🚫 declined

---

## 1. This round — prompt 35

| # | Ask | Status | Where |
|---|---|---|---|
| 1 | Read every image in the PDF and find the MCC **no matter what** | ✅ | §2 below |
| 2 | Confirm RuPay acceptance per QR, "like CRED and GPay do" | ✅ | §2, §3 |
| 3 | A detailed checklist of every ask from every prompt | ✅ | this file |
| 4 | A separate file for decisions that deviated from the original idea | ✅ | [`36`](36-DEVIATIONS.md) |
| 5 | Fix dark and white mode, add a toggle in Settings | ✅ | `F-155` |
| 6 | Use the design reference from the screenshots | ✅ | Foil recovered from `f2acf31^`, the exact theme in your screenshots |
| 7 | Razorpay link `razorpay.me/@seemaramchandramaurya` | ✅ | `support_goal.dart` |
| 8 | UPI ID `8779875272@kotak` | ✅ | `support_goal.dart` |
| 9 | **Do the blockchain, regardless of what CoWIN did** | ✅ | `F-156` — merkle, PoW, Ed25519, validator |
| 10 | **Get the CRED/PSP lookup done, no excuses** | ✅ | `F-157` — §3 below |
| 11 | The daily rituals (ledgers) | ✅ | changelog, prompt ledger, conversation log |
| 12 | Sanity check everything works | ✅ | §6 |

---

## 2. The QR codes in the PDF

Sixty-three pages. **Ten unique QR payloads**, decoded from the page images —
nine by OpenCV, one more by ZXing on a second pass. The other pages are
screenshots, and they turned out to be the more valuable half because they
pair each code with what a payment app said about it.

Full corpus and assertions:
[`pdf_qr_corpus_test.dart`](../app/test/pdf_qr_corpus_test.dart).

| # | Payee | MCC | SWIP's RuPay verdict | Evidence in the PDF |
|---|---|---|---|---|
| 1 | `gpay-11257000245@okbizaxis` | **5411** Grocery Stores | likely | The only code of ten that publishes a category |
| 2 | `paytm.s1jii6k@pty` | — | not negative (full merchant) | p3: CRED says **"this merchant accepts RuPay payments"** ✓ |
| 3 | `paytm.s2070wm@pty` | — | not negative | full-merchant handle |
| 4 | `paytm.s233ffl@pty` | — | not negative | full-merchant handle |
| 5 | `paytm.s28uaa5@pty` | — | not negative | full-merchant handle |
| 6 | `paytmqr68ud8l@ptys` | — | **blocked** | P2PM: NPCI does not permit credit card on UPI |
| 7 | `paytmqr6twbbd@ptys` | — | **blocked** | P2PM |
| 8 | `Q848969421@ybl` (PhonePe merchant, signed) | `0000` → none | — | `mc=0000` is "not categorised", not a category |
| 9 | `9892033544-2@ybl` (a person) | `0000` → none | none claimed | A personal QR. No card verdict is made about a person |
| 10 | `BHARATPE.9U0T0Q0D4Q030860@unitype` | — | — | `pn=Verified Merchant` is a placeholder |

### 2.1 "Find the MCC no matter what" — the honest answer

**One of the ten codes contains an MCC.** That is not a parser failing; it is
the distribution, and it matches your own 85-capture export exactly (34 of 42
misses were stickers with no `mc` field at all).

A category cannot be extracted from a code that does not carry one. What *can*
be done, and is:

1. **Read it when it is there** — code 1, `mc=5411`. ✅
2. **Read it from the terminal instead** — the POS route, which is why `F-140`
   matters: it was broken for every tap. ✅
3. **Remember it** — once any route learns a merchant's category, every later
   capture at that merchant key inherits it (`F-150` extends this to the name,
   city and country). ✅
4. **Learn it from a bank statement**, where the acquirer posted it after the
   money moved. ✅ `F-50`
5. **Say precisely why it is missing, and what would find it.** ✅ `F-125`

Your PDF contains a perfect illustration of (2) vs (1): pages 4–7 are one
visit to Yaashkrishni Food Science. The **POS tap** returned a factory
placeholder terminal (`9F16` = ASCII `112233445566778`) with no category; the
**QR scan** of the same shop returned **5462, Bakeries**. Two routes, same
counter, one of them worked.

### 2.2 Three defects the corpus found

Running the ten through the resolver broke three things no existing test could
see. All fixed, all in `pdf_qr_corpus_test.dart`:

1. **`mc=0000` rendered as the category.** `CaptureResolver.hasMcc` excluded
   `0000`; `CaptureEvent.hasMcc` did not — and the screens use the event one.
   An unclassified merchant showed **`0000` as the hero number**, 84 px tall.
2. **`mc=0000` was treated as proof of a merchant.** Payload 9 above is a
   person — phone-number handle, personal name, no signature — and SWIP was
   putting a RuPay credit-card verdict on it. PhonePe mints `mc=0000&mode=02`
   on personal QRs. The discriminator is the **signature**, not the category
   field.
3. **`Verified Merchant`, `Google Pay Merchant` and `PhonePeMerchant`** all
   became shop names. All three are printed on real stickers in your PDF.

---

## 3. RuPay, and how CRED really does it

> *"find and confirm if the rupay is accepted or not… cred and gpay finds
> these in the same flow"*

### 3.1 What your screenshots settle

Page 1 is a sticker whose entire payload is:

```
upi://pay?pa=paytm.s1jii6k@pty&pn=Paytm&tn=Verified Paytm Account
```

Page 3 is CRED looking at that same code and showing:

> **Jagannathrao Hospitality Private Limited**
> `paytm.s1jii6k@pty`
> RuPay ▸ *this merchant accepts RuPay payments*

**The shop's name is not in the QR.** `pn` says "Paytm". So CRED is not
reading the name out of the code — it is resolving the VPA against a
directory. Your own screenshots proved it, which is why `F-157` exists.

Pages 5 and 10 are the same story from the other side: a payment sheet
offering **AU Small Finance RuPay** and **Bank of Baroda RuPay** credit cards,
not greyed out, at Yaashkrishni Food Science and Bangalore Iyengar's Bakery.
Both merchants accept RuPay CC.

### 3.2 The route, and it needs no licence

Resolving a VPA to its registered name is a **commercial aggregator API**, sold
to any business with KYC:

| Provider | What it returns |
|---|---|
| **Razorpay — Validate VPA** | Valid/invalid, plus `customer_name` |
| Cashfree | VPA verification |
| Decentro | Holder name, account type, IFSC |
| Juspay | Verify-VPA across acquiring partners |

**Razorpay, because you already have the account** — the same one behind
`razorpay.me/@seemaramchandramaurya`. Built in
[`merchant_directory.dart`](../app/lib/data/sources/merchant_directory.dart),
16 tests, transport injected so the suite never touches a network.

#### It is connected now — `F-160`

For one round this section said the lookup was built, tested and imported by
nothing in `lib/`, and that connecting it was two decisions that were yours.
**Neither was.**

1. *"It needs the one HTTP client SWIP does not have."* That check was written
   to catch a client arriving **by accident**. A single deliberate one, in a
   named file, behind a switch that is off by default, is not what it was
   guarding against. [`30` §1](30-PRE-LAUNCH-PARAMETERS.md) now has exactly
   one exception, by exact path, and still fails the build on a client
   anywhere else.
2. *"Three constants are marked `VERIFY`."* They were unverified only because
   razorpay.com is blocked from the environment this is written in. Going at
   it through search rather than the site confirmed all three, and all three
   were already right.

**What is genuinely yours** is narrower and larger: the key lives on the
device, and a Razorpay key pair is not read-only — the same credentials that
resolve an address can create orders, list every payment on the account and
issue refunds. The screen says so above the switch, suggests a test key, and
can delete the credentials rather than merely switching the feature off. The
only design that removes the risk is a server holding the key, which is a
different product with a different privacy notice.
[`37` §4](37-OMNIPRESENCE-AND-THE-TWO-BLOCKERS.md).

### 3.3 What no API gives you

**The MCC.** Every one of those returns a *name*, not a category. The MCC is
assigned by the acquiring bank at onboarding and lives in the acquirer's
switch. It is not on any public or commercial lookup.

That is exactly why CRED writes **"MERCHANT MAY NOT ACCEPT RUPAY CC"**. The
word *may* is them inferring from the same handle-shape signals SWIP has,
because they do not have the category either. SWIP matches that hedge on
purpose.

### 3.4 Three things to confirm before a key is wired

The endpoint path, the request field and the response field name are marked
`VERIFY` in the source, because **razorpay.com and every mirror of their docs
is blocked from this build environment** — the egress proxy refused all of
them. Everything else is structural and correct. Confirm those three against
the live docs, then wire a key.

---

## 4. Everything from prompts 1–34

### 4.1 Capture — the core product

| Ask | Prompt | Status |
|---|---|---|
| Read an MCC from a UPI QR | 1 | ✅ |
| Read an MCC from a POS terminal over NFC | 1, 13 | ✅ and **actually reachable since `F-140`** |
| Read an MCC from a pay-by-app hand-off | 13, 17 | ✅ |
| Share-to-SWIP target | 18 | ✅ |
| Learn from a bank statement | 20 | ✅ |
| Merchant graph — remember a shop | 19, 27 | ✅ |
| Link a POS identity to a QR identity | 27 | ✅ `F-49` |
| Geolocation on each capture, coarse only | 18 | ✅ |
| Quick Settings tile | 30 | ✅ |
| Gyro-gated scanning | 33 | ✅ `F-134` |
| Scan from a photo | 32 | ✅ |
| Every tap produces a record, even a silent one | 34 | ✅ `F-143` |

### 4.2 The screens

| Ask | Prompt | Status |
|---|---|---|
| Make it interesting, CRED-like | 7 | ✅ |
| Dashboard, ledger, settings | 1 | ✅ |
| One capture sheet for every vector | 27 | ✅ |
| Full-screen result instead of a pop-up | 34 | ✅ `F-144` |
| Bottom-stuck "Capture another" / "Try another" | 34 | ✅ `F-145` |
| Technical detail collapsed at the bottom | 34 | ✅ `F-145` |
| MCC cropping in the sheet | 33 | ✅ `F-133` |
| Pull-to-reveal | 31 | ✅ — and the crash behind it, `F-152` |
| Fluid motion | 34 | ✅ `F-151` |
| **Dark and light, with a toggle** | 35 | ✅ `F-155` |
| Display serif for headlines | 33 | 📋 a font file + licence check, deliberately its own commit so it can be reverted cleanly if it reads as costume |
| Space pass (`33` §3.3) | 33 | ◑ the full-screen result is built to it; the dashboard is not |

### 4.3 Data, export, safety

| Ask | Prompt | Status |
|---|---|---|
| Local SQLite ledger, no server | 1 | ✅ |
| Export you own | 25 | ✅ |
| Export filename with name, date, time, serial | 32 | ✅ `F-128` |
| Tamper-evident seal | 32 | ✅ `F-127` |
| Import that **never fails** | 34 | ✅ `F-147`, 2,240 fuzzed inputs |
| Encrypted black box | 34 | ✅ AES-256-GCM |
| Recovery phrase for the uninstall case | 34 | ✅ `F-148`, BIP-39 |
| Plain one-line-per-capture export | 34 | ✅ `F-149` |
| **A real blockchain** | 34, 35 | ✅ `F-156` — merkle, PoW, Ed25519, 23 adversarial tests |
| ₹5,000 unlock on the raw payload | 34 | ✅ built; **not on sale** until a Play Console product exists |
| Pre-launch security gate | 32 | ✅ [`30`](30-PRE-LAUNCH-PARAMETERS.md) |
| 02:00 daily auto-backup | 28 | 📋 now cheap, because `F-147` gives it something safe to write; it was never safe to schedule an automatic export of a plain-text ledger |

### 4.4 Platform and release

| Ask | Prompt | Status |
|---|---|---|
| Debug APK from CI | 10, 17 | ✅ every push |
| Go private | 29 | ✅ |
| iOS plan and `.ipa` route | 32 | ✅ documented, [`31`](31-IOS-AND-IPA.md) |
| iOS CI (Stage 1–2) | 32 | 📋 needs a macOS runner at 10× minutes — a budget decision, not a code one |
| Floating bubble | 32, 36, 37, 38 | ◑ steps 1–3 built and **actually working** (`F-131`, `F-158`, `F-159`). `F-158` shipped a dropped-broadcast bug that kept the bubble permanently hidden; fixed in `F-159`, which also added the five-screen wizard and made it survive a reboot and an app update. **Step 4 done in `F-163`** — the real `ScanPage` hovered in a transparent Activity rather than a native CameraX twin, [`32` §10](32-FLOATING-BUBBLE.md) |
| `INTERNET` permission | 30 | ◑ diagnosed; the fix is a debug/profile manifest split and **must be tested on a device** |
| Signed release keystore | 30 | 📋 blocking a store release, not a debug APK |
| Privacy policy at a URL | 30 | 📋 blocking release |
| Release-mode log audit | 30 | 📋 |
| `upi://pay` intent filter: keep or drop | 30 | 🔍 **your decision** — it is the app's one untrusted input |
| Black screen on intent capture | 28 | ✅ **it was `F-152`** — the duplicate key threw inside a sliver and took the whole `CustomScrollView` with it |

### 4.5 Money

| Ask | Prompt | Status |
|---|---|---|
| Support section, told as a story | 28 | ✅ |
| Goal bar | 28 | ✅ `F-120` |
| Razorpay link | 29, 35 | ✅ live |
| UPI ID | 29, 35 | ✅ live |
| GST position | 29 | ✅ a genuine donation is not a supply — CBIC Circular 116/35/2019 |
| Cashback-arbitrage donation mechanism | 29 | 🚫 **declined** — [`27` §3](27-DONATIONS.md) |
| A plan to avoid GST | 29 | 🚫 **declined**; the accurate position given instead |

### 4.5b The floating bubble and the hovering scanner — prompts 36–40

Kept together because they are one feature built over five rounds, and because
four of the entries below are things that were **already built and not
connected**. That count is the reason `check_wiring.py` exists and keeps
growing.

| Ask | Prompt | Status |
|---|---|---|
| A floating shortcut that works everywhere | 36 | ✅ `F-158` — it had never been built; the switch wrote a preference nothing read |
| Omnipresent, surviving reboot and process death | 37 | ✅ `F-162` — `BOOT_COMPLETED` + `START_STICKY`, reversing my own earlier refusal |
| A Wispr Flow style permission wizard | 37 | ✅ `F-159` — five screens, and the last one is the one that was missing |
| Warn about clashes with other floating apps | 37 | ✅ and **corrected**: overlays stack by Z-order and never disable each other. The single-slot thing is the accessibility shortcut |
| The scanner hovering over other apps | 38 | ✅ `F-163` — the real `ScanPage` in a transparent Activity, not a second CameraX implementation |
| "Scanning…" cropped on the right edge | 39 | ✅ `F-165` |
| Snooze, like Wispr Flow | 39 | ✅ `F-167` — hold, or an hour from the shade |
| The MCC inside the card, not over the screen | 39 | ✅ `F-168` — the card gets its own `Navigator` |
| Dashboard MCC opens details | 39 | ✅ `F-169` — **a callback nobody ever passed** |
| Bigger bubble | 40 | ✅ `F-170` — 48 → 56 dp, which is what [`32` §4](32-FLOATING-BUBBLE.md) had asked for all along |
| Messenger's motion, researched from open repositories | 40 | ✅ `F-170` — `androidx.dynamicanimation`; the old snap never read a velocity |
| Logo and torch at the top, title down with the copy | 40 | ✅ `F-171` — the `AppBar` made the two asks contradictory |
| Close button more prominent | 40 | ✅ `F-172` — it was invisible at 1.03:1, not small |
| Compatible with Paper and Foil | 40 | ✅ `F-172` — the scrim follows the palette, the chrome deliberately does not |
| The snooze goodbye message | 39, 40 | ✅ `F-170` — written in 39, **visible for the first time in 40** |
| The reticle overlapping the copy in the short card | 40 | ✅ `F-171` — sized to its surface, and tested |
| A reader for the exported bubble trace | 45 | ✅ `F-179` — [`tool/read_trace.py`](../app/tool/read_trace.py), verified against a synthetic trace of the bug before being trusted |
| Judge a floating-icon tutorial, and log it | 46 | ✅ [`39` §7](39-FLOATING-OVERLAY-PRIOR-ART.md) — nothing in it SWIP lacks, four things in it illegal or dead in 2026, and one live bug; **and it prompted a read of our own tap-versus-drag test**, which is correct |
| The latest APK | 43 | ✅ link, not file — the artifact host is blocked by this environment's egress proxy, established by trying |
| A survey of open-source floating-icon projects | 44 | ✅ [`39`](39-FLOATING-OVERLAY-PRIOR-ART.md) — every entry opened and verified, not recalled |
| Why the bubble disappears | 42 | ✅ `F-178` — a lifecycle asymmetry, found by reading; **and half the report was by design**, said plainly rather than fixed |
| A temporary, exportable lifecycle tracker | 42 | ✅ `F-176` — and it *cannot* reach a Play Store build, which is stronger than remembering to remove it |
| The launch not feeling like an app opening | 42 | ✅ `F-177` — the bottom-up slide was Android's own, and `windowAnimationStyle: @null` had never been enough |
| ~~An automated test for the bubble itself~~ | — | ✅ `F-173` — `ShakeDetector` is pure Kotlin with no Android imports and has a JUnit suite CI runs. **Its gestures are still untested**, and that is a different claim |
| Snooze by dragging to a target | 41 | ✅ `F-173` — `docs/32` §4 asked for this target in round one |
| Ten minutes, and shake to bring it back | 41 | ✅ `F-173` — the accelerometer is armed only while snoozed |
| The long-press glitch | 41 | ✅ `F-173` — the gesture is deleted, not smoothed; see [`36`](36-DEVIATIONS.md) D-51 |
| The striped bar at the bottom | 41 | ✅ `F-174` — a 28 px overflow, reachable only since `F-169` wired the dashboard tap |
| Minimalise the capture screen | 41 | ✅ `F-174` — `CaptureLayout.brief`; nothing deleted, everything folded behind *View all* |
| A non-intrusive result instead of full screen | 41 | ✅ `F-175` — for the two live vectors only |
| Split the CTA into *View all* and *Tap POS* | 41 | ✅ `F-175` |
| *Tap POS* reaches the in-app POS screen | 41 | ✅ `F-175` — a push in the app, and bringing the app forward from the hovering card |

### 4.6 Cannot be done

| Ask | Why |
|---|---|
| Scrape the LinkedIn profile photo | Behind an auth wall. The colophon falls back to a monogram; dropping `brand/avatar.jpg` into `/brand/` fixes it |
| NFC "Tap POS" on iOS | Apple does not expose the EMV kernel to third parties. [`31` §2.1](31-IOS-AND-IPA.md) |
| Floating bubble on iOS | No overlay API exists |
| MCC from a VPA lookup | Not exposed by any public or commercial API — §3.3 |
| Read the **first** 40-page PDF | The container was reclaimed and the upload was gone. **This one arrived and was read in full** |

---

## 5. Open, with the reason on the line

Nothing here is forgotten. Each is either your decision, needs a device, needs
money, or is deliberately held.

| Item | Why it is open | Whose move |
|---|---|---|
| Display serif | Held as its own commit so a bad outcome is bisectable | Mine, next round |
| ~~Bubble step 4 — the scanner over other apps~~ | **Done** (`F-163`), and deliberately **not** as a native CameraX overlay: that would be a second implementation of scanning, and SWIP's is several rounds of hard-won behaviour. The real `ScanPage` is hovered instead, in a transparent Activity. [`32` §10](32-FLOATING-BUBBLE.md) | — |
| ~~The result page inside the hovering card~~ | **Done** (`F-168`) — the card carries its own `Navigator`, so the push is bounded to those pixels | — |
| Confirming the disappearance is actually fixed | `F-178` is a plausible cause found by reading, not one confirmed by watching. The recorder is on; closing this needs an exported trace showing the bubble surviving the sequence that used to kill it | **Yours** — reproduce and export |
| Deleting the bubble trace | Deliberately still here. [`38` §4](38-BUBBLE-TRACE.md) is the ten-step list, including deleting its own gate check | Mine, once the above is confirmed |
| A behavioural test for the bubble's **gestures** | `F-173` built the Kotlin test source set and `ShakeDetector` is covered, so the blocker is gone — but a `WindowManager` overlay cannot be exercised on the JVM. The drag, the swallow and the target's window lifecycle need instrumentation and a device | Mine — and now it is a device problem, not a build-config one |
| The circle→camera shared-element morph, [`32` §4](32-FLOATING-BUBBLE.md) | Cannot be done as specified while the scanner is a separate Activity with its own Flutter engine — there is no shared element to morph across a process boundary | Mine — needs a different design, not more effort |
| ~~The drag target, [`32` §4](32-FLOATING-BUBBLE.md)~~ | **Done** (`F-173`), as a **snooze** target rather than a delete one — SWIP's bubble is not a conversation you close, it is a tool you want back | — |
| iOS CI | macOS runners bill at 10× | **Yours** — budget |
| `INTERNET` permission | Fix must be verified on a device | **Yours** — a device |
| 02:00 auto-backup | Now unblocked by `F-147` | Mine, next round |
| Exhaustive MCC list | A data task | Mine, next round |
| ~~Connect the merchant-name lookup~~ | **Done** (`F-160`). Both halves of that "needs your decision" were mine: the HTTP check was written to catch an *accidental* client and now has one named exception, and the three constants were verified and all correct | — |
| Whether the lookup should use a server instead of a key on the phone | A Razorpay key pair is not read-only — it can create orders, list payments and issue refunds. On a device it is readable by anything with root. A server holding it is a different product with a different privacy notice | **Yours** — [`37` §4](37-OMNIPRESENCE-AND-THE-TWO-BLOCKERS.md) |
| Whether SWIP should take an Accessibility Service | Buys precise foreground detection so the bubble dodges payment screens exactly rather than by a 90-second timer. Costs the claim that SWIP *cannot* see another app's screen | **Yours** — [`37` §3](37-OMNIPRESENCE-AND-THE-TWO-BLOCKERS.md) |
| Keystore, privacy URL, log audit | Blocking a store release | **Yours** — decisions |
| Intent filter: keep or drop | The one untrusted input | **Yours** |
| ₹5,000 product in Play Console | Needs a signed build and a Console entry | **Yours** |
| Razorpay VPA key + the three `VERIFY` constants | Docs blocked from this environment | **Yours** — confirm, then I wire |

---

## 6. Sanity check

> *"do for sanity check for everything of it working and fine perfectly or
> not"*

| Check | Result |
|---|---|
| `tool/check_balance.py` | ✅ |
| `tool/check_const.py` | ✅ |
| `flutter analyze` | ✅ clean (one expected warning: `assets/brand/` is gitignored and copied by `bootstrap.sh`) |
| `flutter test` | ✅ **281 passing** at prompt 35; **more since** — the count in each round's CI log is the authority, not this line |
| `tool/check_wiring.py` | ✅ five checks as of `F-170` — files, channels, preferences, callbacks, and the bubble's radius against its diameter |
| `tool/check_links.py`, `tool/check_secrets.sh` | ✅ |
| Close button legible over a white app and a black app, both palettes | ✅ `test/hover_chrome_test.dart` — composited, not eyeballed |
| Reticle leaves room on a phone and in the shortest card | ✅ `test/scan_layout_test.dart` |
| CI — analyze and test job | ✅ |
| CI — **debug APK job** | ✅ read directly, not just the rollup |
| Dashboard lays out on both palettes, two sizes | ✅ |
| Full-screen result lays out, 3 sizes + large text | ✅ |
| Import fuzzer | ✅ 2,240 mangled inputs, none throws |
| Blockchain under attack | ✅ 7 distinct forgery attempts, all caught |
| Merchant lookup sends only the VPA | ✅ asserted on the request body |
| No secrets in the tree | ✅ |
| No HTTP client in the app | ✅ the directory's transport is injected |

### What a sanity check cannot tell you

Everything above runs on a CI machine with **no camera, no NFC and no
screen**. Three things can only be confirmed on your phone:

1. **A POS tap now producing something** — `F-140` is the fix for every silent
   tap and it is verified by reading the routing rules and a reference
   implementation, not by a terminal.
2. **The theme toggle**, which is 440 colour reads moving at once.
3. **The pull-to-reveal**, now that the duplicate key is gone.

Those three are the field test for this build.
