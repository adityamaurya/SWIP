# SWIP — Ideation Ledger (Source of Truth)

> **Purpose of this document.** You asked that *nothing* from your ideation be lost.
> This file is the canonical, ID'd capture of every idea, sub-idea, constraint, worry,
> and aside you gave. Every other document in `/docs` references these IDs.
> If an idea has no ID here, it did not come from you — it came from research, and it
> will be marked as such (`R-xx`).
>
> **How to read it.** Each row has: the ID, your idea in your own framing
> (paraphrased only for grammar, never for meaning), and where it is answered.
>
> **Rule for all future work:** never delete a row. If an idea is dropped, change its
> status to `DEFERRED` or `REJECTED` and write the reason. Add new rows at the bottom.

---

## Legend

| Status | Meaning |
|---|---|
| `BUILT` | Implemented in this repository right now |
| `SPEC'D` | Fully specified in docs + Figma, not yet coded |
| `PHASE-2` | Deliberately after v1 |
| `PHASE-3` | Deliberately after v2 |
| `BLOCKED` | Cannot be done as literally stated — see the linked doc for the workaround |
| `CORRECTED` | Your premise had a factual error; the corrected version is carried forward |

---

## A. Brand & Identity

| ID | Your idea | Status | Answered in |
|---|---|---|---|
| `A-01` | App is named **SWIP**. You also floated **SWIIP** as an alternate spelling. | BUILT | [06-DESIGN-SYSTEM](06-DESIGN-SYSTEM.md#naming) — SWIP chosen, SWIIP kept as defensive domain/handle registration |
| `A-02` | Logo is a **typographic wordmark**: the word `SWIP` in **all caps**. | BUILT | `brand/swip-wordmark.svg` |
| `A-03` | The wordmark must be **slanted** (italic / oblique). | BUILT | 8° forward shear, see [06-DESIGN-SYSTEM](06-DESIGN-SYSTEM.md#logo) |
| `A-04` | Type colour = **golden foil** (not flat gold — a foil, i.e. a gradient with highlight). | BUILT | 5-stop foil gradient, `brand/swip-wordmark.svg` |
| `A-05` | **Black** is the app icon background. | BUILT | `brand/swip-appicon.svg` |
| `A-06` | Interior of the app should be **light/white**, *not* a dark theme, for now. | BUILT | Light-first theme in `app/lib/core/theme/`; dark theme scaffolded but off by default |
| `A-07` | Build on an **established brand design system** rather than inventing from zero. | BUILT | Material 3 as the substrate, SWIP tokens layered on top — [06-DESIGN-SYSTEM](06-DESIGN-SYSTEM.md#why-material-3) |
| `A-08` | The app must feel **"smooth and sexy" to operate**. | SPEC'D | Motion spec in [06-DESIGN-SYSTEM](06-DESIGN-SYSTEM.md#motion) |
| `A-09` | The **dashboard must be minimal** and "straight up to the point where I enter and do the things". | BUILT | [07-SCREEN-SPEC](07-SCREEN-SPEC.md#s-01-dashboard) |

## B. Platform & Delivery

| ID | Your idea | Status | Answered in |
|---|---|---|---|
| `B-01` | Target **both Android and iOS**. | BUILT | Flutter, single codebase |
| `B-02` | Later in the same brief you narrowed to **"Android application only, so I can publish it"**. | BUILT | Android is the *primary* target and the only one with full feature parity; iOS ships with the NFC vector disabled. Reason: [03-RESEARCH](03-RESEARCH-MCC-CAPTURE.md#ios-nfc-reality) |
| `B-03` | Explicitly **not a web application**. | BUILT | No web target in `pubspec.yaml`. A thin admin console exists server-side only |
| `B-04` | **Industry-standard code structure**, clean, because this is a finance app. | BUILT | [08-ARCHITECTURE](08-ARCHITECTURE.md) |
| `B-05` | You are a **product designer, new to mobile development** — everything must be hand-held. | BUILT | [09-BUILD-AND-RUN](09-BUILD-AND-RUN.md) is written for a first-time mobile dev |

## C. Core Product — "Know the MCC"

| ID | Your idea | Status | Answered in |
|---|---|---|---|
| `C-01` | **The primary thing the user always sees is the MCC of his expense.** | BUILT | Dashboard hero + ledger column 1 |
| `C-02` | He can **scan the MCC of the expense anywhere in the world**. | BUILT | Vector 1 — global EMVCo QR parser |
| `C-03` | **Vector 1 — QR:** person scans a UPI QR and the MCC is shown on screen. | BUILT | [03-RESEARCH §2](03-RESEARCH-MCC-CAPTURE.md#vector-1-qr) |
| `C-04` | **Vector 2 — NFC:** app has NFC access; user tells the merchant "I want to initiate the payment", and instead of tapping his card he **taps his phone** on the POS; the app captures whatever the POS gives, including the MCC. | BUILT (Android) | [03-RESEARCH §3](03-RESEARCH-MCC-CAPTURE.md#vector-2-nfc) — this works, via the PDOL/`9F15` mechanism |
| `C-05` | You were **"not sure how Visa/Mastercard infrastructure works on a POS machine"** and asked me to figure it out. | ANSWERED | [03-RESEARCH §3](03-RESEARCH-MCC-CAPTURE.md#vector-2-nfc) — full EMV contactless flow explained from first principles |
| `C-06` | **The hard case:** no QR is available. The user must swipe, insert-and-pay, tap-and-pay, hand over the card, or pay a Razorpay / Stripe / Cashfree link. | BUILT + PHASE-2 | Vectors 2, 3, 4, 5 |
| `C-07` | **Vector 3 — payment links:** people give custom payment links, national or international. Capture the data into the app. | BUILT (heuristic) + PHASE-2 (definitive) | [03-RESEARCH §4](03-RESEARCH-MCC-CAPTURE.md#vector-3-links) |
| `C-08` | You were unsure how the link scenario would work, because merchants "put their info in and simply get the MCC". | ANSWERED | [03-RESEARCH §4](03-RESEARCH-MCC-CAPTURE.md#vector-3-links) — MCC is assigned by the *acquirer* at onboarding, not encoded in the URL. Consequences explained |
| `C-09` | **Vector 4 — own card-issuing machine:** SWIP issues a **virtual card**. The user "gets the card approved every time they use our app", so they get the **MCC all in one place**. | PHASE-2 | [03-RESEARCH §5](03-RESEARCH-MCC-CAPTURE.md#vector-4-probe-card) |
| `C-10` | The virtual card should be **insertable into Gyftr/"Jipe" and other places** and instantly show what MCC is offered. | PHASE-2 | Same |
| `C-11` | Today's painful workaround you described: **people tap their card with the card disabled, then call customer support to ask what the MCC was.** This is the pain SWIP kills. | — | Quoted as the core problem statement in [01-PRD §2](01-PRD.md#2-the-problem) |
| `C-12` | You are unsure whether the card should be issued **by Visa or Mastercard** — you asked me to find a workaround so a virtual card can still be created. | ANSWERED | [03-RESEARCH §5](03-RESEARCH-MCC-CAPTURE.md#vector-4-probe-card) — network is not the blocker; the *issuer licence* is. Three workarounds given |
| `C-13` | The user **inserts the card and the payment gets declined** — no payment happens. SWIP simply **captures the payment that was attempted**. **"It's not related to payments or money."** | PHASE-2 | This is the **Probe Card**. It is the single most novel thing in the product. [03-RESEARCH §5](03-RESEARCH-MCC-CAPTURE.md#vector-4-probe-card) |
| `C-14` | There are **many types of QR codes in the whole world** — China, Western Europe, "every damn country". Any merchant the user pays, he just scans it. | BUILT | [03-RESEARCH §2.4](03-RESEARCH-MCC-CAPTURE.md#24-world-coverage) — 30+ national schemes, coverage matrix included |

## D. The Ledger

| ID | Your idea | Status | Answered in |
|---|---|---|---|
| `D-01` | The ledger has to be **very simple**. | BUILT | [07-SCREEN-SPEC §S-04](07-SCREEN-SPEC.md#s-04-ledger) |
| `D-02` | **Whenever a swipe, scan, or link URL happens, it gets added to the ledger.** | BUILT | One `CaptureEvent` write path for all vectors |
| `D-03` | The ledger table is **on the dashboard itself** (not only on its own tab). | BUILT | Dashboard shows the last 5; "See all" opens the full ledger |
| `D-04` | **Column 1 = the MCC code.** | BUILT | |
| `D-05` | **Column 2 = the detailed category** — including whether it is published **nationally, internationally, or by RuPay**. | BUILT | Modelled as `MccPublication { national, international, rupay }` — a code can carry more than one |
| `D-06` | Then show **time and date in relative format** — "2 hours ago", "1 hour ago". | BUILT | |
| `D-07` | Correction you made mid-thought: **the time below should be replaced with date and time**; then you swapped it again — **keep the time just below the day, date and month**. | BUILT | Final resolved layout: line 1 = `08 Aug`, line 2 = `4:12 PM`. Relative time (`2h ago`) is the *tap-to-toggle* alternate state. Both of your instructions are honoured — see [07-SCREEN-SPEC §S-04.3](07-SCREEN-SPEC.md#s-043-the-time-cell) |
| `D-08` | **The ledger part has to be interlinked.** | BUILT | Every row links to: the merchant profile, the MCC profile, other captures at the same merchant, and the card used |
| `D-09` | **Minimal on the surface; deep dive once you go inside.** | BUILT | Row → Capture Detail → MCC Detail → Merchant Detail, three levels |
| `D-10` | **"Primary has to be visible."** | BUILT | Design rule: MCC + category are never truncated, never behind a tap |

## E. Phase 2 — Pay Through SWIP

| ID | Your idea | Status | Answered in |
|---|---|---|---|
| `E-01` | Two separable jobs: **(1) just knowing the MCC**, and **(2) actually getting payments done via our portal.** | — | This is exactly the v1 / v2 split in [10-ROADMAP](10-ROADMAP.md) |
| `E-02` | **People want rewards.** So let them pay via SWIP and earn rewards on their credit card. | PHASE-2 | [04-BUSINESS-MODEL](04-BUSINESS-MODEL.md) |
| `E-03` | They **tap "Add money to the wallet"**. | PHASE-2 | Screen `S-11` |
| `E-04` | **Problem: wallets are expensive** and are excluded by card issuers. | ANSWERED | Confirmed by research: wallet loads code as **MCC 6540**, which nearly every Indian issuer excludes from rewards — [03-RESEARCH §7](03-RESEARCH-MCC-CAPTURE.md#7-the-6540-problem) |
| `E-05` | **Find a way to term this wallet** so we can attach a **flights / travel-aggregator MCC** to it. | BLOCKED as literally stated → workaround given | [04-BUSINESS-MODEL §5](04-BUSINESS-MODEL.md#5-the-mcc-question-answered-honestly). You cannot self-declare an MCC — the acquirer assigns it and the network audits it. But there is a **legitimate structure that reaches the same outcome**: stop being a wallet and become a *travel merchant of record*. Full design given |
| `E-06` | They **tap the bank, get money in, and use it anywhere they want** for payment. | PHASE-2 | |
| `E-07` | There should be an **expense ledger** for this. | PHASE-2 | Same ledger, new event type `Spend` alongside `Capture` |
| `E-08` | **Bypass** the exclusion "with a wallet named something that doesn't count as one of the excluded MCCs". | CORRECTED | The *name* has no effect on the MCC. The *business activity* does. See `E-05` |

## F. Business Model & Float

| ID | Your idea | Status | Answered in |
|---|---|---|---|
| `F-01` | Users pay **2% or the bare-minimum MDR** on the platform. | PHASE-2 | [04-BUSINESS-MODEL §3](04-BUSINESS-MODEL.md#3-unit-economics) — real Indian MDR bands researched |
| `F-02` | **Give the MDR back** to users as **coins / rewards** so they know they'll get it. | PHASE-2 | SWIP Coins |
| `F-03` | **Guardrails against abuse** by people who are "very *lalchi*" — hungry for points and miles. Stop reload-farming. | SPEC'D | [04-BUSINESS-MODEL §7](04-BUSINESS-MODEL.md#7-anti-abuse-guardrails) — 9 concrete guardrails |
| `F-04` | We pay the MDR back to the **Visa/Mastercard folks**, and eventually **every card type — JCB, RuPay, Amex, everything — must be supported.** | PHASE-2 | Network support matrix in [04-BUSINESS-MODEL §8](04-BUSINESS-MODEL.md#8-network-coverage) |
| `F-05` | **Investor story:** an angel invests a headstart amount; that amount sits in a **debt fund**; the interest funds the rewards. | SPEC'D | [04-BUSINESS-MODEL §6](04-BUSINESS-MODEL.md#6-the-float-engine) — modelled, with the hard regulatory caveat |
| `F-06` | **Float loop:** users pay MDR → SWIP holds it for XYZ time in a debt/safe fund → earns interest → pays users back in rewards. | SPEC'D + CORRECTED | Same. Critical finding: **you cannot earn float on customer money held in a PPI escrow** under RBI rules. The float you *can* legally earn on is your **own settlement receivable and your own capital** — the model still works, but the money has a different name |
| `F-07` | **Research how long the amount should be held** — what holding period is ideal. | ANSWERED | [04-BUSINESS-MODEL §6.3](04-BUSINESS-MODEL.md#63-how-long-should-you-hold) — T+2 operational, 30–90 day liquid/ultra-short duration bucket, with the maths |
| `F-08` | Rewards convert to **air miles 1:1**, or make it more lucrative at **1:2** through partnerships. | SPEC'D | [05-LOYALTY](05-LOYALTY-ALLIANCES.md) — why 1:2 is structurally impossible to fund and what to do instead |
| `F-09` | Keep rewards **logged/accrued for XYZ amount of time** before they vest. | SPEC'D | Vesting ladder in [04-BUSINESS-MODEL §7.4](04-BUSINESS-MODEL.md#74-the-vesting-ladder) — doubles as an anti-abuse device *and* as the thing that creates the float |

## G. Loyalty & Airlines

| ID | Your idea | Status | Answered in |
|---|---|---|---|
| `G-01` | Users convert SWIP rewards into **one program from each of Star Alliance, Oneworld and SkyTeam**, then transfer internally within the alliance. | SPEC'D + CORRECTED | [05-LOYALTY §2](05-LOYALTY-ALLIANCES.md#2-the-alliance-misconception) — **alliances do not pool miles.** Alliance membership lets you *fly and redeem on* partner metal, it does not let you *transfer balances between* member programs. The three-anchor strategy still works, but for a different reason |
| `G-02` | **Partner with at least one program per alliance.** | SPEC'D | Anchor recommendations with rationale: [05-LOYALTY §4](05-LOYALTY-ALLIANCES.md#4-the-three-anchor-strategy) |
| `G-03` | Some airlines are **not in any alliance** and must be partnered with individually. | SPEC'D | [05-LOYALTY §5](05-LOYALTY-ALLIANCES.md#5-the-non-aligned-carriers) — IndiGo, Emirates, Etihad, Qatar(now Oneworld), Turkish(Star), etc., with a partnering sequence |
| `G-04` | You gave **Air India** as your example of a possibly non-aligned carrier, and said you weren't sure. | CORRECTED | **Air India has been a Star Alliance member since 11 July 2014.** Its program is Maharaja Club (formerly Flying Returns). It is therefore an *anchor candidate*, not a non-aligned exception. Vistara merged into Air India in Nov 2024, so Club Vistara is gone |
| `G-05` | **Eventually every airline in the world** must be reachable. | SPEC'D | 4-tier coverage ladder in [05-LOYALTY §6](05-LOYALTY-ALLIANCES.md#6-the-coverage-ladder) — direct partner → alliance reach → hotel-currency bridge → cash-equivalent floor |

## H. Process & Deliverables

| ID | Your idea | Status | Answered in |
|---|---|---|---|
| `H-01` | Produce a **PRD**, structured properly, **missing nothing** from the verbatim ideation. | DONE | [01-PRD](01-PRD.md) + this ledger |
| `H-02` | **Research thoroughly** — internet, research papers, everything. | DONE | [03-RESEARCH](03-RESEARCH-MCC-CAPTURE.md), 40+ cited sources |
| `H-03` | Create a **Figma file where every screen is replicated** for visual checkpoint. | DONE | [11-FIGMA.md](11-FIGMA.md) |
| `H-04` | Every **smallest change, toggle, screen change and element change** must be in Figma. | DONE | Every screen state, every toggle, both time-cell variants |
| `H-05` | A **changelog** wherever screen changes happen, **per prompt**. | DONE | [CHANGELOG.md](CHANGELOG.md) — keyed by prompt number |
| `H-06` | **Create a flow** for building the application. | DONE | [10-ROADMAP](10-ROADMAP.md) |

---

## Open questions back to you

These are the only places where I made a judgement call that you may want to overturn.
Everything else is decided and built.

| # | Question | What I assumed | Where it bites |
|---|---|---|---|
| `Q-1` | Legal entity + home market for v2 (the money part). I assumed **India first**, because your entire framing — RuPay, MDR, *lalchi*, Gyftr — is Indian. | India | The whole of [04-BUSINESS-MODEL](04-BUSINESS-MODEL.md) is written against RBI rules. If you meant Singapore/UAE first, the float chapter changes completely |
| `Q-2` | Should v1 ship with **accounts at all**, or be fully local-first / anonymous? | **Local-first, no login.** MCC lookup needs no account, and no-login is a massive install-conversion advantage | Sync, and the crowdsourced merchant DB, get harder |
| `Q-3` | `SWIP` vs `SWIIP` as the shipped name. | **SWIP** | Trademark class 36/42 search still needed |
| `Q-4` | Do you want the **relative time** (`2h ago`) or the **absolute stack** (`08 Aug / 4:12 PM`) as the *default* ledger state? | **Absolute stack default, relative on tap** — because you corrected toward absolute last | `S-04` |

---

*Last updated: Prompt 1. See [CHANGELOG.md](CHANGELOG.md).*
