# SWIP — Changelog

> Answers ideation `H-05`: *"a changelog is mentioned wherever the screen changes happen
> eventually, as per every prompt."*
>
> **Keyed by prompt.** Each entry records what changed in that round, which screens moved,
> and which ideation IDs it served. Screen IDs (`S-nn`) match
> [07-SCREEN-SPEC](07-SCREEN-SPEC.md) and the Figma frames. Ideation IDs match
> [02-IDEATION-LEDGER](02-IDEATION-LEDGER.md).
>
> **Never rewrite a past entry.** Add a new one.

---

## Prompt 1 — 08 Aug 2026 · Foundation

The initial brief: name and brand SWIP, research how an MCC can be captured, design the
app, build it for Android and iOS, and write it all down without losing any idea.

### Brand — new

| Asset | Note |
|---|---|
| `swip-wordmark.svg` | **New.** All caps, 12° slant, gold foil (`A-01`–`A-04`) |
| `swip-wordmark-flat / -ink / -white` | **New.** Ink is the only correct mark on the light UI |
| `swip-appicon.svg` | **New.** Gold foil on Ink, full bleed (`A-05`) |
| `swip-appicon-monochrome.svg` | **New.** Android 13+ themed / iOS tinted |
| `swip-monogram.svg` | **New.** Alternate for ≤ 48 px |
| `brand/generate.mjs` | **New.** All variants from one glyph definition |

**Two corrections made during drawing, both found by rendering rather than reasoning:**

1. Gradients defaulted to `objectBoundingBox`, giving each of the 13 shapes its own
   private sweep — the mark rendered as unrelated shards of gold. Fixed to
   `userSpaceOnUse` so one sweep crosses the whole word.
2. The modular **S read as a 5.** A 5 is literally a square top-left corner over a stem.
   Chamfering the two *outer* corners (top-left, bottom-right) restored the S's diagonal
   axis. First attempt chamfered the wrong corners and made it worse.

### Screens — all new

Every screen below is **specified**; those marked ▲ are also **built in Flutter**.

| ID | Screen | State | Serves |
|---|---|---|---|
| `S-00` | Splash | new | `A-08` |
| `S-01` ▲ | **Dashboard** | new | `A-09` `C-01` `D-03` `D-10` |
| `S-02` | Scan QR | new | `C-03` `C-14` |
| `S-03` | Tap POS | new | `C-04` `C-05` `C-13` |
| `S-04` ▲ | **Ledger** | new | `D-01`–`D-10` |
| `S-05` | Capture detail | new | `D-08` `D-09` |
| `S-06` | MCC detail | new | `D-05` `D-08` |
| `S-07` | Merchant detail | new | `D-08` |
| `S-08` | Check a link | new | `C-07` `C-08` |
| `S-09` | MCC directory | new | `C-02` |
| `S-10` `S-11` | Cards, Card detail | new | `E-02` |
| `S-12` | Settings | new | `D-07` |
| `S-13` | Confirm a capture | new | Vector 6 |
| `S-14` `S-15` | Onboarding, permission primers | new | `B-05` |
| `S-16` | Search | new | — |
| `S-17` | Insights (Pro) | new, v1.5 | — |
| `S-18` | SWIP Probe | new, v2 | `C-09` `C-10` `C-12` `C-13` |
| `S-19` | Travel Credit | new, v2 | `E-03`–`E-06` |
| `S-20` | Capture chooser | new | `C-06` |
| `S-21` | SWIP Coins | new, v2 | `F-02` `F-08` |
| `S-22` | Tap unavailable (iOS) | new | `B-02` |

### Element-level decisions worth recording

| Where | Decision | Why |
|---|---|---|
| `S-04` time cell | **Absolute stack default** (`08 Aug` over `4:12 PM`), tap toggles to `2h ago`, global and persisted | You gave three instructions and the third revised the second (`D-06` `D-07`). Changing your mind mid-sentence says both are right in different moments, so it is a toggle, not a decision |
| `S-04` col 1 | MCC fixed 56 dp, never truncates or wraps | `D-04` `D-10` |
| `S-04` col 2 | Publication chips are a **set** in fixed order | `D-05` — a code can be published in more than one place |
| `S-04` row | Merchant string is the only element allowed to ellipsise | `D-10` |
| `S-04` row | Reflows to stacked at ≥ 130 % text scale | Measured on a 360 dp device, not guessed |
| `S-01` | Exactly five recent rows | Six turns a dashboard into a list |
| `S-01` | Hero is the **last capture**, not a monthly stat | The question on opening is "what did that come out as?" |
| `S-01` iOS | Tap tile dimmed, not hidden → `S-22` | A missing feature reads as a bug; an explained one reads as honesty |
| Everywhere | Every MCC carries a confidence **dot + word** | Colour alone fails ~1 in 12 men, and this audience skews male |
| Global | Gold on black always; gold on white never as text | Gold is 2.3 : 1 on white — fails AA |

### Code — new

- **EMVCo MPM QR parser.** Byte-oriented TLV walking. *(A string-indexed walker mis-slices
  the moment a merchant name carries non-ASCII — tag 64 legitimately does — and every
  later tag, including tag 52, becomes garbage. Verified against Japanese, Thai and
  Devanagari.)* CRC-16/CCITT-FALSE enforced; a failing payload is refused, not surfaced.
- **UPI intent URI parser.** Hand-rolled rather than `Uri.parse`, because real merchant QRs
  routinely contain unencoded `&` and stray `%`, and losing `mc` to a malformed `pn` is
  undiagnosable for a user.
- **`SwipListenService.kt`** — the HCE service. PDOL requests `9F15` + 11 more tags;
  terminates every exchange with `SW=6985`; drops all-zero slices because an unprovisioned
  tag is not data.
- Design tokens, theme, `MccBadge`, `ConfidencePill`, `PublicationChips`, `LedgerRow`,
  `DashboardPage`, 212-code offline MCC table, 17 parser tests.

### Corrections to the brief

Three premises did not survive research. Each has a working alternative.

| # | Premise | Finding | Alternative |
|---|---|---|---|
| 1 | `E-05` — name the wallet so it carries a travel MCC | The acquirer assigns the MCC from actual activity and networks audit it. Wallet loads code `6540` and Indian issuers exclude it | Become a genuine travel merchant of record selling restricted-use travel credit — then `4722` is simply true |
| 2 | `F-06` — hold customer money in a debt fund | RBI bars interest on PPI escrow except the core portion, in an FD with the escrow bank | Under a travel-MoR structure the same rupees are *deferred revenue*, freely investable. Same idea, different balance sheet |
| 3 | `G-01` — convert into an alliance, then transfer internally | Alliances share **redemption reach**, not balances. No mechanism transfers miles between member programmes | Three anchors still right — one deal reaches ~57 airlines by redemption. Air India is in Star Alliance (since 2014), so it is your strongest anchor, not the exception (`G-04`) |

Also: **1 Coin : 2 miles is loss-making at the first rupee** (−₹45 per ₹1 L). Ship 1:1 and
run airline-funded transfer bonuses.

### Deliberately not built

| Thing | Why |
|---|---|
| SMS reading | Play policy blocks it for non-default handlers, and bank SMS carries no MCC anyway. `S-13` asks the user instead |
| Dark theme | `A-06` — light interior. Scaffolded, ships v1.2 |
| Accounts / login / server | `Q-2` — no-login is a large install-conversion advantage and removes DPDP exposure in v1 |
| `rupay` publication data | Not verifiable. A product that exists to stop people acting on wrong category data must not ship invented category data |

### Figma — file created

[SWIP — Design System & Screens](https://www.figma.com/design/YW2CBMQPT07R4XPNbNZg2u)
(`YW2CBMQPT07R4XPNbNZg2u`), in the **Personal** team. There is no *Claude Code* team on the
account and Figma teams cannot be created via API — moving the file later is drag-and-drop
and does not change the key. Full detail in [11-FIGMA](11-FIGMA.md).

| Built | |
|---|---|
| Variables | 37 colour + 16 space/radius, each with explicit `scopes` |
| Text styles | 11 — Inter, plus Roboto Mono for `Mono` |
| Components | `MccBadge` (12 variants) · `ConfidencePill` (4) · `PublicationChip` (3) · `LedgerRow` (+ boolean `Show chips`) |
| Foundations page | Colour ramps and the full type specimen |
| `S-01` | Frame, top bar, Ink hero, capture tiles, `RECENT` header |

**Two element-level changes made while drawing:**

| Where | Before | After | Why |
|---|---|---|---|
| `LedgerRow` | 390 wide, 20 px side padding | **350 wide, zero side padding** | The row owned the screen gutter, so an instance inside the dashboard's 16 px Recent card double-indented. The list supplies the gutter now |
| `LedgerRow` col 1 | ConfidencePill in column 1, under the MCC | **Pill moved to col 2 line 3**, beside the merchant | Built from the ASCII sketch, the pill overflowed the fixed 56 dp column and collided with the merchant. The normative S-04.1 table puts confidence on col 2 line 3 — and that is also what makes `D-10` work, since the merchant is then the `FILL` sibling that gives |

**Confidence colour on Ink — named tokens replace a computed lift.** The confidence palette
is defined for light surfaces, but the `S-01` hero is an InkCard where `verified` #0E7A4A is
2.2 : 1. `ConfidencePill` already handled this via `Color.lerp(color, white, 0.45)`, so it
was not a live AA bug — but the lerp desaturates, landing verified on a sage #7AB69B that no
longer reads as green. Four named `*-onInk` tokens now hold their hue and clear AAA, added
to the Figma collection, [06-DESIGN-SYSTEM](06-DESIGN-SYSTEM.md), `swip_tokens.dart`, and
`mcc_badge.dart`. **The Dart change is uncompiled — no Flutter toolchain in this
environment.** Run `flutter analyze`.

### Open

- **Figma build incomplete** — the Starter plan's MCP tool-call limit was reached part-way
  through `S-01`. No damage (`use_figma` is atomic). Remaining screens listed in
  [11-FIGMA §4](11-FIGMA.md#4-where-the-build-stopped).
- **`swip_tokens.dart` and `mcc_badge.dart` are uncompiled** — no Flutter toolchain here.
- Starter plan also caps a file at **3 pages**, so the intended 5-page structure is folded
  into 3.
- Inter's `tnum` must be enabled manually on the `MCC` text style — the Plugin API has no
  setter for OpenType features.
- `docs/00-INDEX`, this file, `docs/11-FIGMA` and the README were added after the first push.
- Four decisions still open — see
  [02-IDEATION-LEDGER § Open questions](02-IDEATION-LEDGER.md#open-questions-back-to-you).

---

## Prompts 2–15 — 08–09 Aug 2026 · Backfilled from the commit history

> **Honest note.** This file fell behind after Prompt 1: fourteen rounds of work were
> committed without an entry here. The section below reconstructs them from
> `git log` and the docs each round produced. It is a *record*, not a rewrite —
> nothing above has been touched. Each row links to what it produced, so nothing is
> left as words you cannot go and read.

| # | Ask | What it produced |
|---|---|---|
| 2–5 | *"Use Team Claude Code"* → *"create it and move ahead"* → auto-resume | Figma file built under a new team; [11-FIGMA §4](11-FIGMA.md#4-where-the-build-stopped) records where the build stopped. `01ec498` establishes the Starter plan's MCP tool-call cap is a **hard cap**, not a throttle — six hourly probes, one across UTC midnight, all failed. `e2971ad` corrects [02-IDEATION-LEDGER](02-IDEATION-LEDGER.md) where statuses said BUILT and the audit found ~25% |
| 6 | *"how do I view the app? I want to view it right away"* | [09-BUILD-AND-RUN](09-BUILD-AND-RUN.md) |
| 7 | Play Store walkthrough + *"why are you making the design so boring? …do something like CRED"* | [13-PLAY-STORE-LAUNCH](13-PLAY-STORE-LAUNCH.md) with every fee itemised, and [14-VISUAL-DIRECTION-FOIL](14-VISUAL-DIRECTION-FOIL.md) — the **Foil** direction, which reverses `A-06` |
| 8–9 | *"Yes"* / *"YES"* | `dabdabe` Foil dark theme everywhere, sqflite store, live scanner, ledger, contextual onboarding primers · `75a67c4` [15-TRADEMARK-SWIP](15-TRADEMARK-SWIP.md) · `9eadd80` the world QR corpus (and a PSP host-matching bug it exposed) · `db98ff3` [16-V2-PRD](16-V2-PRD.md) |
| 10 | *"HOW DO I FACILITATE THIS FOR YOU, STEP-BY-STEP NEEDED"* | `cf42883` [Flutter CI](../.github/workflows/flutter.yml) — **the code had never been compiled**; CI became the compiler |
| 11 | Screenshot of the first red CI run | `b737845` every error from run 1 · `55882c8` a stale `.gitignore` rule was silently dropping the Inter font · `4bfbb75` EMVCo TLV lengths are **bytes, not characters** |
| 12 | *"whats happening? where are we falling short to achieve success?"* | The honest structural answer — code had been written for weeks before the project could build. Then `1dcfdd2` round icon + package alignment · `5eeefca` the Kotlin HCE service and its missing Android resources · `cedd09e`/`83caa21` compileSdk 36 (my own append-vs-prepend error, fixed). **First installable APK.** |
| 13 | Reusable APK instructions for other projects · PVR pay-by-app · phone-to-phone card payment | [17-BUILD-ANY-APK](17-BUILD-ANY-APK.md) — the recipe any repo can follow · [18-INTENT-CAPTURE-AND-TAP-TO-PHONE](18-INTENT-CAPTURE-AND-TAP-TO-PHONE.md) · `62020c6` **Vector 7**, capture the merchant's pay-by-app intent |
| 14–15 | Feedback after installing the APK, with PVR and Swiggy screenshots | `4d8f3bc` [19-FEEDBACK-ROUND-1](19-FEEDBACK-ROUND-1.md) — `F-01`–`F-25` with a build order. Same commit **corrects my Vector 7 claim**: the screenshots showed merchant-rendered app lists, not Android's system chooser, so "SWIP will appear there" was downgraded from confident to 50/50, settled only by one install |

---

## Prompt 16 — 09 Aug 2026 · Tap and Link become real

> *"read docs/19-FEEDBACK-ROUND-1.md and build priorities 1 and 2"*

### Screens changed

| ID | Screen | Change | Serves |
|---|---|---|---|
| `S-03` | Tap a POS terminal | **New in Dart.** The Kotlin host has implemented NFC since the first commit and nothing ever called it | `F-08` |
| `S-08` | Check a payment link | **New in Dart.** Paste or clipboard → resolve → ledger | `F-09` |
| `S-02` / `S-09` / Vector 7 | Every capture result | Two near-identical sheets replaced by one `CaptureSheet` | `F-10`–`F-13`, `F-17`, `F-18`, `F-23` |

### Element changes

| Where | Before | After | Why |
|---|---|---|---|
| App shell | `onOpenCapture` received the vector and `_openScan()` ignored it — every tile opened the scanner | `_openCapture(vector)` switches to `TapPage` / `LinkPage` / `ScanPage` | **This was the whole bug.** Two of three vectors were unreachable from the UI although both halves existed |
| Capture sheet | Merchant name first, category below | **Code → what it means → merchant → the rest under a rule** | `F-10`–`F-12`: the number is the product |
| Capture sheet | Fixed field schema shared by both sheets | Per-vector `details` map keyed by **the source's own field names** (`9F15`, `9F1C`, `Payment provider`…) | `F-13`. A POS tap and a QR genuinely return different things, and this audience does not trust a number it cannot check |
| Capture sheet | Provenance in body text | Badge, **top right** | `F-17` |
| Capture sheet | No confirmation | Grey *"Saved to your ledger"* under the CTA | `F-18` |
| Capture sheet | Raw payload always shown | *"View technical details"* — available, never in the way | `F-23` |
| Unrecognised QR | *"Unrecognised"* | Named in plain words: wifi, contact, phone, SMS, map pin, app link, crypto, plain text — and **"a personal UPI code, not a shop"** | `F-19`–`F-22`. Technically true and useless is still useless |
| Failed-checksum QR | Parsed anyway, or silently dropped | *"This code is damaged"* | Better to show nothing than something invented |

### Code

| File | Change |
|---|---|
| [`app/lib/main.dart`](../app/lib/main.dart) | `_openCapture` routes by `CaptureVector` |
| [`app/lib/features/capture_nfc/tap_page.dart`](../app/lib/features/capture_nfc/tap_page.dart) | **New.** Capability probe → NFC-off prompt → preferred-service registration → capture stream → `stopListening` always on dispose, so SWIP never holds the NFC field in the background |
| [`app/lib/features/capture_link/link_page.dart`](../app/lib/features/capture_link/link_page.dart) | **New.** States plainly that this vector can only ever infer — an MCC is assigned by the acquiring bank and is never written into a URL, so a link never returns *Verified* |
| [`app/lib/widgets/capture_sheet.dart`](../app/lib/widgets/capture_sheet.dart) | **New.** The one sheet, replacing ~610 duplicated lines |
| [`app/lib/data/sources/payload_kind.dart`](../app/lib/data/sources/payload_kind.dart) | **New.** Kept out of `CaptureResolver` so copy can change without touching parsing that has 40 tests against it |

### Open

- **Vector 2 is unproven in the field.** The code path is now complete end to end, but whether real terminals populate EMV tag `9F15` needs the 50-terminal test in [03-RESEARCH-MCC-CAPTURE](03-RESEARCH-MCC-CAPTURE.md).
- Still queued from [19-FEEDBACK-ROUND-1](19-FEEDBACK-ROUND-1.md): camera-first dashboard carousel (`F-01`–`F-03`), geolocation and domestic/international (`F-14`–`F-16`, `F-40`), ledger filters (`F-06`, `F-07`), learning uncategorised merchants (`F-24`).
- Launcher icons are still the Flutter placeholders.

---

## Prompt 17 — 09 Aug 2026 · The counter test

> *"implement 3 & 4 & 5"* — plus two photographs from a shop counter that
> produced the most serious defect found so far.

Full write-up: [20-FEEDBACK-ROUND-2](20-FEEDBACK-ROUND-2.md).

### Screens changed

| ID | Screen | Change | Serves |
|---|---|---|---|
| `S-01` | Dashboard | **Live camera in the top band**, swipeable to the last capture, dot indicators, both cards one height | `F-01`–`F-03` |
| `S-04` | Ledger | Hide-uncategorised toggle; hidden runs collapse to a **dotted break** that names how many | `F-06`, `F-07` |
| `S-04.1` | Ledger row | **Merchant first, category second** — a reversal of `D-05` | `F-44` |
| `S-23` | Home country | **New.** First-run country + currency, changeable in Settings | `F-15` |
| `S-09` etc | Capture sheet | Domestic/International badge; registered-shop copy when the code has no category | `F-16`, `F-42` |

### Element changes

| Where | Before | After | Why |
|---|---|---|---|
| Every UPI capture | `pn` printed as the merchant | Placeholder names **rejected**; falls back to the payee handle | `pn=Paytm` put "Paytm" on five rows that were five different shops. The payment company is not the shop |
| Uncategorised merchant QR | "Unknown category" | *"A real shop — its category was not in the code"*, with the three ways to fill it | A `paytmqr…@ptys` handle proves a registered business. That answers *"will this earn?"*, which is the actual question |
| Sheet | PSP mixed into the merchant line | "Payment company" as its own labelled field | `F-13` |
| Ledger row line 3 | confidence · merchant · vector | confidence · Domestic/Intl · payment company · vector | `F-16` |
| Dashboard hero | Static, always the last capture | Card 2 of a carousel; card 1 is the camera | `F-03` |

### Code

| File | Change |
|---|---|
| [`merchant_identity.dart`](../app/lib/data/sources/merchant_identity.dart) | **New.** Who is behind a UPI handle: PSP, registered-business proof, placeholder-name rejection |
| [`live_viewfinder.dart`](../app/lib/widgets/live_viewfinder.dart) | **New.** Gold-bracketed camera card, sweep line, three honest states |
| [`home_market.dart`](../app/lib/core/settings/home_market.dart) | **New.** Home country/currency and the domestic-vs-international verdict |
| [`home_market_page.dart`](../app/lib/features/onboarding/home_market_page.dart) | **New.** `S-23` |
| [`merchant_identity_test.dart`](../app/test/merchant_identity_test.dart) | **New.** Both real handles from the photographs, pinned |
| `dashboard_page` · `ledger_page` · `ledger_row` · `capture_sheet` · `capture_resolver` · `capture_event` · `main` | Rewired for the above |

### Open

- **Vector 7 is closed, negative.** SWIP does not appear in Swiggy's UPI list. The share-target fallback is promoted from contingency to plan.
- **`F-40` geolocation deferred with a reason** — domestic/international already works from the payload's own country field, with no new permission. Location would add precision at the cost of Android's most sensitive permission.
- `F-43` — the "trusted apps" listing spotted on the phone. Waiting on a screenshot of where.
- The two photographed shops still have no category anywhere in their QRs. Only a terminal tap, a manual entry, or a second sticker can supply it.

---

## Prompt 18 — 09 Aug 2026 · The two things Vector 7 left open

> *"build the share-to-SWIP target and F-40 geolocation"*

### Screens changed

| ID | Screen | Change | Serves |
|---|---|---|---|
| `S-24` | Share-to-SWIP | **New.** Text or image arriving from any app's share sheet becomes a capture | `F-41` |
| `S-12` | Settings | Location toggle — off by default, asks for the permission as you flip it | `F-40` |
| `S-04.1` · capture sheet | Ledger row and sheet | Place shown discreetly where one exists | `F-40` |

### Element changes

| Where | Before | After | Why |
|---|---|---|---|
| Share sheet | SWIP listed, and did nothing when picked | Text and images both handled end to end | The `text/plain` filter had been in the manifest since the first commit with nothing behind it — the same registered-but-never-wired failure as Tap and Link |
| Shared screenshot with no QR | — | *"No payment code in that picture"*, pointing at the screen's own copy-link action | A share target that silently goes nowhere is worse than not having one. A Swiggy payment screen is exactly this case: it shows a list of apps, not a code |
| Domestic/International | Decided from the payload's country | **Device country wins** when both exist | What `F-14` actually asked for. A QR issued to a Singapore-registered merchant and scanned in Mumbai carries `SG` while you are standing in India |
| Ledger row line 3 | payment company | **place**, falling back to payment company | "The Bandra one" is how a person finds a past capture |

### Code

| File | Change |
|---|---|
| [`share_capture.dart`](../app/lib/features/capture_share/share_capture.dart) | **New.** `S-24`, both shapes, resolved through the same `CaptureResolver` as a scan |
| [`capture_location.dart`](../app/lib/core/location/capture_location.dart) | **New.** Opt-in coarse fix, reduced to a 6-character geohash before storage. Geohash hand-written — thirty lines, no platform surface, one fewer package in the supply chain |
| [`geohash_test.dart`](../app/test/geohash_test.dart) | **New.** Pinned against Niemeyer's reference vector, precision included |
| `MainActivity.kt` · `AndroidManifest.xml` · `strings.xml` | `ACTION_SEND` for text and images; `ACCESS_COARSE_LOCATION`; share-sheet label |
| `swip_database.dart` | Schema **v1 → v2**, additive and nullable, so a ledger already on a phone survives untouched |
| `capture_repository.dart` | Location fetched in `record()`, so "with every capture" is structurally true rather than remembered |
| `bootstrap.sh` | iOS usage strings generalised; location string added |

### A correction made during the work

The first version of `geohash_test.dart` asserted that two points 200 m apart
land in the **same** cell. That is false — geohash cells are a fixed grid and
two close points either side of a boundary differ in the last character.
Verifying the algorithm against the reference vector surfaced it before the
push. The test now asserts the property the privacy claim actually rests on:
they share the first five characters, so the cell cannot identify a building.

### Open

- `F-43` — the "trusted apps" listing spotted on the phone. Waiting on a screenshot of where.
- `F-24` — learning and grouping uncategorised merchants. Needs volume first.
- Launcher icon is still the Flutter placeholder.
- The 50-terminal `9F15` field test. Only the user can run it.

---

## Prompt 19 — 10 Aug 2026 · Cracking the Paytm QR

> The counter test, part two. Full prompt and all 24 to-dos:
> [21-PROMPT-LEDGER § Prompt 19](21-PROMPT-LEDGER.md#prompt-19--the-counter-test-part-two-current).
> Findings: [22-FEEDBACK-ROUND-3](22-FEEDBACK-ROUND-3.md).

### The finding

**The missing MCC and CRED's RuPay line are the same fact.** NPCI onboards merchants
in two tiers: **P2M** has an MCC and can take a RuPay credit card on UPI; **P2PM** has
neither. "Best Wishes" is P2PM — so there was never a category to read, and that is
also why CRED greyed out the RuPay cards. SWIP was not failing to parse.

### Screens changed

| ID | Screen | Change | Serves |
|---|---|---|---|
| `S-01` | Dashboard | Ambient scans produce a **condensed card**, not a modal | `F-60`, `F-61` |
| `S-03` | Tap POS | **Red/green default-payment-app card** | `F-54`–`F-56` |
| `S-12` | Settings | — | |
| capture sheet | Every vector | Detection-mode line; RuPay note; one-glance uncategorised copy | `F-53`, `F-47`, `F-64` |

### Element changes

| Where | Before | After | Why |
|---|---|---|---|
| Ambient scan | Full-height modal on every code in frame | Condensed card under the camera, chevron to expand | A modal is the most interrupting pattern there is, and the wrong answer to scanning nobody asked for |
| Sheet, no category | "SWIP could not find it" in four sentences | **"A person, not a shop"** + one line, or **"A real shop, no category published"** | At a counter, four sentences is the same as nothing |
| Sheet | No provenance line | *"Read from the shop's card terminal · EMV tag 9F15"* | `F-53` |
| Sheet | Nothing about card acceptance | RuPay note, green or amber, with the reason | `F-47` |
| Tap screen | No mention of the default-payment slot | Red until SWIP holds it, green after | Android sends taps to whichever app owns the slot. Without it the feature cannot work, and nothing said so |
| Location label | "Kasarvadavali, IN" at best | **"Kasarvadavali, Thane"** | `F-52`, the requested format |

### Code

| File | Change |
|---|---|
| `merchant_identity.dart` | `MerchantTier` — P2M/P2PM from the handle the PSP mints |
| [`scan_flash_card.dart`](../app/lib/widgets/scan_flash_card.dart) | **New.** The condensed card |
| `capture_location.dart` | Medium accuracy, last-known fallback, two-part de-duplicated label |
| `MainActivity.kt` | `isDefaultPayment` in `status`; `openPaymentSettings` |
| `tap_page.dart` | The red/green card, re-checked on return |
| `merchant_identity_test.dart` | +6 tests pinning the tier hypothesis against the three real counters |

### Open

- `F-49` merchant reconciliation and `F-50` the ₹1 statement loop — the two routes that would have given Snowberry's QR the category its own terminal already gave up.
- `F-62`, `F-63`, `F-66`–`F-68` — card stacking, the pull-string, camera morph and ripple.
- `F-43` — the trusted-apps screenshot was not among the images sent.
- `F-59` — held blank for the scenario that was forgotten. Not invented.

---

<!--
Template for the next entry:

## Prompt N — DD Mon YYYY · <one-line theme>

### Screens changed
| ID | Screen | Change | Serves |
|---|---|---|---|

### Element changes
| Where | Before | After | Why |
|---|---|---|---|

### Code
### Docs
### Open
-->
