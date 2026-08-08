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
