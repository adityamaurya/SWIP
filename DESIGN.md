---
version: alpha
name: SWIP Foil
description: >-
  A near-black instrument for reading a merchant category code at a counter,
  one-handed, before paying. Gold is the only colour that carries meaning.
colors:
  primary: "#C9A227"
  primary-light: "#E8C766"
  primary-lighter: "#F7E7B4"
  primary-dark: "#8A6620"
  primary-darker: "#4A3610"
  surface: "#060507"
  surface-raised: "#141216"
  surface-raised-2: "#1C191F"
  surface-sunken: "#0C0B0E"
  on-surface: "#F2EFE9"
  on-surface-variant: "#8E8896"
  on-surface-dim: "#5D5866"
  outline: "#262229"
  outline-strong: "#3A353F"
  success: "#34C77B"
  warning: "#E0A22B"
  danger: "#F2685E"
  info: "#6FA8F5"
typography:
  display:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: 700
    lineHeight: 1.05
    letterSpacing: -0.02em
  mcc:
    fontFamily: Inter
    fontSize: 34px
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: -0.01em
    fontFeature: "'tnum' 1"
  title-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: 600
    lineHeight: 1.2
  title-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: 600
    lineHeight: 1.25
  title-sm:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: 600
    lineHeight: 1.3
  body-lg:
    fontFamily: Inter
    fontSize: 17px
    fontWeight: 400
    lineHeight: 1.45
  body-md:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.45
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: 0.06em
rounded:
  chip: 8px
  input: 12px
  card: 16px
  sheet: 24px
  full: 9999px
spacing:
  xxs: 2px
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 20px
  xxl: 24px
  xxxl: 32px
  huge: 40px
  giant: 56px
  colossal: 72px
  gutter: 20px
components:
  tile-capture:
    backgroundColor: "{colors.surface-sunken}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.card}"
    height: 104px
  card-flash:
    backgroundColor: "{colors.surface-raised}"
    rounded: "{rounded.card}"
    height: 72px
  chip-vector:
    textColor: "{colors.on-surface-dim}"
    typography: "{typography.label-sm}"
    rounded: "{rounded.chip}"
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.surface}"
    rounded: "{rounded.full}"
    padding: 12px
  sheet-capture:
    backgroundColor: "{colors.surface-raised}"
    rounded: "{rounded.sheet}"
---

# SWIP — DESIGN.md

## Overview

SWIP is an instrument, not a destination. It is opened at a counter, one-handed,
with a queue behind, to answer one question — *what category is this shop filed
under?* — in the two seconds before a card comes out of a wallet.

Everything follows from that. The camera is already looking when the app opens.
The four digits are the largest object on any screen they appear on. Nothing
that is not the answer competes with the answer.

The surface is near-black, not "dark mode". There is no light theme and there
will not be one: the app is used under shop lighting, at arm's length, and a
dark instrument face with one bright reading is how every instrument built for
that condition looks.

**Gold is the only colour that means anything.** It marks the number, and things
that lead to the number. If a second accent ever appears on a screen, one of
them is wrong.

## Colors

The palette is one accent and a ladder of greys. That is the entire system.

- **Primary `#C9A227`** — THE brand gold. 8.4:1 on `surface`, so it is a *text*
  colour, not just a decorative one. Reserved for the MCC, the brand mark, and
  the single most important action on a screen.
- **Primary-light `#E8C766`** and **lighter `#F7E7B4`** — the foil sweep and the
  ripple only. Never for text.
- **Primary-dark `#8A6620`** / **darker `#4A3610`** — borders and fills where
  gold must be present but must not read as a text colour.
- **Surface `#060507`** — SWIP Ink. Not `#000`: a hair of warmth stops OLED
  smearing at card edges and keeps the gold from going acidic against it.
- **Raised `#141216`** / **raised-2 `#1C191F`** — depth by tone, not shadow.
- **On-surface `#F2EFE9`** — warm white. Pure white against warm gold reads
  blue-ish and cheap.
- **Semantic colours** exist for exactly four states — success, warning, danger,
  info — and are used at ~10 % alpha as fills with the full-strength hue as
  their text. They never appear as decoration.

Colour never carries meaning alone. The NFC status card is red or green **and**
says which; confidence was a dot **and** a word before it was removed entirely.
Roughly one man in twelve has a colour-vision deficiency and this audience
skews heavily male.

## Typography

Inter, variable, vendored. One family, weights 400 and 600, plus 700 for the
single display line at the foot of the home page.

- **`mcc`** — the four digits. Tabular figures, always. A category code that
  reflows its own width as digits change is the one typographic failure this
  product cannot afford.
- **`display`** — used once per app, for the sign-off at the end of the home
  scroll. If it appears twice, something is wrong.
- **`title-*`** — screen and card headings.
- **`body-*`** — everything a person reads as a sentence.
- **`label` / `label-sm`** — uppercase micro-copy: route tags, column heads,
  hints over the camera. Tracked out; never set in sentence case.

Copy rules that are as load-bearing as the type scale:

- **Hyphens, not em dashes.** An em dash in UI copy reads as machine-written.
- **A row states; a sheet explains.** "No category" on a row; the paragraph that
  says why lives one tap away.
- Sentence case everywhere except `label` styles.

## Layout

A single column, 20 px gutters, 8 px rhythm. No grid system — there is never
more than one column of content on a phone, and inventing one would be
scaffolding for a case that does not exist.

- **Safe areas are non-negotiable.** Every screen respects the cutout at the top
  and the gesture bar at the bottom. Content may scroll *under* the navigation
  bar; nothing may be pinned beneath it.
- **Never `CrossAxisAlignment.stretch` inside a sliver.** A sliver hands its
  child unbounded height; `stretch` turns that into a tight infinite constraint
  and takes the whole scroll view down with it. This has happened once and the
  entire dashboard rendered as nothing.
- **Above 1.3× text scale, three-column rows reflow to stacked**, and every cell
  in that layout is `Flexible`. Large-text users were the only ones ever seeing
  overflow stripes.

## Elevation & Depth

Depth is tone and a hairline. There are no drop shadows in the interface, with
one exception: the condensed scan card floats above the page as a notification,
and gets a shadow so it reads as *over* rather than *in*.

`surface` → `surface-raised` → `surface-raised-2`, each with a `outline`
hairline. Three levels is the whole ladder.

## Shapes

Corners get rounder as the surface gets larger, which is how a physical stack of
objects behaves: `chip 8` → `input 12` → `card 16` → `sheet 24`.

`full` is reserved for pills — the primary button and the progress track. A
fully rounded rectangle at card size reads as a toy.

## Components

- **Capture tile** — 104 px, icon over `title-sm` over `body-sm`, wrapped in
  `FittedBox(scaleDown)` so large text shrinks the content rather than
  overflowing the box.
- **Ledger row** — three columns: the MCC at 76 px fixed, the merchant and place
  flexible, the date and route tag at 76 px fixed. The MCC column is never
  truncated and never behind a tap.
- **Condensed scan card** — fixed 72 px, exactly two lines. It lives inside a
  fixed-height deck; a third line overflowed it by four pixels and painted
  hazard stripes across the one reassuring surface in the app.
- **Capture sheet** — the single destination for every vector. MCC, meaning,
  merchant, then everything else below a rule, labelled with the *source's own*
  field names.
- **Camera overlay text** — uppercase on a translucent plate. It sits over a
  live feed, so the background is whatever the counter happens to be.

## Do's and Don'ts

- **Do** make the MCC the largest thing on any screen it appears on.
- **Do** say a number is missing with the word `NA`, in grey. Never an em dash —
  punctuation pretending to be a value reads as a rendering fault.
- **Do** name a capture route in the words a person would say out loud:
  `QR SCAN`, `POS TAP`, `APP DIRECT`. Never a glyph, never an abbreviation of an
  abbreviation.
- **Do** delete a feature that does not work rather than leave it looking as
  though it does.
- **Don't** hedge. There is no "Likely". A category is read from the transaction
  or it is not known; a hedge transfers the app's uncertainty onto someone
  standing at a till.
- **Don't** use a second accent colour. If a screen needs one, the hierarchy is
  wrong.
- **Don't** put a modal in front of something the user did not ask for. Ambient
  scans get a condensed card; only a deliberate action earns a sheet.
- **Don't** add a permanent hint. A picture of a hand tapping is a tutorial
  drawn on top of the product; the gesture teaches itself through the response.
- **Don't** animate a collapse faster than ~400 ms. Below that the eye reads an
  event rather than a movement, and a card that snaps shut feels broken.
- **Don't** let colour be the only carrier of a state.

---

### On this file

Written to the [Google Labs DESIGN.md specification](https://github.com/google-labs-code/design.md):
YAML front matter for machine-readable tokens, `##` sections in the canonical
order for the reasoning behind them.

It is the visual half of what `docs/` already does for process. The changelog
and the prompt ledger record *what* was decided; this records *what the thing
looks like and why*, in a form an agent can parse before it writes a line.

The tokens here mirror
[`app/lib/core/theme/swip_tokens.dart`](app/lib/core/theme/swip_tokens.dart),
which remains the runtime source of truth. When they disagree, the Dart file
wins and this file is stale — say so rather than trusting it.
