# SWIP — Visual direction "Foil"

> **Status: proposed, awaiting your go-ahead.** Nothing in the app has been rebuilt yet.
> Walk the direction first: **https://claude.ai/code/artifact/e7764030-c2fd-49d5-9656-77bdfcfc7e0e**
>
> This **reverses `A-06`** (black-and-gold branding, light interior). You asked for the light
> interior, I argued for it, you've now seen it built and called it boring. That's the only
> test that counts, so this document assumes the reversal — but see §6 for what it costs.

---

## 1. Why the first draft was boring

Being honest about the failure is the only way not to repeat it.

The first direction was built from **constraints** — AA contrast, tabular figures, the
"never gold text on light" rule, Material 3 underneath. Every one of those decisions was
correct in isolation, and together they produced a competent settings screen. I optimised
for *nothing going wrong* and never asked what should go **right**.

The specific failure: **gold was demoted to a garnish.** On a light interior, gold fails AA
as text at 2.3 : 1, so the rule became "gold appears only as a fill, a 2–3 px indicator, or
an icon". The brand's one distinctive material was allowed to appear as a hairline. That is
why it read as generic — it was a white fintech app wearing a gold pin.

---

## 2. The idea

> **The four digits are treasure. The app is the moment you find out what they are.**

Every choice below serves that one sentence.

Invert the ground to near-black and **gold clears 8.4 : 1** — the rule that hobbled the
first draft simply stops applying. Gold is promoted from accent to **the material the
product is made of**. Nothing about accessibility gets sacrificed; the constraint just
moves out of the way.

---

## 3. Where it comes from

I did not browse Dribbble — I can't meaningfully, and inventing a shot list would be worse
than naming the real references. The direction is drawn from products in this exact
category that have solved this exact problem:

| Reference | What is worth stealing | What is not |
|---|---|---|
| **CRED** | Near-black ground, extreme type scale contrast, one hero number per screen, motion as reward. The reason you named it | Its opacity — CRED can be cryptic because it already has your trust. SWIP has to explain itself |
| **Apple Card** (Wallet) | The card *is* the interface; colour derived from spend category | Skeuomorphic gloss |
| **Monzo / Revolut** | Transaction lists that stay readable at length | Their palettes — both are bright, which is what we're moving away from |
| **Robinhood Gold** | Restrained use of a single metallic on dark | Its density |
| **Physical foil-stamped cards** | The actual specular behaviour: a *band* travelling across the surface, not a static gradient | — |

The last row matters most. A gold gradient that sits still looks like a cheap CSS preset.
**Foil is defined by the highlight moving when the surface tilts.** That's the whole trick,
and it's why the reveal animation and the pointer-tilt exist.

---

## 4. Tokens

```
── Ground ───────────────────────────────────────────
void      #060507   the base. Warm-shifted near-black, never #000
pitch     #0C0B0E   device / screen ground
raise     #141216   elevated surface, cards
raise2    #1C191F   input wells, code blocks
hair      #262229   1px separators

── Foil ─────────────────────────────────────────────
foil-lo   #8A6620   shadow stop
foil      #C9A227   body — THE brand gold, unchanged
foil-hi   #F5E3A3   specular stop. Only ever inside a gradient
paper     #F2EFE9   the ledger sheet. Warm white, not #FFF

── Text on void ─────────────────────────────────────
paper     #F2EFE9   primary
mute      #8E8896   secondary          (7.4:1 ✓)
mute2     #5D5866   tertiary           (≥18px only)

── Confidence on Ink (already in swip_tokens.dart) ──
verified  #34C77B   likely  #E0A22B
unknown   #A1A1A1   conflict #F2685E
```

The gradient is always **three stops minimum** (`lo → hi → lo`) at ~100°, with
`background-size` well over 100% so the highlight has somewhere to travel from. A two-stop
gradient is not foil, it's a fade.

---

## 5. Motion

Everything from `06-DESIGN-SYSTEM` survives. One token is now load-bearing rather than
decorative.

| Moment | Spec |
|---|---|
| **Onboarding panels** | Staggered rise: 18 px up, opacity 0→1, 620 ms `ease-out`, children offset 90 ms |
| **Screen change** | 420 ms. Opacity plus a 14 px lift and a 0.985→1 scale. No horizontal slides — they read as a website |
| **Reticle (listening)** | Two concentric rings, `scale(.72)→1.28` with opacity 0.85→0, 1.9 s, second offset by half a period. Reads as a heartbeat, not a spinner |
| **THE REVEAL** | Digits land individually: 26 px up + `scale(.86)`, 520 ms `cubic-bezier(.16,1,.3,1)`, staggered **50 ms** per digit. At +340 ms a specular band rakes across all four over 900 ms, linear, once. One light haptic on land; success-notification haptic if `verified` |
| **Card tilt** | Pointer/gyro → ±7° `rotateX/rotateY` on a 1400 px perspective, 500 ms settle. Fine pointers only |
| **Everything else** | 120–320 ms and unremarkable. That is what makes the reveal land |

> **The reveal fires in exactly three places: splash, a verified capture, a coin transfer.**
> Using it anywhere else destroys it. This was true in the first draft too — the difference
> is that now there's a ground dark enough for a specular highlight to actually read.

`prefers-reduced-motion` / `MediaQuery.disableAnimations` kills all of it: the reveal
becomes a cross-fade, the tilt is disabled, **the haptic stays**.

---

## 6. The one deliberate exception: the ledger stays paper

The ledger slides up as a **light sheet** (`#F2EFE9`) against the dark shell.

A ledger is a document, and you read documents in long sittings — that argument from the
first draft was right, and it survives. What was wrong was applying it to the *entire app*.
The contrast between vault and paper now does work: it tells you which mode you're in.

Every rule that made the row correct is unchanged: MCC fixed 56 dp and never truncated,
category clamped at 2 lines, publication chips a set, the merchant the only element that
gives, reflow at ≥130 % text scale, confidence as dot **and** word.

---

## 7. What this costs

Not free, and you should decide with the number in front of you.

- **Every one of the 22 screens needs its dark treatment.** The tokens make it mechanical,
  but it is 22 screens.
- **QA surface roughly doubles.** Two grounds, and the ledger sheet is a third context.
- **The Figma file needs a second variable mode** — and the Starter plan allows only one
  mode per collection, so this needs a Professional seat or a second collection as a
  workaround.
- **`swip_tokens.dart` gains a dark scheme.** It is already scaffolded for this (`A-06`
  noted a dark theme was planned for v1.2) — the work is real but not architectural.
- Rough estimate: **1.5–2 weeks** of design and front-end on top of current scope.

**My recommendation: do it, and do it now rather than in v1.2.** Retrofitting a ground
inversion after 22 screens exist in light is far more expensive than building them dark
once. The tokens and components already exist, so the cost is near its lifetime minimum
today.

---

## 8. What I need from you

1. **Confirm the `A-06` reversal.** Dark ground, light ledger sheet.
2. **Ledger sheet: keep or kill?** I think the vault/paper contrast is the best idea in this
   direction. If you want it dark too, say so and it's a one-line change.
3. Then I roll it through the components, the remaining Figma screens, and the Flutter theme.

Until you confirm, nothing in `app/` or the Figma file changes — this document and the
artifact are the whole deliverable.
