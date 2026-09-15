# 36 — Deviations: every decision that moved away from the original idea

> *"if we added something on the way as in it as purole color of any decision
> done from original idea, make an checklist in another md file"*

This is that file. Every entry is a place where what SWIP **is** drifted from
what SWIP was **first described as** — a feature added, a promise narrowed, a
default reversed, or a position I argued you out of.

It exists because the drift is invisible otherwise. Each change was reasonable
on the day it was made and defended in its own commit, and thirty of them
stacked up are a different product than the one you asked for unless somebody
writes them down in one place.

**Nothing here is a complaint and nothing here is asking for permission.** It
is a record, so you can look at any line and say "no, put that back".

**Legend.** 🟣 a real change of direction · 🔵 an addition that was never in the
original · 🟡 a promise narrowed or qualified · ⚪ a default reversed

---

## 1. The big ones — read these four if you read nothing else

### 🟣 D-01 · The app now makes a network call

| | |
|---|---|
| **Originally** | *"There is no server, no account, no analytics."* The README says it, `docs/30` §0 says it, and the app's own privacy copy says it |
| **Now** | One optional call: a VPA lookup to Razorpay, to get the merchant name CRED shows |
| **Why** | Prompt 35: *"about cred bring a psp, just get it done don't give me excuses"*. There is no way to resolve a name that is not in the QR without asking somebody who knows |
| **Cost** | The absolute version of the claim is gone. It becomes *"nothing leaves your phone unless you switch this on, and then only a payment address"* |
| **Contained by** | Off by default · explained before it is enabled · the request body is asserted to contain exactly one key · cached so a shop is looked up once, ever, rather than on every visit |
| **To reverse** | Delete `merchant_directory.dart`, `directory_transport.dart`, `features/lookup/`, their tests, and the Settings row. Restore `docs/30` §1 step 3 to have no exception |
| **Status** | **Live as of `F-160`.** It was built but unconnected for a round; it is wired now, off by default, and needs the user's own Razorpay key |

This is the largest deviation in the project's life and it should be the one
you re-examine first. **`F-157`**

### 🟣 D-02 · Something in SWIP now costs money

| | |
|---|---|
| **Originally** | Free, whole, no tiers. The support section explicitly said *"A contribution buys nothing. No feature changes, nothing is unlocked, and no part of SWIP is behind it"* |
| **Now** | Viewing the raw payload in-app is a one-time ₹5,000 unlock |
| **Why** | Prompt 34: someone could replicate the app from the captured strings |
| **Cost** | That sentence was rewritten. It now says a donation unlocks nothing *including this*, and that the two are separate transactions |
| **Contained by** | The wall is around a **view**, not data. Category, merchant, RuPay verdict, the whole ledger and **both exports including the encrypted backup** stay free, because the backup is your data and holding it hostage would be indefensible |
| **Watch for** | If the donation flow ever offers this unlock as a perk, the donation stops being a donation and becomes a supply — [`27` §2](27-DONATIONS.md) |

**`F-146`**

### 🟣 D-03 · Paper was "the only look". It is not any more

| | |
|---|---|
| **Originally** | Foil — gold on near-black. Then `F-130` replaced it wholesale with Paper and `main.dart` pinned `themeMode: ThemeMode.light` with the comment *"Paper is the only look"* |
| **Now** | Both, with a three-way toggle defaulting to your phone's setting |
| **Why** | Prompt 35 asked for it, and both are right for different rooms |
| **Cost** | 51 `const` constructors across 20 files stopped being `const`, because the colour tokens are now getters rather than compile-time constants |
| **Also** | The argument in `docs/33` that one look is better than a half-built second one is now formally overruled — by having built the second one properly rather than half |

**`F-155`**

### 🟣 D-04 · The backup stopped being human-readable

| | |
|---|---|
| **Originally** | *"That file is plain, readable JSON — not an opaque blob — so it stays useful even if SWIP stops existing"* |
| **Now** | AES-256-GCM, openable only with twelve words |
| **Why** | A plain ledger of every shop you have paid, every amount and every location, sitting in a Downloads folder and synced to a cloud, is the most sensitive artefact this app produces |
| **Cost** | Lose the phrase and the backup is gone. Nobody can reset it — not you, not me |
| **Mitigated by** | The plain line export (`F-149`) took over the "readable forever" job, and carries no payloads, no handles, no geohashes |

**`F-147`**

---

## 2. Things added that were never in the original idea

| | Addition | Prompt | Note |
|---|---|---|---|
| 🔵 D-05 | **A blockchain** | 34, 35 | Merkle trees, proof of work, Ed25519, a validator. Genuinely new capability: prove one capture to a third party without revealing any other |
| 🔵 D-06 | A recovery phrase | 34 | BIP-39. Twelve words that own both the backup and the chain identity |
| 🔵 D-07 | A second export format | 34 | The app was meant to have one export. It has two, for two different readers |
| 🔵 D-08 | Google Play Billing | 34 | A dependency, a permission surface and a Console product in an app that had no commerce |
| 🔵 D-09 | The merchant graph | 19, 27 | Not in the first description. It is now what answers when no code carries a category |
| 🔵 D-10 | Statement import | 20 | The highest-value path in the app, and it arrived from one line on a Federal Bank statement |
| 🔵 D-11 | Location on captures | 18 | An app that reads a number now also records where you were. Opt-in, coarse, reduced to a ~1.2 km geohash on device |
| 🔵 D-12 | A floating overlay | 32 | `SYSTEM_ALERT_WINDOW` is the most invasive permission Android grants. **I declined this once** and reversed on evidence that Wispr Flow ships it — [`32` §1](32-FLOATING-BUBBLE.md) |
| 🔵 D-39 | **Start on boot** | 37 | `RECEIVE_BOOT_COMPLETED`. `F-158` refused this — "a category reader restarting itself at boot is a worse trade than one app launch" — and the owner reversed it by asking for omnipresence explicitly. Legal for `specialUse`; Android 15's blocked-from-boot list does not include it |
| 🔵 D-40 | **`POST_NOTIFICATIONS`** | 37 | A permission prompt on an app that had none. The foreground service's notice is suppressed without it, taking the "Turn off" action with it |
| 🔵 D-41 | **A five-screen wizard** | 37 | The bubble was a switch with a subtitle. Two rounds of "it is not working" later, it is an onboarding flow |
| 🔵 D-13 | The support section | 28 | The app asks for money. Placed behind a pull at the foot of the home page, which is the least prominent position available |

---

## 3. Promises narrowed

| | Promise | Then | Now |
|---|---|---|---|
| 🟡 D-14 | "Shows you the MCC before you pay" | Implied it usually can | **One QR in ten carries one.** The product's honest shape is four capture routes and a memory, not a reader |
| 🟡 D-15 | "Works at any shop" | — | P2PM merchants have no MCC and cannot take a credit card on UPI **at all**. At a tea stall there is nothing to read and no card will reward you |
| 🟡 D-16 | "Tap the terminal" | Presented as a route | Depends on SWIP holding the contactless slot, the Tap screen being open, and the terminal being provisioned. Three ways to get silence, now each with its own sentence (`F-143`) |
| 🟡 D-17 | "Not readable by malicious software" | Sounded absolute | True of the **exported file**. A compromised phone can read the SQLite ledger directly and no export format changes that |
| 🟡 D-18 | "Tamper-proof" | — | The seal is tamper-**evident**. The chain is tamper-proof only against someone without the key, which is the strongest claim anything offline can make |
| 🟡 D-19 | Merchant names "like CRED" | — | Closed for **names** via a paid lookup. **Not closed for MCC**, and no purchasable API closes it |

---

## 4. Defaults reversed

| | Setting | Was | Is | Why |
|---|---|---|---|---|
| ⚪ D-20 | Theme | Pinned light | Follows your phone | D-03 |
| ⚪ D-21 | Capture result | Modal bottom sheet | Full screen | The number is the product and a sheet caps it at 60 px over a camera feed |
| ⚪ D-22 | Scanner | Always detecting | Only while the phone is raised | It was ambushing you with pop-ups while sitting on a table (`F-134`) |
| ⚪ D-23 | Import file picker | `.json` only | Any file | A backup that has been through Drive and a chat app comes back with any extension, and a picker that will not show you your own file is its own import failure |
| ⚪ D-24 | HCE broadcast | Only on success | Every outcome | Silence was indistinguishable from a broken app |
| ⚪ D-25 | Hint animations | Repeat forever | Capped | A thing twitching while you read is a fault, not an invitation |

---

## 5. Positions I argued, and how they resolved

Recorded because in three of five you overruled me and were right to.

| | Position | Outcome |
|---|---|---|
| 🟣 D-26 | *"A floating overlay is too invasive"* | **You overruled me.** Evidence — Wispr Flow ships it — beat my caution. Building it |
| 🟣 D-27 | *"CoWIN was not blockchain-based, so a blockchain adds nothing here"* | **You overruled me.** The premise correction stands and was worth making; the conclusion did not follow, and the Merkle tree turned out to buy a real capability I had not thought of |
| 🟣 D-28 | *"CRED needs a PSP licence, SWIP cannot have that"* | **You overruled me, and I was plainly wrong.** A VPA lookup is a commercial API sold to any business with KYC. I should have looked before concluding |
| 🚫 D-29 | The cashback-arbitrage donation mechanism | **Declined and staying declined.** The cashback is paid by an issuer who believes it funded a retail purchase. [`27` §3](27-DONATIONS.md) records it and what replaces it |
| 🚫 D-30 | A plan to avoid GST | **Declined.** The accurate position was given instead: a genuine donation with no quid pro quo is not a supply at all under CBIC Circular 116/35/2019 |
| 🟣 D-42 | *"Wiring the lookup needs an HTTP client our own gate forbids — your call"* | **Wrong, and mine.** The gate was written to catch an accident. It now has one named exception and still fails everywhere else. `F-160` |
| 🟣 D-43 | *"Three Razorpay constants can't be verified from here"* | **Wrong.** razorpay.com is blocked; search was not. All three confirmed, all three already correct. `F-160` |
| 🟣 D-44 | *"`bootstrap.sh` regenerates `build.gradle`, so CameraX can't stick — your call"* | **Wrong, and mine.** That script is ours and had been re-injecting a `compileSdk` override for the same reason since the file_picker collision. `F-161` |
| 🚫 D-45 | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | **Declined, on policy rather than taste.** Play prohibits a direct Doze exemption "unless the core function of the app is adversely affected"; the acceptable list is messaging, enterprise VOIP, safety, task automation and peripheral companions. A floating button is none of those |
| ⏸ D-46 | An Accessibility Service, as Wispr Flow uses | **Offered, not taken.** It would buy precise foreground detection and cost the claim that SWIP *cannot* read another app's screen. Put to the owner in [`37` §3](37-OMNIPRESENCE-AND-THE-TWO-BLOCKERS.md) rather than decided alone |
| 🟣 D-47 | *"The bubble's snap animation is fine"* — never argued out loud, which is the point | **Wrong, and the owner named it precisely.** *"Too much sticky type experience"* is an exact description of a fixed `duration`: 260 ms whether the bubble was flicked across the screen or nudged a centimetre. [`32` §4](32-FLOATING-BUBBLE.md) had specified *"velocity-aware edge snapping"* from the beginning and the build never read a velocity at all. `F-170` |
| 🟣 D-48 | *"The close button needs to be bigger"* — my first reading of the owner's note | **Wrong diagnosis.** It was a contrast failure, not a size one: near-black at 80% on a 45% black scrim over a dark app composites to 1.03:1, and a bigger version would have been a bigger invisible button. `F-172`, and [`test/hover_chrome_test.dart`](../app/test/hover_chrome_test.dart) now asserts it |
| 🟣 D-50 | `F-144`: *"a sheet is the wrong container for a capture result"* | **Reversed for two vectors, and the original argument still stands for the other two.** The reasoning was that the number is the product and a sheet caps it at 60 px — which is why `CaptureLayout.brief` gives the digits the full-screen treatment on a sheet. What changed is what is *behind* it: a QR scan and a POS tap leave their capture surface running, so covering it meant the next capture needed a dismissal first. The share sheet and the pay-by-app handover keep the page. `F-175` |
| 🟣 D-51 | *"the close button needs to be bigger"* → *"the snooze needs a smoother animation"* — the same mistake twice, one round apart | **Both were diagnoses of a symptom.** The button was invisible, not small; the snooze glitched because a long-press timer fires under a finger that may still become a drag, not because its easing was wrong. In both cases the fix was to change what the thing *was*, and in both cases polishing it would have produced a better-looking version of the same bug. `F-172`, `F-173` |
| 🟣 D-49 | The first fix for D-48: make the chrome follow the Paper/Foil palette | **Wrong, and caught by my own test rather than by the owner.** Foil's raised surface is `#141216`, so Foil got the invisible pill back. `CLAUDE.md`'s camera-overlay rule already covered the case — overlay chrome carries its own contrast — and I had not applied it here. `F-172` |

The pattern in D-26, D-27 and D-28 is worth naming: **I was reasoning from
what I already believed instead of going and checking.** The correction in each
case came from you telling me to look. That is the useful thing on this page.

**D-47 is a third variant, and the quietest one.** It was not a position I
argued and not a decision I handed over — it was a spec on this project's own
page that the implementation had drifted from, and nobody re-read the page. The
two numbers `docs/32` §4 asked for (56 dp, velocity-aware) were both wrong in
the build for four months, and the owner found them by feel. **Before
declaring a feature finished, re-read what was written down for it.**

D-49 is the encouraging one: a wrong turn caught by a test written in the same
session, before the owner ever saw it. That is what the two new suites this
round are for.

**D-51 is the one to actually change behaviour over.** Twice in two rounds the
owner described a symptom — *"not prominent enough"*, *"not smooth"* — and
twice the literal reading pointed at a polish job that would have produced a
better-looking version of the same defect. Both times the real cause was
structural and the fix was to change what the thing was. **When the report is
about how something feels, find the mechanism before reaching for the easing
curve or the padding.**

**D-42, D-43 and D-44 are the same pattern again, in a worse form.** Those
three were not positions I argued for — they were things I labelled "your
decision" and handed over, which is how a wrong conclusion avoids being
argued with at all. All three were mine to solve and none needed a decision
from anybody. If a line in this project ever says *"that is the owner's
call"*, the question to ask first is whether it is a genuine trade-off or
just something I have not tried yet.

---

## 6. Load-bearing engineering choices

Not product decisions, but each constrains what can be built next.

| | Choice | Consequence |
|---|---|---|
| D-31 | Colour tokens are **static getters over a global**, not a `ThemeExtension` | A palette switch rebuilds the whole tree from a `key`. Fine for a preference; would not scale to per-screen theming |
| D-32 | The paywall entitlement is a `SharedPreferences` boolean | Flippable on a rooted phone. Accepted: the alternative is an account system, which costs more than the feature is worth |
| D-33 | Billing is verified client-side | Google recommends a server. There is none, by design |
| D-34 | PBKDF2 at 210,000 rounds, not OWASP's 600,000 | Measured: 600k is 6–12 s on a phone, twice per round trip. The secret is a 128-bit CSPRNG phrase, not a password |
| D-35 | Proof-of-work difficulty 3 | ~4,096 hashes a block. Higher would be theatre — the signature is what actually stops a rewrite |
| D-36 | One recovery phrase per install, not per backup | Twelve words per export would be unusable. Each file still gets its own salt |
| D-37 | The directory's HTTP transport is **injected** | Keeps `docs/30` §1's "no HTTP client" check meaningful and the suite offline |
| D-38 | `sqflite_common_ffi` as a dev dependency | The database is finally testable. The two worst near-misses in this project were both in that layer and both caught by reading, not running |

---

## 7. If you want any of it back

| Undo | How |
|---|---|
| The network call | Delete `merchant_directory.dart` + test. Nothing depends on it |
| The paywall | Delete `lib/features/paywall/` and `raw_data_lock.dart`; show the payload directly |
| The dark theme | Set `SwipPalette.active = SwipPalette.paper` and drop the Settings rows |
| The blockchain | Remove the `chain` block from `BlackBox.seal`; `F-127`'s seal still stands on its own |
| The encrypted backup | `BlackBox.inspect` still reads plain exports, so nothing has to be migrated |
| The full-screen result | `CaptureLayout.sheet` still exists and still works |

Every one of those is a small, contained change, and that is deliberate: a
deviation you cannot reverse is not a decision, it is a trap.
