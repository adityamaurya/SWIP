# SWIP — Design System

> Answers ideation IDs `A-01` … `A-09`, `D-10`.
> Every token here exists in three places and they must stay in sync:
> `app/lib/core/theme/swip_tokens.dart` · the Figma variable collection · this file.

---

## Naming `A-01`

**SWIP** ships. **SWIIP** is registered defensively (domain, handles, app-store keyword)
and redirects. Reasons: `SWIP` is shorter, it is the natural reading of the mark, and the
double-i creates permanent verbal ambiguity ("is that two i's?") in a product whose entire
job is being unambiguous.

> ⚠️ **Not done yet:** trademark clearance in classes 36 (financial services) and 42
> (software). "Swipe"-adjacent marks are dense in fintech. Do this before spending on
> launch creative — see [12-COMPLIANCE-RISK](12-COMPLIANCE-RISK.md).

---

## Logo `A-02` `A-03` `A-04` `A-05`

| Asset | File | Use |
|---|---|---|
| Primary wordmark, gold foil | `brand/swip-wordmark.svg` | On Ink, or on photography |
| Flat gold, no sheen | `brand/swip-wordmark-flat.svg` | **Below 24 px** — the foil aliases into mud at small sizes |
| Ink | `brand/swip-wordmark-ink.svg` | **The only correct mark on the light app background** |
| Knockout white | `brand/swip-wordmark-white.svg` | Photography, dark fills |
| App icon, 1024 master | `brand/swip-appicon.svg` | Store listing, launcher |
| Monochrome icon | `brand/swip-appicon-monochrome.svg` | Android 13+ themed icons, iOS tinted |
| Monogram (S) | `brand/swip-monogram.svg` | ≤ 48 px: notification, favicon, complication |

All variants are generated from one glyph definition by `node brand/generate.mjs`.
**Never hand-edit the SVGs** — edit the generator and re-run, or they drift.

### Construction

- Modular geometric caps on a 120 unit cap height, 28 unit stroke.
- **12° forward slant** (`A-03`), sheared about the optical centre at y=80 so the mark
  stays visually level rather than tipping.
- **Gold foil** (`A-04`): a 9-stop gradient — shadow → body → specular → body → shadow —
  plus a second sheen pass, both in `userSpaceOnUse` so **one** sweep crosses the whole
  word. (In `objectBoundingBox`, the SVG default, each of the 13 shapes gets its own
  private gradient and the mark shatters into unrelated shards of gold. This is the single
  most common way a foil logo goes wrong.)
- **The S carries the design.** A modular S built from flat rectangles reads as a **5** —
  a 5 is literally a square top-left corner over a stem. The two outer corners, top-left
  and bottom-right, are chamfered at 45°, which restores the S's diagonal axis and, as a
  bonus, echoes the swipe motion in the name.

### Rules

1. **Clear space** = the cap height (120 units) on all four sides. Nothing enters it.
2. **Minimum size**: 72 px wide for the foil variant, 44 px for flat.
3. **Never** re-slant, outline, add a drop shadow, stretch, or recolour outside these files.
4. **Never** place the foil variant on a light background — the shadow stops disappear and
   the highlight vanishes into the page. Use Ink.
5. The app icon is **full bleed**. Platforms apply their own corner mask; do not pre-round.

> **Known trade-off you should decide on:** you asked for the full `SWIP` wordmark in the
> app icon (`A-05`), and that is what ships. It is legible down to about 72 px. On a dense
> launcher at 48 px it silts up. `swip-monogram.svg` is the alternate. My recommendation is
> to ship the wordmark — brand recognition at install matters more than legibility at 48 px
> — but the asset is there if you disagree.

---

## Colour `A-06`

You asked for black-and-gold branding with a **light** interior, not a dark theme. That is
the right call for a finance app — a ledger is a document, and documents are light.

### The contrast problem, and the rule that solves it

**SWIP Gold on white is 2.3 : 1.** That fails WCAG AA (4.5 : 1) for text by a wide margin.
Gold on Ink is 8.4 : 1 and passes comfortably.

> ### The gold rule
> **Gold on black, always. Gold on white, never as text.**
> On light surfaces, gold appears only as a *fill* (with Ink text on it), as a 2–3 px
> indicator, or as an icon ≥ 24 px. For gold-coloured **text** on light, use
> `goldInk` (#7A5E12, 6.2 : 1).
>
> This one rule is what stops the brand from turning into an illegible luxury-hotel menu,
> and it is the most likely thing to get violated by someone adding a screen in six months.

### Tokens

```
── Brand ────────────────────────────────────────────
gold/50    #FBF6E6    tint wash, selected rows
gold/100   #F7E7B4    
gold/300   #E8C766    
gold/500   #C9A227    THE brand gold. Fills, indicators, icons ≥24px
gold/700   #8A6620    
gold/ink   #7A5E12    gold-flavoured TEXT on light  (6.2:1 ✓)
gold/900   #4A3610    

ink/900    #0A0A0A    SWIP Ink — primary text, black surfaces
ink/700    #2E2E2E    
ink/500    #5C5C5C    secondary text            (7.0:1 ✓)
ink/300    #8E8E8E    tertiary / placeholder    (3.5:1 — ≥18px only)
ink/200    #C9C9C9    
ink/100    #E4E4E7    hairlines, dividers
ink/50     #F4F4F5    subdued surface

── Surface (light) ──────────────────────────────────
surface           #FFFFFF
surfaceSubdued    #FAFAFA
surfaceSunken     #F4F4F5
surfaceInverse    #0A0A0A    black cards — the hero, the virtual card
border            #E4E4E7
borderStrong      #C9C9C9

── Semantic ─────────────────────────────────────────
success  #0E7A4A   onSuccess #FFFFFF   successBg #E9F6F0
warning  #A66A00   onWarning #FFFFFF   warningBg #FDF3E3
danger   #B3261E   onDanger  #FFFFFF   dangerBg  #FCEBEA
info     #1A5FB4   onInfo    #FFFFFF   infoBg    #EAF1FB

── Confidence (MCC-specific, load-bearing) ──────────
verified   #0E7A4A   captured live this session, or ≥5 agreeing captures
likely     #A66A00   inferred — heuristic or single report
unknown    #5C5C5C   no data. Say so. Never guess in grey and hope
conflict   #B3261E   sources disagree — show both
```

**Confidence colour is not decoration.** In a finance app, a number shown with unearned
certainty is a defect. Every MCC in SWIP carries its confidence colour and label wherever it
appears — dashboard, ledger, detail, notification. No exceptions.

### Dark theme

Scaffolded in `swip_tokens.dart`, **off by default** per `A-06`. It inverts to Ink surfaces
with the foil wordmark and lets gold return to full text duty. Ship it in v1.2, not v1 —
two themes double the QA surface and you have exactly one designer.

---

## Type

**Inter** — variable, superb tabular figures, free, already present in Figma (which matters,
because the Figma file is generated). The wordmark is outlines, so it carries no font
dependency.

| Token | Size / Line | Weight | Tracking | Use |
|---|---|---|---|---|
| `display` | 40 / 44 | 700 | −0.02em | Coin balance, capture hero |
| `mcc` | 34 / 38 | 700 | −0.01em | **The MCC number.** `tabular-nums`, always |
| `titleL` | 28 / 34 | 600 | −0.01em | Screen titles |
| `titleM` | 22 / 28 | 600 | 0 | Sheet titles, card headers |
| `titleS` | 18 / 24 | 600 | 0 | Row headers |
| `bodyL` | 17 / 24 | 400 | 0 | Primary reading |
| `bodyM` | 15 / 22 | 400 | 0 | Default body |
| `bodyS` | 13 / 18 | 400 | 0 | Supporting |
| `label` | 13 / 16 | 600 | +0.02em | Buttons, chips, column heads |
| `labelS` | 11 / 14 | 600 | +0.04em | Publication chips (NATIONAL / INTL / RUPAY) |
| `mono` | 15 / 20 | 500 | 0 | VPAs, terminal IDs, raw TLV |

**Numerals are `tabular-nums` everywhere without exception.** MCCs stacked in a ledger must
align on the digit or the column reads as noise, and that column is `D-04` — the single most
important thing on the screen.

---

## Space, radius, elevation

**Space** — 4 pt base: `2 4 8 12 16 20 24 32 40 56 72`. Screen gutter **20**. Card padding
**16**. Section gap **24**.

**Radius** — chip `8` · input/button `12` · card `16` · sheet `24` (top only) · pill `999`.
The virtual card uses `16` to echo a real card's corner.

**Elevation** — light theme uses **borders first, shadows barely**. Material's default
elevation ramp looks cheap on white.
```
e0  none                                    flat on surface
e1  0 1 0 border/#E4E4E7                    cards, rows       ← the default
e2  0 1 2 rgba(10,10,10,.06) + border       raised card
e3  0 8 24 rgba(10,10,10,.10)               sheets, menus
e4  0 16 48 rgba(10,10,10,.16)              modals
```

---

## Why Material 3 `A-07`

You asked to build on an established design system rather than invent one.

**Substrate: Material 3.** Not because SWIP should look like Google — it must not — but
because M3 gives you, free and correct: touch targets, focus/pressed/disabled states, text
scaling, RTL, TalkBack/VoiceOver semantics, dynamic type, and platform-native scroll
physics. Those are the things that take a year to get right and that nobody notices until
they are wrong. In a finance app they are non-negotiable.

**Then override the surface.** SWIP replaces M3's colour roles, type scale, shape scale and
elevation ramp entirely. What survives is behaviour, not appearance. On iOS, Cupertino
scroll physics and back-swipe are used so the app feels native there too.

> **This is the standard way serious product teams work**, and it is what "smooth and sexy"
> (`A-08`) actually reduces to in practice: 95 % correct, boring, accessible mechanics, and
> 5 % of highly considered brand surface applied on top. Apps that feel cheap almost always
> got that ratio backwards.

---

## Motion `A-08`

| Token | Duration | Curve | Use |
|---|---|---|---|
| `micro` | 120 ms | `cubic-bezier(0.2, 0, 0, 1)` | Press, toggle, chip |
| `standard` | 200 ms | `cubic-bezier(0.2, 0, 0, 1)` | Row expand, tab |
| `emphasized` | 320 ms | `cubic-bezier(0.05, 0.7, 0.1, 1)` | Sheets, push |
| `capture` | 480 ms | `cubic-bezier(0.16, 1, 0.3, 1)` | **The capture reveal** |
| `foilSweep` | 900 ms | `linear`, once | Splash, verified capture |

### The one signature moment

Every product needs exactly one motion that people remember. SWIP's is the **foil sweep**:

> The instant an MCC is captured, the digits land with a 480 ms spring, and a gold specular
> band rakes across them once — the same band that lives in the logo. Paired with a single
> light haptic. Success-notification haptic if the confidence is `verified`.

It appears in exactly three places: splash, a verified capture, and a coin transfer. Using
it anywhere else destroys it.

**Discipline:** everything else is 120–320 ms and unremarkable. Honour
`prefers-reduced-motion` / `MediaQuery.disableAnimations` — the sweep becomes a cross-fade,
the haptic stays.

---

## Core components

| Component | Notes |
|---|---|
| `MccBadge` | The MCC number + confidence dot. **The most-used component in the app.** Sizes: sm 20 / md 34 / lg 56 |
| `PublicationChips` | `NATIONAL` `INTL` `RUPAY` — `labelS`, 8 radius, outlined. Directly serves `D-05` |
| `ConfidencePill` | Dot + word + optional count: `● Verified · 47 captures` |
| `LedgerRow` | See [07-SCREEN-SPEC §S-04](07-SCREEN-SPEC.md#s-04-ledger). Never truncates column 1 or 2 (`D-10`) |
| `CaptureTile` | The three big entry points on the dashboard |
| `InkCard` | Black surface card, gold accents — hero, virtual card, coin balance |
| `SwipSheet` | Bottom sheet, 24 top radius, drag handle, `emphasized` |
| `EmptyState` | Illustration + one sentence + one action. Never a bare "No data" |
| `AmountText` | Currency-aware, tabular, never truncated |

---

## Accessibility floor

Non-negotiable, and cheaper to build in than to retrofit:

- Contrast **AA (4.5 : 1)** for all text; **AAA (7 : 1)** for the MCC number and any amount.
- Touch targets **≥ 48 × 48 dp**.
- Text scaling to **200 %** without clipping — the ledger row reflows to stacked at ≥ 130 %.
- **Never encode meaning in colour alone.** Confidence is dot **+ word**. Publication is
  chip **+ label**. Roughly 1 in 12 men has a colour vision deficiency, and the
  points-and-miles demographic skews heavily male.
- Every icon-only control has a semantic label.
- Full TalkBack / VoiceOver pass before any store submission.
