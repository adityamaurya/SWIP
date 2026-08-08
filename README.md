# SWIP

**Know the code before you pay.**

Four digits — the merchant category code — decide whether a purchase earns 10× points, 1×,
or nothing at all. They are assigned by the acquiring bank, they are not printed anywhere,
and you find out what they were when the statement arrives a month later. SWIP shows you the
MCC **before** you pay.

---

## What it does

| Vector | How | Status |
|---|---|---|
| **Any payment QR on earth** | EMVCo MPM tag `52`, UPI `mc` parameter | Parser built, 17 tests |
| **POS terminal over NFC** | Card-emulation: demand EMV tag `9F15` via the PDOL, read it, then decline | HCE service built (Android) |
| **Payment links** | Gateway/host heuristics — `rzp.io`, `pages.razorpay`, and friends | Specified |
| **The merchant graph** | Every capture makes the next one answerable without a QR | Specified |

No account. No login. No server. The parsing and the local graph are offline-first, so it
works on a plane, and there is no personal data leaving the device to protect in the first
place.

**iOS note:** Apple permits card emulation only in the European Economic Area, so the tap
vector is Android-only. The app says so plainly rather than hiding the tile.

---

## Repository layout

```
app/     Flutter — Android + iOS
brand/   Logo generator and every variant   →  node brand/generate.mjs
docs/    All twelve documents               →  START AT docs/00-INDEX.md
```

**Two directories are generated. Never hand-edit them:**

| Generated | Edit this instead |
|---|---|
| `brand/*.svg` | `brand/generate.mjs` |
| `app/assets/mcc/mcc_table.json` | `app/tool/build_mcc_table.mjs` |

---

## Start here

**→ [`docs/00-INDEX.md`](docs/00-INDEX.md)** routes you to the right document in one table.

If you have ten minutes: [01-PRD](docs/01-PRD.md).
If you have never built a mobile app: [09-BUILD-AND-RUN](docs/09-BUILD-AND-RUN.md) takes you
from zero to the app running on your phone in about 40 minutes.
If you want to know whether any of this is technically real:
[03-RESEARCH-MCC-CAPTURE](docs/03-RESEARCH-MCC-CAPTURE.md), which is cited throughout.

**Design file:** [SWIP — Design System & Screens](https://www.figma.com/design/YW2CBMQPT07R4XPNbNZg2u)
· see [11-FIGMA](docs/11-FIGMA.md) for what is drawn and what is not.

---

## Run it

```bash
cd app
flutter pub get
flutter run
```

Full prerequisites, SDK setup, signing and device notes:
[09-BUILD-AND-RUN](docs/09-BUILD-AND-RUN.md).

---

## Status

v1 is partially built and fully specified. What exists in code today: the EMVCo and UPI
parsers with tests, the Android HCE service, the design tokens and theme, the `MccBadge` /
`ConfidencePill` / `PublicationChips` / `LedgerRow` components, the dashboard, and a
212-code offline MCC table.

Four product decisions are still open, each with a working assumption already in place so
nothing is blocked — listed in
[02-IDEATION-LEDGER](docs/02-IDEATION-LEDGER.md#open-questions-back-to-you).

Three premises from the original brief did not survive research, and each has a documented
alternative — see the *Corrections to the brief* table in
[CHANGELOG](docs/CHANGELOG.md). Read [12-COMPLIANCE-RISK](docs/12-COMPLIANCE-RISK.md) before
submitting to a store or taking money.
