# SWIP — Compliance & Risk Register

> The things that can stop this product, ordered by how likely they are to actually bite.
> You said *"forget all the security and legalities behind this."* I have not, because the
> two items marked 🔴 would end the company rather than delay it — and both have cheap
> mitigations if handled now and expensive ones if handled later.
>
> Everything else in the plan proceeds as you asked.

---

## 🔴 R-01 · Play Store rejection of the HCE service

**The single most likely thing to block launch.** SWIP registers real payment AIDs
(`A0000000031010` etc.) under `category="payment"`. Reviewers see "app emulates a Visa
card" and reject on a fraud/impersonation basis.

**Mitigations, all cheap, all now**

1. **Say it first, in the listing.** *"SWIP taps a card terminal to read its merchant
   category code. It holds no card number and cannot make a payment."*
2. **Make the binary prove it.** There is no PAN, no key material, no cryptogram
   generation, and no `GENERATE AC` handler anywhere in `SwipListenService.kt`. Every
   exchange terminates with `SW=6985`. Point a reviewer at the file.
3. **Ship a 30-second screen recording** with the appeal, showing the terminal declining.
4. **Fallback:** if rejected twice, move to a non-payment AID category and accept a lower
   hit rate, or ship Vector 2 as a sideloaded power-user build.

*Residual risk: medium.* Play policy on payment AIDs is enforced inconsistently.

---

## 🔴 R-02 · The v2 money structure

Holding customer money in India without the right authorisation is not a fine, it is an
enforcement action.

| Item | Status |
|---|---|
| Non-bank PPI: ₹5 cr net worth at application, ₹15 cr by year 3 | Out of reach at v1 |
| Escrow with a scheduled commercial bank, quarterly auditor certification | Mandatory under a PPI structure |
| **No interest on escrow** except the core portion, in an FD with the escrow bank | **Kills the debt-fund plan for customer money** — [04 §6.1](04-BUSINESS-MODEL.md#61--the-hard-rule-you-must-know) |
| **Draft RBI (PPI) Directions, 2026** (22 Apr 2026) — ₹2 lakh limits, tighter escrow, mandatory interoperability | **Live. Re-check before launch** |
| Travel merchant-of-record structure | The recommended route — [04 §5.2](04-BUSINESS-MODEL.md#52-the-version-that-works-stop-being-a-wallet) |

> **Action: a payments lawyer signs off the Travel Credit structure before a single rupee
> is loaded.** This is the one place in the entire plan where I would not proceed on my own
> judgement, and it is cheap now — a few lakh — against an enforcement action later.

---

## 🟠 R-03 · The Probe Card looks like card testing

Repeated small declines across many merchants from one BIN is the exact signature of
carding, and network fraud systems are built to spot it.

**Mitigations:** declare the use case in the issuer-processor programme application, never
discover it together later · hard rate limits (N/user/day, 1/merchant/30 days) · a global
per-acquirer circuit breaker · never $0-auth (an account-verification message cannot be
captured and is handled differently) · in-app disclosure before the first probe.

---

## 🟠 R-04 · Trademark

"Swipe"-adjacent marks are dense in fintech. Clear **classes 36** (financial services) and
**42** (software) before spending on launch creative. `SWIIP` registers defensively either
way.

---

## 🟠 R-05 · MCC arbitrage collapses

Issuers change exclusion lists quarterly and specifically in response to volume they
dislike. Every arbitrage in this space has died — GrabPay top-ups, wallet loads, rent
platforms.

**Mitigation, structural rather than tactical:** the company is never built on the
arbitrage. v1 needs no issuer's cooperation, and the merchant graph cannot be revoked by
anyone. See [04 §5.4](04-BUSINESS-MODEL.md#54--correction-3--mcc-arbitrage-is-not-a-moat-at-any-scale).

---

## 🟡 R-06 · Terminal vendors block the AID

Possible over time if the technique becomes popular. **Mitigation:** the graph is the
durable asset by design — captures made today keep answering after the capture path closes.

## 🟡 R-07 · DPDP Act 2023 (India)

Applies once there is a server. Consent, purpose limitation, breach notification, erasure.
**v1 avoids it structurally** — no account, no server, no personal data leaves the device.
The graph is merchant-keyed with 5-char geohashes, never user-keyed. That is a design
decision, and it should stay one.

## 🟡 R-08 · Apple review

An MCC app is unusual. It touches no NFC on iOS and holds no card data, so the honest
answer is short. Expect one question.

## 🟢 R-09 · Wrong MCC shown to a user

The reputational failure mode for this specific audience.
**Mitigations already in code:** CRC enforced, all-zero PDOL slices dropped, confidence on
every value, conflicts shown rather than resolved, raw payload always inspectable.

---

## Register

| ID | Risk | Likelihood | Impact | Owner | Due |
|---|---|---|---|---|---|
| R-01 | Play rejection | High | High | Aditya | Before submission |
| R-02 | v2 money structure | Medium | **Critical** | Lawyer | Before Phase 2 |
| R-03 | Card-testing flags | Medium | High | Aditya | Probe programme application |
| R-04 | Trademark | Medium | Medium | Aditya | **Week 1** |
| R-05 | Arbitrage collapse | High | Medium | — | Structural, mitigated |
| R-06 | AID blocked | Low | Medium | — | Structural, mitigated |
| R-07 | DPDP | Low in v1 | High | Aditya | Before any server |
| R-08 | Apple review | Medium | Low | Aditya | Submission |
| R-09 | Wrong MCC | Low | High | Aditya | Continuous |
