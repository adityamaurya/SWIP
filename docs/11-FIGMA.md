# SWIP — Figma

**File:** [SWIP — Design System & Screens](https://www.figma.com/design/YW2CBMQPT07R4XPNbNZg2u)
**Key:** `YW2CBMQPT07R4XPNbNZg2u` · **Team:** Personal · **Editor:** Design

> **On the team.** You asked for a team called *Claude Code*. No such team exists on the
> account, and Figma teams cannot be created through the API — only in the Figma UI. Rather
> than block, the file was created in **Personal** (a Full-seat team). Moving it later is a
> drag-and-drop in the Figma file browser and costs nothing; the file key and every link in
> these docs survive the move.

---

## 1. What is in the file

### Pages

The account is on the **Figma Starter plan, which caps a file at 3 pages**, so the intended
five-page structure is folded into three.

| Page | Holds |
|---|---|
| `01 Foundations & Components` | Colour, type, and the component library |
| `02 Screens — v1` | Every v1 screen |
| `03 Screens — v2` | Probe, Travel Credit, Coins |

### Variables — `SWIP Colour` (37) and `SWIP Space & Radius` (16)

Every colour in [06-DESIGN-SYSTEM](06-DESIGN-SYSTEM.md) exists as a variable with an
explicit `scopes` list, so the property pickers stay clean:

- `gold/*` — 7, with `gold/ink` scoped to **`TEXT_FILL` only**. That scope is the gold rule
  made mechanical: the picker will not offer `gold/500` where AA would fail.
- `ink/*` — 7 · `surface/*` — 6 · `semantic/*` — 9
- `confidence/*` — **8**, not 4. See §3.
- `space/*` — 11 (4 pt base) · `radius/*` — 5, named by role (`chip`, `control`, `card`,
  `sheet`, `pill`) rather than by value, so a radius change is one edit.

### Text styles (11)

`Display · MCC · Title/L · Title/M · Title/S · Body/L · Body/M · Body/S · Label · Label/S ·
Mono`. Inter throughout; `Mono` resolved to **Roboto Mono Medium** (checked against
`listAvailableFontsAsync` rather than assumed).

> ⚠️ **One thing Figma will not do for you.** Inter's default figures are proportional.
> The `MCC` style needs **`tnum`** enabled in *Type details* — the Plugin API has no setter
> for OpenType features, so this is a manual toggle. Without it the ledger's MCC column
> does not align on the digit, and that column is `D-04`.

### Components

| Component | Variants | Notes |
|---|---|---|
| `MccBadge` | **12** — Size `sm/md/lg` × Confidence ×4 | `sm` 20 / `md` 34 / `lg` 56 |
| `ConfidencePill` | 4 — Verified / Likely / Unknown / Conflict | Dot **and** word, always |
| `PublicationChip` | 3 — National / Intl / RuPay | A **set**, not a value (`D-05`) |
| `LedgerRow` | 1 + boolean `Show chips` | Built from instances of the three above |

Every component carries a `description` explaining the rule it enforces, so the reasoning
travels with the component into whatever file it is used in.

---

## 2. Two decisions taken while drawing

**`LedgerRow` does not own the screen gutter.** It was first built at 390 wide with 20 px
side padding. That is right for `S-04` and wrong everywhere else — the dashboard's Recent
card pads 16, so an instance would double-indent. The row is now **350 wide with zero
horizontal padding**, and the list that holds it supplies the gutter. Instances then drop
into either container and reflow correctly.

**The confidence pill sits in column 2, not column 1.** The ASCII sketch in
[07-SCREEN-SPEC §S-04](07-SCREEN-SPEC.md#s-04-ledger) shows `●Ver` in the column-1 gutter,
which is an artefact of drawing a 3-line row in monospace. The normative table one section
below puts *"confidence + merchant + vector glyph"* on **column 2 line 3**. Built from the
sketch, the pill overflowed the fixed 56 dp column and collided with the merchant string.
Built from the table, it is a sibling of the merchant in the same row — which is also what
makes `D-10` work: the merchant is `FILL`, so it is the element that gives, and it
ellipsises to `Blue Tokai · Po…` while the MCC, the chips and the time cell all stay whole.

---

## 3. Confidence colour on Ink

The confidence palette is defined once, for light surfaces. The dashboard hero is an
**InkCard**, and `confidence/verified` `#0E7A4A` on `#0A0A0A` is about **2.2 : 1**.

The Flutter widget already anticipated this — `ConfidencePill` takes an `onInk` flag and
lifted the colour with `Color.lerp(color, white, 0.45)`. So this was never a live
accessibility bug in the app. But a lerp toward white solves contrast by removing
saturation: verified lands on `#7AB69B`, a sage that clears AA at ~6.8 : 1 and stops reading
as *green* — which is the one thing the colour is there to carry.

Four **named** on-ink tokens replace the computed lift. They hold their hue and clear AAA:

| Token | Light | Lerp gave | Named token | Contrast on Ink |
|---|---|---|---|---|
| `confidence/verified` | `#0E7A4A` | `#7AB69B` | **`#34C77B`** | ~10 : 1 |
| `confidence/likely` | `#A66A00` | `#CBA97F` | **`#E0A22B`** | ~9.8 : 1 |
| `confidence/unknown` | `#5C5C5C` | `#A5A5A5` | **`#A1A1A1`** | ~8.2 : 1 |
| `confidence/conflict` | `#B3261E` | `#D37E79` | **`#F2685E`** | ~7.2 : 1 |

Now present in all three token homes: the Figma collection,
[06-DESIGN-SYSTEM](06-DESIGN-SYSTEM.md), and `swip_tokens.dart` —
with `mcc_badge.dart` selecting the named constant instead of lerping.

> ⚠️ The Dart change has **not been compiled** — there is no Flutter toolchain in this
> environment. It is a widened `switch` over `(confidence, onInk)`, exhaustive across all
> eight cases, but run `flutter analyze` before trusting it.

The rule generalises: *any* semantic colour used on `surface/inverse` needs an on-ink
counterpart. `semantic/success` and `semantic/danger` hit this the moment they appear on a
black card.

---

## 4. Where the build stopped

**The Figma Starter plan has an MCP tool-call limit, and this file hit it** part-way through
`S-01`. Nothing is broken — `use_figma` is atomic, so the failed call changed nothing.

**Complete:** all pages · all variables · all text styles · the whole Foundations page
(colour ramps, type specimen) · all four components · `S-01` frame, top bar, Ink hero,
capture tiles, and the `RECENT` header.

**Not yet drawn:**

| | Screen |
|---|---|
| `S-01` | The five Recent rows and the bottom nav — *the next call, already written* |
| `S-04` | Ledger — filter chips, sticky month head, rows with chips on |
| `S-03` | Tap POS, incl. the `S-03b` partial-result sheet |
| `S-02` `S-08` | Scan QR · Check a link |
| `S-13` `S-22` | Confirm a capture · Tap unavailable (iOS) |
| `S-05`–`S-07` | Capture / MCC / Merchant detail |
| v2 | `S-18` `S-19` `S-21` |

To resume, either wait for the limit to reset or upgrade the plan at the link Figma
returns. The remaining work is scripted the same way as everything above.

---

## 5. Rules for this file

1. **Tokens are generated, not hand-picked.** If a colour is not a variable, it does not go
   in a screen. A raw hex in a fill is a bug.
2. **The file and `swip_tokens.dart` must not drift.** They already have, in one place —
   §3. When they disagree, the doc is the arbiter and both get corrected.
3. **Screens are built from component instances**, never redrawn. If a screen needs a row
   that `LedgerRow` cannot express, the component gains a property; the screen does not
   gain a copy.
4. **Every component description states the rule it enforces**, not what it looks like.
5. `S-04` is the reference screen. When a component's behaviour is ambiguous, the question
   is always *"what does this do in the ledger at 130 % text scale?"*
