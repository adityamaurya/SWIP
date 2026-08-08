# SWIP — Business Model

> Answers ideation IDs `E-01` … `E-08`, `F-01` … `F-09`.
> Written against **Indian** regulation (assumption `Q-1`). If the launch market changes,
> §5 and §6 change completely; §3, §7 and §9 survive.
>
> **Three things in here contradict what you said.** They are marked ⚠️ and each one comes
> with a version of your idea that *does* work. I would rather hand you a plan that
> survives contact with a regulator than one that flatters the brief.

---

## 1. The one-sentence model

> **SWIP sells knowledge first and float second.**
> v1 gives away the MCC to build the merchant graph and the habit. v2 monetises the habit
> by becoming a genuine travel merchant, earning the spread and the float on prepaid travel
> credit, and giving the spread back to users as SWIP Coins that convert into airline miles.

The reason this holds together — and the thing that makes SWIP more than two unrelated
products bolted together — is in §4. Read that before §5.

---

## 2. Why v1 must be free

You framed v1 (know the MCC) and v2 (pay through us) as two tasks (`E-01`). They are, but
they are not equal.

| | v1 — Know | v2 — Pay |
|---|---|---|
| Licence needed | **None** | PPI / PA / travel MoR |
| Time to ship | Weeks | Quarters |
| Revenue | ₹0 | The whole model |
| Strategic value | **The merchant graph, the habit, the audience** | Monetisation |

v1 is not a lead magnet. **v1 is the asset.** A user who opens SWIP before every purchase
has given you the most valuable position in consumer fintech — pre-transaction attention.
Charging for it would trade a moat for pocket change. Give it away, permanently, with no
account required (`Q-2`).

---

## 3. Unit economics of v2 `F-01`

### 3.1 What MDR actually is in India, 2025–26

| Rail | MDR to merchant | Source |
|---|---|---|
| Credit card (Visa/MC), general | **1.5 % – 2.5 %** | [Backspace/Medium](https://backspace-tech.medium.com/the-economics-of-acceptance-merchant-discount-rate-mdr-5926eba465d1), [HonestMoney](https://honestmoney.in/credit-cards/credit-card-processing-fees-small-business-india-upi-vs-card) |
| Credit card, broad band | 1 % – 3 % | [EnKash](https://www.enkash.com/resources/blog/merchant-discount-rate-mdr-fees-calculations-insights) |
| Debit card | 0.25 % – 1 % | ibid. |
| Amex | ~3 % – 3.5 % (highest) | industry standard |
| **UPI (P2M)** | **Zero. Statutory.** Finance Ministry: claims MDR is coming are "false, baseless and misleading" | [NewsOnAir, Jun 2025](https://www.newsonair.gov.in/finance-ministry-says-there-is-no-plan-to-levy-mdr-charge-on-upi-transactions), [Rau's IAS](https://compass.rauias.com/economy/merchant-discount-rate/) |
| RuPay credit on UPI | **Zero ≤ ₹2,000** for small merchants; **1.1 % – 2 %** above ₹2,000 | [ZET](https://zetapp.in/blog/mdr-charges-on-rupay-credit-card), [Business Standard](https://www.business-standard.com/finance/news/rupay-credit-card-upi-transactions-double-in-first-seven-months-of-fy25-124120301103_1.html) |

**Consequence you need to internalise:** SWIP is the *merchant* in v2. When a user loads
₹100,000 with a credit card, **SWIP pays the MDR — roughly ₹1,800.** Your line *"they'll be
paying 2 % MDR on my platform"* (`F-01`) is right in effect but inverted in mechanics: the
user pays SWIP a **convenience fee**, and SWIP pays the acquirer an **MDR**. These are two
different numbers and the gap between them is thin.

### 3.2 The per-₹1,00,000 ladder

| Line | Amount | Note |
|---|---|---|
| User loads SWIP Travel Credit on a credit card | **₹1,00,000** | |
| Convenience fee charged to user @ 2.00 % | **+ ₹2,000** | your `F-01` |
| MDR SWIP pays its acquirer @ 1.80 % | **− ₹1,800** | negotiated; assumes Visa/MC, not Amex |
| **Gross spread** | **+ ₹200 (0.20 %)** | razor thin — and this is the point |
| Float, 30-day average hold @ 6.75 % p.a. | **+ ₹555 (0.55 %)** | §6 |
| Breakage / expiry (conservative 0.15 %) | + ₹150 | |
| **Gross contribution** | **₹905 (0.91 %)** | |
| SWIP Coins returned to user @ 0.40 % | **− ₹400** | your `F-02` |
| Payment ops, fraud, support @ 0.15 % | − ₹150 | |
| **Net contribution** | **₹355 — 0.36 %** | |

**Read the table again.** The MDR spread contributes ₹200. **The float contributes ₹555.**

> ⚠️ **Correction 1.** You described the model as *"they pay the MDR, I keep that amount and
> create interest out of it."* The MDR is ~2 % of the load and most of it leaves immediately
> to the acquirer. **The money worth investing is the ₹1,00,000 of unspent travel credit,
> not the ₹2,000 fee.** Same instinct, an order of magnitude different in size. Your
> business is float on balances, and the fee is only there to cover the MDR.

### 3.3 Why the user says yes

The user pays 2 % and earns their card's reward. On an Indian premium travel card returning
~3.3 % in transferable value, they net **+1.3 %**. On a 1 % cashback card they net **−1 %**
and should not do it.

**So SWIP must tell them which they are.** And SWIP is the only app on earth positioned to,
because SWIP already knows MCCs. See §4.

---

## 4. The join between v1 and v2 — the strategic core

This is the part of the business that wasn't in the brief and that I would defend hardest.

```
        ┌─────────────────────────────────────────────────────┐
        │  v1 knows THE MCC of every merchant                 │
        │  v1 knows WHICH CARDS the user holds                │
        │  v1 knows EACH ISSUER'S category rules & exclusions  │
        └────────────────────────┬────────────────────────────┘
                                 │
                                 ▼
        ┌─────────────────────────────────────────────────────┐
        │   "Pay this ₹42,000 with your Card A — it codes      │
        │    5812 and earns 10×. Do NOT route it through       │
        │    SWIP Credit; you'd lose 0.8 %."                   │
        │                                                     │
        │   "Pay this ₹42,000 through SWIP Travel Credit —     │
        │    direct it would code 6513 and earn nothing.       │
        │    Through us you net +1.9 %."                       │
        └─────────────────────────────────────────────────────┘
```

**SWIP is the only wallet in the market that will tell a user *not* to use it.**

That is the trust position, it is the reason v1 and v2 belong in one app rather than two,
and it is what turns a commodity wallet into a advisor with a balance sheet. It also
directly serves your `F-03` worry about greed: a user who is being told the honest answer
has far less incentive to game the system than one who is being milked.

---

## 5. The MCC question, answered honestly `E-05` `E-08`

You asked for a wallet *"named something that doesn't count as one of the excluded MCCs"*,
carrying *"some flights or travel aggregator merchant category code."*

### 5.1 ⚠️ Correction 2 — the name is irrelevant

An MCC is **not chosen by the merchant.** The acquirer assigns it at underwriting based on
the business's actual activity, and the networks audit assignments and penalise
miscoding. ([Visa Acceptance](https://support.visaacceptance.com/knowledgebase/knowledgearticle/?code=KA-09260))
Calling a wallet "SWIP Skyways" changes nothing. If the activity is *"load value, spend
anywhere"*, the acquirer codes it **6540 — Stored Value Card Purchase/Load**, and Indian
issuers exclude 6540 from rewards, milestones and fee-waiver spend. ([Kotak MCC list](https://www.kotak.bank.in/content/dam/Kotak/gsfcfiles/credit-cards/list-of-mccs-with-respect-to-revised-fees-and-rewards_june_01_2025.pdf), [Axis](https://www.axis.bank.in/important-links/credit-card/important-announcement-on-credit-card))

And even if you got a favourable code by misrepresentation, it would be **fraud against the
acquirer**, it would be caught by network category audits, and it would end the company.

### 5.2 The version that works: stop being a wallet

You do not need a wallet with a travel MCC. **You need to actually be a travel merchant.**
Then 4722 is not a trick — it is simply true.

> ### SWIP Travel Credit
> **Restricted-use prepaid value, redeemable only against travel inventory that SWIP sells.**
> Flights, hotels, buses, rail, visas, insurance, forex. Nothing else. Ever.
> Not spendable at a grocery store. Not withdrawable. Not transferable to a bank account.

Why this is legitimate and defensible:

| Test the acquirer applies | Wallet (fails) | SWIP Travel Credit (passes) |
|---|---|---|
| What is the customer buying? | Stored value | **A travel booking, paid in advance** |
| Where can it be spent? | Anywhere | **Only SWIP travel inventory** |
| Is SWIP the merchant of record for the end sale? | No, a pass-through | **Yes** |
| Is there real inventory and fulfilment? | No | **Yes — GDS/aggregator supply, PNRs issued** |
| Refundable to cash? | Often | **No — original card only** |

This is not novel or aggressive. **It is exactly how airline gift cards, MakeMyTrip wallet
credit and hotel-brand credit already work**, and they code as travel because they *are*
travel. The prepaid-credit-against-future-travel structure is ordinary commerce.

### 5.3 What this costs you

Honesty about the price of the honest route:

- You must build or licence real travel inventory (a GDS/consolidator or aggregator API).
  This is a genuine second product, not a label change.
- Your margin now includes travel margin (typically 2–6 % on hotels, thin on flights),
  which **helps** the model in §3.2 considerably.
- Your addressable spend shrinks from "everything" to "travel". That is a real loss.
- You will need a payment-aggregator relationship and possibly a PA licence depending on
  structure.

### 5.4 ⚠️ Correction 3 — MCC arbitrage is not a moat, at any scale

Even if you find a favourable coding, **issuers change exclusion lists every quarter**, and
they change them *specifically in response to volume they don't like*. Every arbitrage in
this space has died the same death — GrabPay top-ups in Singapore, wallet loads in India,
rent-payment platforms repeatedly. ([The MileLion](https://milelion.com/2020/07/21/rip-no-more-credit-card-points-for-grabpay-top-ups/))

> **Never build the company on the arbitrage.** Build it on the merchant graph (which no
> issuer can revoke) and let the travel structure be a *product*, not a loophole. If an
> issuer excludes 4722 tomorrow, SWIP v1 is untouched and SWIP v2 still sells travel.

### 5.5 Regulatory watch item

The June 2022 RBI circular barring non-bank PPI issuers from loading PPIs with credit lines
sits adjacent to this model, and the **Draft RBI (PPI) Directions, 2026** (issued 22 Apr
2026) tighten capital, ₹2 lakh wallet limits, escrow norms and interoperability.
([Medianama](https://www.medianama.com/2026/04/223-rbi-prepaid-payment-instruments-rules-wallet-limits-escrow-norms/), [Taxguru](https://taxguru.in/rbi/rbi-issues-draft-ppi-rules-strengthen-digital-payment-security-framework.html))
**A payments lawyer must sign off the Travel Credit structure before a rupee is loaded.**
This is the one place in the plan where I would not proceed on my own judgement.

---

## 6. The float engine `F-05` `F-06` `F-07`

### 6.1 ⚠️ The hard rule you must know

You said: hold the money, put it in a debt fund, earn interest, pay users back.

**Customer money held under a PPI licence cannot do that.**

- Non-bank PPI issuers must hold proceeds in a **separate escrow account with a scheduled
  commercial bank**, with quarterly auditor certification, and only specified debits and
  credits are permitted.
- **No interest is payable on escrow balances**, except on a defined **"core portion"** —
  computed from the average of the *lowest* monthly outstanding balances over the preceding
  12 months — which may be placed in a **fixed deposit with the escrow bank**. Not in a
  debt mutual fund. Not anywhere else.
- **PPI issuers may not pay interest on PPI balances** to users.

([Enterslice](https://enterslice.com/learning/rbi/compliance-on-wallets/), [Medianama](https://www.medianama.com/2026/04/223-rbi-prepaid-payment-instruments-rules-wallet-limits-escrow-norms/), [Business Standard on PA escrow](https://www.business-standard.com/article/economy-policy/rbi-allows-payment-aggregators-to-maintain-additional-escrow-account-120111701470_1.html))

### 6.2 The version that works

Three legally distinct pools. Only two of them can be invested, and the difference is the
whole game.

| Pool | What it is | Where it must sit | Can it earn? |
|---|---|---|---|
| **A. Customer float (PPI structure)** | Unspent value if you are a PPI issuer | Escrow, scheduled commercial bank | **Only the core portion, in an FD with the escrow bank** |
| **B. Deferred revenue (travel MoR structure)** | Customer paid in advance for travel SWIP will supply. This is **SWIP's revenue received in advance**, not customer money in trust | Ordinary corporate account | **Yes — full treasury freedom** |
| **C. Corporate cash** | Investor capital, retained earnings, fee income | Ordinary corporate account | **Yes** |

> **This is the single strongest argument for the travel-merchant structure in §5.2, and it
> has nothing to do with MCCs.** Under a wallet/PPI structure your float is legally frozen.
> Under a genuine merchant-of-record structure the same rupees are *deferred revenue*, and
> deferred revenue is yours to invest — subject to solvency, audit, and the absolute duty to
> deliver the travel you sold. **The same idea. A completely different balance sheet.**
>
> Pool B carries a real obligation: you owe the customer a flight, not a refund. Treasury
> policy must therefore be conservative to the point of boring. See 6.3.

### 6.3 How long should you hold it `F-07`

You asked me to research the ideal holding period. Here is the ladder, matched to
liability behaviour rather than to yield-chasing.

| Bucket | % of pool | Instrument | Why | Indicative yield |
|---|---|---|---|---|
| **T+0 operating** | 15 % | Overnight funds / sweep FD | Same-day redemption, effectively zero duration and zero credit risk. **No exit load** | ~6.0 – 6.3 % |
| **T+7 to T+90 working** | 55 % | **Liquid funds** — SEBI caps residual maturity at 91 days | The natural home for money whose liability is 30–60 days away. Graded exit load applies only to redemptions inside 7 days, nil from day 7 — so this bucket must never be touched before day 7 | ~6.6 – 7.0 % |
| **Statistical core** | 30 % | Money-market / ultra-short duration | Funded only by the 12-month **minimum** observed balance — the money that provably never leaves | ~7.0 – 7.5 % |
| | | **Blended** | | **~6.75 %** |

**Hard treasury rules — write these into policy on day one:**

1. **AAA / sovereign / T-bill and equivalent only.** No credit funds. No AA. No corporate
   bond funds. You are managing someone's holiday, not a return target. The 2018 IL&FS and
   2020 Franklin Templeton episodes exist precisely to teach this lesson.
2. **Duration never exceeds the 95th-percentile liability tenor.**
3. **Daily liquidity ≥ 3× the worst historical single-day redemption.**
4. **Never mark a treasury gain as revenue until realised.**
5. **The escrow-governed pool (A) never touches this ladder.** Segregate at the bank
   account level, not in a spreadsheet.

**Answer to "XYZ amount of time":**

> **Hold for 30 days to earn, and vest rewards at T+45.**
>
> - 30 days is the realistic average gap between load and travel booking.
> - 45 days for vesting sits comfortably past the practical chargeback/dispute window, so a
>   reversed load can be clawed back before coins become transferable.
> - It is short enough that users still feel the reward is *for this transaction*. Push
>   vesting past ~60 days and perceived value collapses while your float gain is marginal.
>
> Do not extend the hold to chase yield. Going from 30 to 90 days adds roughly 0.1 % of
> blended yield and materially increases liquidity risk and user distrust.

### 6.4 The investor conversation `F-05`

Your framing — *"an angel puts in X, I park it in a debt fund, the interest pays the
rewards"* — is a real mechanism but a weak pitch, and I want to be blunt about why.

**No investor funds a business whose returns come from investing their own cheque.** At
~6.75 %, ₹5 crore yields ~₹34 lakh a year. That is not a business; it is a fixed deposit
with an app attached, and any investor will say so.

**Here is the same money, pitched correctly:**

| Your framing | The fundable framing |
|---|---|
| "Invest ₹5 cr, I park it in debt funds and pay users from the interest" | "₹5 cr is the **float seed** that lets us honour rewards from day one before the balance sheet self-funds. **The return is the merchant graph and the take rate**, and the float becomes self-financing at ₹X crore of monthly load." |

**The break-even you should actually put on the slide:**

At 0.36 % net contribution (§3.2), and, say, ₹1.2 crore of monthly opex:

```
Required monthly load  =  ₹1.2 cr / 0.0036  ≈  ₹333 crore / month
```

That is a demanding number and it must be on the slide, because an investor will compute it
in ten seconds and you should be the one who computed it first. It has three honest levers,
and you should present all three:

1. **Travel margin.** Selling the trip, not just holding credit for it, adds 2–6 % on hotel
   and ancillary attach. This is the single biggest lever and it moves break-even by nearly
   an order of magnitude. It is also the reason §5.2 is strategy, not compliance theatre.
2. **Become the issuer.** Interchange on the *other* side of the transaction, once a card
   programme exists (Vector 4, route B).
3. **Licence the graph.** Issuers, acquirers and expense-management platforms all pay for
   verified merchant categorisation. This is high-margin and it is built for free by v1.

**The clean version of your pitch:**

> *"Every credit card user in India loses money to categories they can't see. We built the
> only app that shows the MCC before you pay — free, no login, and it works on any QR on
> earth and at the terminal itself. Every use makes our merchant graph better. Then we sell
> travel to the audience that is, by definition, optimising for travel rewards."*

---

## 7. Anti-abuse guardrails `F-03`

You worried about users who are *lalchi* — hungry for points — reloading without genuinely
spending. This is the well-known **manufactured-spend** attack, and it has killed programmes
much better capitalised than SWIP will be at launch. Nine controls, in order of how much
they matter.

| # | Control | Mechanism | Kills |
|---|---|---|---|
| **1** | **Refund to source only** | Unused credit refunds **only** to the original card, never to a bank account, never as coins | The whole attack. Load → refund → keep points becomes a zero-sum round trip with no cash-out |
| **2** | **No cash-out, ever** | Coins convert to travel or miles. Never to rupees | Removes the profit motive entirely |
| **3** | **Utilisation gate** | Coins vest only if ≥ 70 % of loaded credit is **actually consumed as travel** within 90 days | The load-and-sit attack |
| **4** | **Tiered reward decay** | First ₹50k/month at full rate; ₹50k–₹2L at half; above ₹2L at zero | Whales farming at scale, while leaving genuine users untouched |
| **5** | **Vesting ladder** | T+45 coins credited · T+90 transferable to airline partners | Chargeback and reversal fraud |
| **6** | **Clawback** | Any reversal, chargeback or refund claws back the coins, including from a transferred balance where the partner permits | Dispute abuse |
| **7** | **Identity dedup** | One card fingerprint (network token) across accounts; device + KYC dedup | Multi-account farming |
| **8** | **Velocity + pattern detection** | Round-amount repetition, load→refund cycling, same-card-many-accounts, load with no browse activity | Automated abuse |
| **9** | **KYC tiering** | Min-KYC to ₹10k, full KYC above; caps rise with tenure not with volume | Regulatory floor + a natural cooling period |

**Design note that matters more than any of the nine:** the *reward decay* in #4 is what
makes SWIP economically safe against the greedy user **without punishing the honest one**.
A user loading ₹40,000 a month for real holidays is never touched. A user loading ₹8 lakh
hits a wall he can see, understand and not resent. Guardrails users can read are guardrails
users don't attack.

---

## 8. Network coverage `F-04`

You said every card type must be supported — Visa, Mastercard, RuPay, JCB, everything.
Agreed, but they are not economically identical and the app must reflect that.

| Network | v1 (know) | v2 (pay) | Note |
|---|---|---|---|
| Visa | ✅ | ✅ | Baseline |
| Mastercard | ✅ | ✅ | Baseline |
| RuPay | ✅ | ✅ | **Special case:** RuPay credit on UPI is zero-MDR ≤ ₹2,000 for small merchants, 1.1–2 % above. Best-in-class for the user; SWIP should actively route here where it wins ([ZET](https://zetapp.in/blog/mdr-charges-on-rupay-credit-card)) |
| Amex | ✅ | ⚠️ surcharged | ~3 %+ MDR breaks the 2 % fee model. Either surcharge Amex explicitly or decline it. **Never silently absorb it** |
| Diners / Discover | ✅ | ✅ | Diners runs on the Discover network in India |
| JCB | ✅ | ✅ | Low domestic volume; support for completeness as you asked |
| UnionPay | ✅ | Phase 3 | |

**Product rule:** the load screen shows the *effective* fee per card **before** the user
picks one. No hidden surcharge. This is also, conveniently, the honest version of the
advisor position in §4.

---

## 9. Revenue streams, ranked

| # | Stream | Live in | Margin | Durability |
|---|---|---|---|---|
| 1 | **Float on deferred travel revenue** | v2 | ~0.55 % of load | High — it's arithmetic |
| 2 | **Travel margin** (hotels, ancillaries, insurance, forex) | v2 | 2–6 % | High |
| 3 | **Merchant-graph licensing** to issuers/acquirers/expense platforms | v2 | 80 %+ | **Highest — the moat** |
| 4 | Convenience-fee spread | v2 | 0.20 % | Low — compresses |
| 5 | Breakage | v2 | 0.15 % | Medium; regulate carefully, never predatory |
| 6 | Interchange, once SWIP issues | v3 | 1 %+ | High, licence-gated |
| 7 | SWIP Pro (advanced analytics, multi-card optimiser, unlimited probes) | v1.5 | 95 % | **Ship this early — it's the only v1 revenue and it needs no licence** |

> **If you take one thing from this document:** stream 7 in v1.5 and stream 3 in v2 are the
> two that require no regulator's permission and cannot be switched off by an issuer
> changing an exclusion list. Everything else is weather.

---

## Sources

[MDR economics](https://backspace-tech.medium.com/the-economics-of-acceptance-merchant-discount-rate-mdr-5926eba465d1) · [India card processing fees 2026](https://honestmoney.in/credit-cards/credit-card-processing-fees-small-business-india-upi-vs-card) · [EnKash — MDR](https://www.enkash.com/resources/blog/merchant-discount-rate-mdr-fees-calculations-insights) · [ZET — RuPay credit MDR](https://zetapp.in/blog/mdr-charges-on-rupay-credit-card) · [Finance Ministry on UPI MDR](https://www.newsonair.gov.in/finance-ministry-says-there-is-no-plan-to-levy-mdr-charge-on-upi-transactions) · [Rau's IAS — MDR](https://compass.rauias.com/economy/merchant-discount-rate/) · [Business Standard — RuPay credit on UPI](https://www.business-standard.com/finance/news/rupay-credit-card-upi-transactions-double-in-first-seven-months-of-fy25-124120301103_1.html) · [Enterslice — RBI wallet compliance](https://enterslice.com/learning/rbi/compliance-on-wallets/) · [Medianama — Draft PPI Directions 2026](https://www.medianama.com/2026/04/223-rbi-prepaid-payment-instruments-rules-wallet-limits-escrow-norms/) · [Taxguru — draft PPI rules](https://taxguru.in/rbi/rbi-issues-draft-ppi-rules-strengthen-digital-payment-security-framework.html) · [Policy Edge — PPI framework](https://www.policyedge.in/p/rbi-issues-draft-ppi-framework-with-2-lakh-wallet-limits-and-interoperability-mandate) · [Business Standard — PA escrow](https://www.business-standard.com/article/economy-policy/rbi-allows-payment-aggregators-to-maintain-additional-escrow-account-120111701470_1.html) · [Kotak MCC list](https://www.kotak.bank.in/content/dam/Kotak/gsfcfiles/credit-cards/list-of-mccs-with-respect-to-revised-fees-and-rewards_june_01_2025.pdf) · [Axis announcements](https://www.axis.bank.in/important-links/credit-card/important-announcement-on-credit-card) · [The MileLion — GrabPay](https://milelion.com/2020/07/21/rip-no-more-credit-card-points-for-grabpay-top-ups/) · [Visa Acceptance — MCC assignment](https://support.visaacceptance.com/knowledgebase/knowledgearticle/?code=KA-09260)
