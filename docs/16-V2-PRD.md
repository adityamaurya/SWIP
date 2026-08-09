# SWIP v2 — Product Requirements

> Covers every v2 idea from the ideation: the wallet (`E-03`–`E-08`), the Probe
> card (`C-09` `C-10` `C-12` `C-13`), the travel MCC (`E-05`), MDR and coins
> (`F-01` `F-02`), float and interest (`F-05` `F-06` `F-07`), coins to miles
> (`F-08`), and transfers (`G-01`–`G-05`).
>
> **You said don't worry about compliance — research it and build a workaround
> around the crux.** That is exactly what this document does. Nothing here is
> "you can't". Every section states the constraint, then the structure that
> delivers your idea inside it.
>
> ⚠️ **Not legal advice.** Every regulated step below needs a lawyer before
> money moves. It is accurate as of August 2026.

---

## 0. The finding that changes the earlier documents

**[RBI issued draft Prepaid Payment Instruments Directions on 22 April 2026](https://www.medianama.com/2026/04/223-rbi-prepaid-payment-instruments-rules-wallet-limits-escrow-norms/)**,
with public comments closed 22 May 2026. [04-BUSINESS-MODEL](04-BUSINESS-MODEL.md)
was written against the **2021** Master Directions and is now partly out of date.

What changed that matters to SWIP:

| Change | Effect on v2 |
|---|---|
| **₹2 lakh wallet limit**, monthly transfer caps | Caps how much travel credit one user can hold |
| **Interoperability mandated** | Good for you — reduces lock-in objections |
| **Capital requirements** for non-bank issuers | Raises the cost of the wallet route (§2) |
| **Escrow core-portion interest now computed monthly**, previously fortnightly | Slightly changes the float maths in §5 |

Sources: [Lexology analysis](https://www.lexology.com/library/detail.aspx?g=35cfed04-f062-4c1e-9e38-7294773aa014) ·
[K&K newsletter](https://ksandk.com/newsletter/rbi-draft-ppi-directions-2026/) ·
[The Policy Edge](https://www.policyedge.in/p/rbi-issues-draft-ppi-framework-with-2-lakh-wallet-limits-and-interoperability-mandate)

> **Consequence: do not build the wallet first.** The rules governing it are
> actively being rewritten. §7 sequences around this.

---

## 1. The confirmed problem — why a plain wallet fails

Your instinct in `E-04` was right, and it is now confirmed from multiple sides.

**Wallet loads are coded [MCC 6540](https://www.axis.bank.in/important-links/credit-card/important-announcement-on-credit-card) — "prepaid load" / quasi-cash.** Indian issuers exclude 6540 from:

- reward point earning
- **milestone accounting**
- annual-fee-reversal spend thresholds

Axis names it explicitly. Most other issuers do the same.

So a SWIP wallet, built the obvious way, produces the exact outcome your users
are trying to avoid: **they load money and earn nothing.** The product would be
self-defeating on day one.

`E-08` — "name the wallet something that isn't an excluded MCC" — **cannot
work**, and now we know precisely why: [MCCs are assigned by the acquiring bank
based on the merchant's primary business activity](https://www.rapyd.net/blog/your-guide-to-merchant-category-code-mcc-4722-travel-agencies-and-tour-operators/),
not chosen by the merchant. The name is not an input.

**But the business activity is.** That is the crux, and the whole of §2 follows from it.

---

## 2. The workaround: be a travel merchant, not a wallet

### The mechanism

The acquirer assigns the MCC from **what you actually sell**.
[MCC 4722 covers travel agencies, tour operators and online travel agencies —
explicitly including Expedia and Booking.com](https://www.pxp.io/mcc-codes/4722-travel-agencies-and-tour-operators).

So: **stop selling stored value. Start selling travel.**

| | Wallet (rejected) | Travel MoR (recommended) |
|---|---|---|
| What the user buys | Stored value | **Travel credit redeemable for flights and hotels** |
| What SWIP is | A PPI issuer | An **online travel agency and merchant of record** |
| MCC the acquirer assigns | **6540** — excluded | **4722** — earns on almost every travel card |
| Whose money is it | Customer's, held in escrow | **SWIP's deferred revenue** |
| RBI PPI licence | Required | **Not required** |
| Interest on the balance | Barred except core portion | **Freely investable** (§5) |

**This is not a relabelling.** SWIP must genuinely become a travel seller:
contract with a consolidator or GDS, take the booking risk, be the name on the
customer's contract, handle refunds and cancellations. That is real work and
real liability. It is also the only structure where `E-05` becomes *true* rather
than *claimed*.

> **`E-05` is not blocked — it is achievable, by changing what SWIP is rather
> than what SWIP is called.** 4722 stops being something to engineer and becomes
> a simple description of the business.

### Requirements

| ID | Requirement |
|---|---|
| `V2-MOR-1` | SWIP contracts with a flight/hotel consolidator (TBO, Travelport, Amadeus) or an aggregator API |
| `V2-MOR-2` | SWIP is the **merchant of record** — its name on the statement, its contract with the customer |
| `V2-MOR-3` | Travel credit is **restricted-use**: redeemable only against travel inventory, never withdrawable as cash. This is what keeps it out of PPI scope |
| `V2-MOR-4` | Acquirer onboarding declares travel as the **primary** activity, with the consolidator contract as evidence |
| `V2-MOR-5` | Clear expiry and refund terms — restricted-use credit with no expiry starts to look like stored value again |

> ⚠️ **The line to watch.** If travel credit becomes withdrawable, transferable
> between users, or spendable outside travel, it is a PPI and everything in §1
> applies. Keep it restricted-use or the structure collapses.

---

## 3. The Probe card — `C-09` `C-10` `C-12` `C-13`

**Your most original idea, and the hardest.**

Your framing: a SWIP virtual card that gets *declined*, so no money moves, but
the attempted authorisation reveals the merchant's MCC.

### Why it works

An authorisation request carries the MCC **before** the issuer decides to
approve or decline. Decline it, and you still have the field. No money moves.
`C-13` — *"it's not related to payments or money"* — is precisely right.

### The real blocker — and it is not Visa vs Mastercard

`C-12` asked whether Visa or Mastercard should issue. **Neither is the
constraint.** The constraint is that in India, [non-bank PPI issuance requires
RBI authorisation](https://www.lexology.com/library/detail.aspx?g=741da40c-2952-4c9b-8f94-886e57b874ec):
an Indian company, an MoA covering PPI issuance, escrow with a scheduled
commercial bank, quarterly auditor certification, and now capital requirements
under the 2026 draft.

Card issuance proper needs a bank or an NBFC with the right licence.

### Three routes, ranked

| Route | How | Time | Cost | Verdict |
|---|---|---|---|---|
| **A. BIN sponsorship** | Partner bank issues; SWIP is the programme manager on their BIN | 6–12 mo | ₹25–75L setup | ✅ **The realistic route** |
| **B. Co-brand** | [Co-branding partners may only market and distribute; the issuer stays liable](https://razorpay.com/blog/business-banking/rbi-implements-new-norms-for-credit-debit-and-co-branded-cards-all-you-need-to-know/) | 6–9 mo | Lower | ⚠️ Too little control over the decline logic |
| **C. Own PPI licence** | Apply to RBI directly | 12–24 mo | ₹5Cr+ net worth | ❌ Not for v2 |

**Route A.** You need a partner bank willing to issue a card whose *designed
behaviour is to decline*. That conversation is unusual and you should expect to
explain it several times.

### The honest risk

A card programme whose intended outcome is a declined authorisation will attract
attention. Networks monitor decline ratios; a high-decline BIN can be flagged
for excessive authorisation traffic. **Mitigations:** rate-limit probes per user
per day, use a distinct BIN range from any spending product, and disclose the
mechanism to the sponsor bank in writing up front. Do not discover this after
launch.

> **Recommendation: Probe is v2.5, not v2.** It needs a bank partner, which
> needs traction, which needs v1 shipped. And [Vector 2 — the POS
> tap](03-RESEARCH-MCC-CAPTURE.md) already delivers most of the same value with
> no licence at all.

---

## 4. MDR and Coins — `F-01` `F-02`

Your model: user pays ~2% MDR to pay through SWIP, and SWIP gives it back as
coins.

### The arithmetic problem

Under the travel-MoR structure SWIP is not charging MDR — SWIP is **selling
travel at a margin**. That is a better position, because travel has a real gross
margin rather than a payments spread.

| Line | Per ₹1,00,000 of travel booked |
|---|---|
| SWIP gross margin (consolidator net vs. retail) | ₹3,000 – ₹8,000 |
| Payment acceptance cost (SWIP pays the acquirer) | −₹1,800 |
| **Contribution before rewards** | **₹1,200 – ₹6,200** |
| User's own card reward at 4722 (their bank pays this, not you) | *~₹2,000 in their points* |

**The user's reward comes from their own bank, not from SWIP.** That is the
entire elegance of the structure: SWIP does not fund the reward, it *unlocks*
one the user could not otherwise earn. Coins on top are a smaller, discretionary
loyalty layer funded from the margin above.

| ID | Requirement |
|---|---|
| `V2-COIN-1` | 1 Coin = ₹0.25 face value on travel redemption |
| `V2-COIN-2` | Coins accrue on booking, **vest after the travel date passes** — see `F-09` and §6 |
| `V2-COIN-3` | Coin liability is carried on the balance sheet from issue, not from redemption |
| `V2-COIN-4` | Hard cap: total coins issued per period ≤ 40% of gross margin for that period |

---

## 5. Float and interest — `F-05` `F-06` `F-07`

### What is barred, precisely

Under the PPI rules, [no interest is payable on escrow balances except on a
defined "core portion"](https://www.lexology.com/library/detail.aspx?g=35cfed04-f062-4c1e-9e38-7294773aa014),
and the 2026 draft moves that computation from fortnightly to monthly. So
`F-06` as literally stated — *hold customer wallet money in a debt fund and earn
interest* — **is barred for a PPI.**

### Why the travel structure dissolves the problem

Under §2, money paid for travel credit is not customer money in escrow. It is
**deferred revenue** — SWIP's own balance sheet, recognised when travel is
delivered. Deferred revenue is freely investable.

**Same rupees. Same float. Different legal character.** This is the answer to
`F-06`: your idea works, but only inside the travel structure, not the wallet one.

### The float model

| Parameter | Value | Why |
|---|---|---|
| Average hold period | **45–90 days** | Booking-to-travel gap. Answers `F-07` |
| Instrument | Liquid / ultra-short debt funds | T+1 redemption, low duration risk |
| Expected yield | **6.5 – 7.5%** | Indian liquid funds, Aug 2026 |
| **Reserve floor** | **≥ 60% held in overnight/liquid** | You must always be able to fulfil bookings |

**Per ₹1 crore of deferred revenue at 70 days:** roughly **₹1.3L** of float
income. Real, but note that it is a **second-order** revenue line. The travel
margin is first-order.

> ⚠️ **The failure mode that kills companies like this.** If float income is
> funding the rewards, and bookings slow, the reward promise outlives the income
> that pays for it. **Rewards must be funded from margin. Float is upside.**
> `V2-COIN-4` exists to enforce that.

`F-05` — the angel's cheque in a debt fund funding rewards — works as a
*bootstrap*, but it is not a business model, because it is not recurring. Present
it to investors as runway, never as unit economics.

---

## 6. Coins to miles — `F-08`

Your idea: 1:1, or 1:2 through partnerships.

**[05-LOYALTY-ALLIANCES §8](05-LOYALTY-ALLIANCES.md) already showed 1:2 loses
money at the first rupee** — roughly −₹45 per ₹1L. That finding stands.

| Ratio | Cost per 1,000 coins | Verdict |
|---|---|---|
| **1:1** | ~₹250 | ✅ Ship this |
| 1:1.5 promo, airline-funded, time-boxed | ~₹250 to SWIP | ✅ The right way to do "more lucrative" |
| **1:2 permanent** | ~₹500 | ❌ Loss-making |

**Transfer bonuses are the mechanism.** Airlines routinely fund 20–50% transfer
bonuses to acquire members — that is *their* marketing budget, not yours. You get
the headline ratio; they pay for it.

| ID | Requirement |
|---|---|
| `V2-MILE-1` | Base ratio 1:1, permanent, never devalued without 90 days' notice |
| `V2-MILE-2` | Bonus campaigns are **airline-funded**, time-boxed, capped in total miles |
| `V2-MILE-3` | Minimum transfer 1,000 coins, in 500-coin increments |
| `V2-MILE-4` | Transfers are **irreversible** and must say so before confirmation |

---

## 7. Transfers and alliances — `G-01`–`G-05`

**`G-01` cannot work as stated, and this is worth being blunt about: alliances
do not pool balances.** Star Alliance membership lets you *fly and redeem on*
partner metal. It does not let you move miles between member programmes. There
is no such mechanism.

`G-04` — **Air India has been in Star Alliance since July 2014**, so it is your
*strongest anchor candidate*, not the non-aligned exception you thought.

**What actually delivers `G-05` — "every airline in the world":**

| Tier | Mechanism | Reach |
|---|---|---|
| 1 | Direct transfer partners | 3–6 programmes |
| 2 | **Redemption reach via those programmes' alliances** | ~57 airlines from one Star anchor |
| 3 | Hotel-currency bridges (Marriott, Hilton → many airlines) | +40 |
| 4 | Cash-equivalent floor — coins buy a ticket outright | Everything else |

Tier 4 is what makes the promise honest. Anywhere the partner network doesn't
reach, coins still buy the seat.

---

## 8. Build order

Sequenced by dependency, and around the fact that the PPI rules are mid-rewrite.

| Phase | What | Gate |
|---|---|---|
| **v1** | MCC capture. No money, no licence | ← **you are here** |
| **v1.5** | Merchant graph at scale, card-reward matching ("which of *your* cards wins here") | 10k+ users |
| **v2.0** | **Travel MoR**: consolidator contract, 4722 acquiring, restricted-use travel credit | Legal + acquirer |
| **v2.1** | Coins, vesting, float treasury | v2.0 revenue |
| **v2.2** | First airline transfer partner | 50k+ users |
| **v2.5** | Probe card via BIN sponsorship | Bank partner |

**Do not start at v2.** Every downstream step needs the user base v1 creates —
and an airline will not talk to you without one.

---

## 9. What I could not settle

Stated plainly rather than papered over:

1. **Will an Indian acquirer actually assign 4722 to SWIP?** The logic is sound
   and it is how OTAs are coded, but [assignment involves acquirer
   judgement](https://www.rapyd.net/blog/your-guide-to-merchant-category-code-mcc-4722-travel-agencies-and-tour-operators/).
   **Ask two acquirers before building anything.** One conversation de-risks the
   entire v2 thesis.
2. **The final PPI Directions.** The April 2026 draft is not law yet. If
   restricted-use travel credit gets pulled into PPI scope in the final text,
   §2 needs rework.
3. **Whether a sponsor bank will underwrite a deliberately-declining card.** §3.
4. **Airline appetite at your scale.** Nobody signs a transfer partnership with a
   10k-user app.

---

## 10. The five things to do first

1. **Talk to two acquirers** about 4722 for a travel MoR. Free, and it validates
   the whole thesis.
2. **Get a consolidator quote** — TBO or Travelport. Tells you the real margin
   in §4.
3. **Read the final PPI Directions** when published.
4. **Ship v1.** Everything else needs users.
5. **Field-test 50 terminals** ([03-RESEARCH §3.4](03-RESEARCH-MCC-CAPTURE.md)) —
   still the highest-information experiment available to you.
