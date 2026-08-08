# SWIP — Roadmap

> Answers ideation `H-06` (*"create a flow for creating the application"*) and `E-01`
> (the know/pay split).
>
> Sequenced by **what unblocks what**, not by what is most exciting. The one
> non-negotiable ordering constraint is at the top of Phase 0.

---

## Phase 0 — Prove the unknown · **Week 1**

> **Do this before writing another screen.**

| # | Task | Output |
|---|---|---|
| 0.1 | Build the debug APK from this repo | Installable `swip-probe` |
| 0.2 | **The 50-terminal field test** ([protocol](03-RESEARCH-MCC-CAPTURE.md#34-what-is-verified-and-what-must-be-field-tested)) | The `9F15` hit rate |
| 0.3 | Decide Vector 2's product position from 0.2 | Go / soften / demote |
| 0.4 | Trademark search, classes 36 & 42 | Keep `SWIP` or rename |

**Why this is first.** Everything downstream — the marketing claim, the store listing, the
investor deck, even how prominent the Tap tile is on S-01 — depends on a number that exists
nowhere in any specification and can only be measured. Building three months of polish on
an unmeasured assumption is the most expensive mistake available here.

**Gate:** ≥ 40 % → Vector 2 is the headline. < 15 % → demote to a bonus, lead with the
merchant graph. In between → ship it honestly with a live in-app hit-rate indicator.

---

## Phase 1 — v1 "Know" · **Weeks 2–10**

No licence, no server, no account. This is the whole product for most users.

| Sprint | Ships | Screens |
|---|---|---|
| **1** · wk 2–3 | Design system in code; navigation shell; **QR capture end-to-end** | S-00, S-01, S-02, S-20 |
| **2** · wk 4–5 | Ledger, persistence, all three depth levels, the time toggle | S-04, S-05, S-06, S-07 |
| **3** · wk 6–7 | **NFC tap**, wired to the real service; iOS explainer | S-03, S-22, S-15 |
| **4** · wk 8 | Link inference; the confirm loop | S-08, S-13 |
| **5** · wk 9 | Cards + reward rules — the bridge to v2 | S-10, S-11 |
| **6** · wk 10 | Directory, search, settings, onboarding, a11y pass, store prep | S-09, S-12, S-14, S-16 |

**Definition of done for v1:** a stranger installs it, scans a QR within 60 seconds of
first launch, sees a correct MCC with an honest confidence label, and never sees a login.

---

## Phase 1.5 — Revenue without a licence · **Weeks 11–14**

The only money that needs nobody's permission. **Do not skip this to rush at v2.**

- **SWIP Pro** — multi-card optimiser, unlimited link checks, insights, export, dark theme
- Merchant graph sync (opt-in), so the "no QR available" case actually answers
- `S-17` Insights

Target: > 3 % conversion. This is what funds Phase 2 without diluting.

---

## Phase 2 — "Pay" · **Months 4–12**

Everything here is licence-gated and lawyer-gated. Detail in
[04-BUSINESS-MODEL](04-BUSINESS-MODEL.md) and [05-LOYALTY](05-LOYALTY-ALLIANCES.md).

| Track | Work | Blocking dependency |
|---|---|---|
| **A. Probe Card** | Offshore issuer-processor programme (Lithic / Stripe Issuing), auth webhook, decline, rate limits | Programme approval — **declare the use case up front** |
| **B. Travel merchant** | Become a genuine travel MoR; inventory via GDS/aggregator; SWIP Travel Credit | **Payments lawyer sign-off.** Non-negotiable |
| **C. Coins** | Earn, the vesting ladder, all nine guardrails | Track B |
| **D. Loyalty** | Sign **Air India Maharaja Club first**, then Qatar Avios, then Flying Blue | Volume evidence from C |
| **E. Cash floor** | "1 Coin ≥ ₹0.25 on any flight, any airline" | Track B |

**Sequencing rule:** B before C before D. Coins with nothing to spend them on is a
liability on your balance sheet and a broken promise on the user's phone.

---

## Phase 3 — Scale · **Year 2**

- India card programme via BaaS + sponsor bank ([03-RESEARCH §5.3 route B](03-RESEARCH-MCC-CAPTURE.md#53-what-actually-blocks-you-c-12-answered))
- **Merchant-graph licensing to issuers and acquirers** — the highest-margin revenue in the
  entire plan, and it is built for free by v1
- Account Aggregator enrichment
- iOS HCE if Apple opens outside the EEA

---

## The critical path

```
  Field test ──► v1 QR ──► v1 Ledger ──► v1 NFC ──► v1 ship ──► Pro revenue
                                                                    │
                                          lawyer sign-off ──────────┤
                                                                    ▼
                                     Travel MoR ──► Coins ──► Airline #1
                                          │
                                          └──► Probe Card (parallel, independent)
```

**The Probe Card is the only Phase-2 track that does not depend on the lawyer**, because
an offshore issuing programme is a different legal question from holding Indian customer
money. Start it in parallel the day Phase 2 opens.

---

## What would make me stop and rethink

Stated in advance, so they are decisions rather than rationalisations:

| Signal | Response |
|---|---|
| `9F15` hit rate < 15 % **and** graph coverage grows slowly | The product is a lookup directory, not a capture tool. Reposition or stop |
| Play Store rejects the HCE service twice with no path | Ship QR + link only; Vector 2 becomes a sideloaded power-user build |
| Pro conversion < 1 % at 50k installs | The audience will not pay. Reconsider v2 before spending on licences |
| Final RBI PPI Directions close the travel-MoR structure | v2 becomes affiliate-only. v1 is untouched — which is exactly why v1 was built to need no licence |
