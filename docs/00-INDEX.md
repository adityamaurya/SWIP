# SWIP — Documentation Index

**Start here.** Everything about SWIP lives in this folder. Twelve documents, each with
one job.

---

## Read in this order

| # | Document | What it answers | Read it if… |
|---|---|---|---|
| **1** | [01-PRD](01-PRD.md) | What SWIP is, who for, what ships | You have 10 minutes and want the whole thing |
| **2** | [02-IDEATION-LEDGER](02-IDEATION-LEDGER.md) | **Every idea you gave, ID'd, with where it was answered** | You want to check nothing was lost |
| **3** | [03-RESEARCH-MCC-CAPTURE](03-RESEARCH-MCC-CAPTURE.md) | How an MCC can actually be captured — six vectors, cited | You want to know whether this is real |
| **4** | [04-BUSINESS-MODEL](04-BUSINESS-MODEL.md) | Money: MDR, float, guardrails, the investor pitch | You are talking to an investor |
| **5** | [05-LOYALTY-ALLIANCES](05-LOYALTY-ALLIANCES.md) | Coins, airlines, alliances, 1:1 vs 1:2 | You are talking to an airline |
| **6** | [06-DESIGN-SYSTEM](06-DESIGN-SYSTEM.md) | Logo, colour, type, motion | You are designing a screen |
| **7** | [07-SCREEN-SPEC](07-SCREEN-SPEC.md) | Every screen, every state, every toggle | You are building or drawing a screen |
| **8** | [08-ARCHITECTURE](08-ARCHITECTURE.md) | How the code is organised and why | You are writing code |
| **9** | [09-BUILD-AND-RUN](09-BUILD-AND-RUN.md) | **Zero to running on your phone, ~40 min** | **You have never built a mobile app** |
| **10** | [10-ROADMAP](10-ROADMAP.md) | What to do, in what order | You are planning a week |
| **11** | [11-FIGMA](11-FIGMA.md) | The design file | You want the visual checkpoint |
| **12** | [12-COMPLIANCE-RISK](12-COMPLIANCE-RISK.md) | What can stop this, and what to do now | Before you submit to a store, or take money |
| — | [CHANGELOG](CHANGELOG.md) | What changed, per prompt | You want to see what moved |

---

## If you only read three things

1. **[03-RESEARCH §3](03-RESEARCH-MCC-CAPTURE.md#3-vector-2--the-pos-tap)** — why tapping a
   POS terminal to read its category code works, and the one number that decides how well.
2. **[04-BUSINESS-MODEL §4](04-BUSINESS-MODEL.md#4-the-join-between-v1-and-v2--the-strategic-core)** —
   why "know the MCC" and "pay through us" belong in one app.
3. **[02-IDEATION-LEDGER](02-IDEATION-LEDGER.md)** — the guarantee that none of your
   thinking was dropped.

---

## The one-paragraph version

SWIP shows you the merchant category code of a purchase **before you pay for it**. Four
digits decide whether a transaction earns 10× points, 1×, or nothing, and they are
invisible at the till. v1 reads them from any payment QR on earth (EMVCo tag 52, UPI `mc`),
from a POS terminal over NFC (EMV tag 9F15, demanded via the card's PDOL, then declined),
and infers them for payment links — with no account, no server, and no licence. Every
capture builds a merchant graph, which is what answers the hard case where there is no QR
and you simply hand over your card. v2 turns that audience into a travel business.

---

## Where the code is

```
app/          Flutter — Android + iOS.  See 09-BUILD-AND-RUN.
brand/        Logo generator + every variant.  node brand/generate.mjs
docs/         You are here.
```

**Two directories are generated. Never hand-edit them:** `brand/*.svg` (edit
`brand/generate.mjs`) and `app/assets/mcc/mcc_table.json` (edit
`app/tool/build_mcc_table.mjs`).

---

## The design file

[SWIP — Design System & Screens](https://www.figma.com/design/YW2CBMQPT07R4XPNbNZg2u) —
tokens, type and the component library are complete; screens are part-drawn.
[11-FIGMA](11-FIGMA.md) says exactly what is in it and what is not.

---

## Open decisions

Four, listed in
[02-IDEATION-LEDGER § Open questions](02-IDEATION-LEDGER.md#open-questions-back-to-you).
All four have a working assumption in place, so nothing is blocked — but overturning any of
them is cheap now and expensive later.

Three smaller things are also outstanding, all recorded in
[CHANGELOG § Open](CHANGELOG.md#open): the Figma screen set is unfinished (plan limit), the
Dart token changes are uncompiled (no Flutter toolchain in the build environment), and
Inter's `tnum` needs enabling by hand on the `MCC` text style.

---

## Added after the first round

| # | Document | What it answers |
|---|---|---|
| **13** | [13-PLAY-STORE-LAUNCH](13-PLAY-STORE-LAUNCH.md) | Getting on the Play Store: every step, real costs, real waiting times |
| **14** | [14-VISUAL-DIRECTION-FOIL](14-VISUAL-DIRECTION-FOIL.md) | The dark "Foil" redesign — proposed, awaiting sign-off |
| **15** | [15-TRADEMARK-SWIP](15-TRADEMARK-SWIP.md) | Trademarking the name and logo in India — every step, every link, real fees |
