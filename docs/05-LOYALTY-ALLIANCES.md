# SWIP — Loyalty, Alliances & the Coin Economy

> Answers ideation IDs `F-08`, `F-09`, `G-01` … `G-05`.
> Contains one significant correction to a premise you built on. It is in §2, and the
> good news is that your conclusion survives it — you were right about *what to do* and
> wrong about *why it works*, which is the best kind of wrong.

---

## 1. SWIP Coins — the currency

| Property | Value | Rationale |
|---|---|---|
| Name | **SWIP Coins** | your `F-02` |
| Earned on | Travel Credit loads, verified captures, referrals, streaks | |
| Base rate | **0.40 % of load value** | funded in [04-BUSINESS-MODEL §3.2](04-BUSINESS-MODEL.md#32-the-per-100000-ladder) |
| Vesting | **T+45 credited · T+90 transferable** | `F-09` — anti-abuse *and* the float window |
| Cash-out | **Never** | Guardrail #2. Non-negotiable |
| Redemption | Airline miles (1:1), SWIP travel inventory, hotel currencies | |
| Expiry | 24 months rolling, reset on any activity | breakage without predation |
| Display | Always shown with **₹ value and mile value side by side** | users cannot compare offers in an opaque currency, and an opaque currency is how loyalty programmes lose trust |

---

## 2. The alliance misconception `G-01`

You wrote:

> *"They can convert to either of these alliances and later on transfer internally,
> whatever feels best to them."*

### ⚠️ Alliances do not pool or transfer miles.

Star Alliance, Oneworld and SkyTeam are **commercial alliances for flying**, not currency
unions. Membership gives you:

- ✅ Earn miles in *your* programme when you fly a partner's metal
- ✅ **Redeem** your programme's miles *on* any partner's flights
- ✅ Reciprocal elite status recognition, lounges, priority
- ❌ **Transfer a balance from one member programme to another** — this does not exist

You cannot move miles from Aeroplan to United MileagePlus, or from Flying Blue to Delta
SkyMiles. There is no mechanism. ([Simple Flying — alliance status transfers](https://simpleflying.com/7-airline-status-transfers-alliance-partners/))

### Why your conclusion is still right

Because of the second bullet. **Redemption reach is transitive even though balances are
not.**

Air India's Maharaja Club lets a member earn and redeem across **all 25 Star Alliance
member airlines** — Lufthansa, Singapore, United, ANA and the rest. ([Air India — partner airlines](https://www.airindia.com/in/en/maharaja-club/redeem-points/partner-airlines.html), [Magnify](https://magnify.club/partners/air-india/), [Air India — Star Alliance partners](https://www.airindia.com/in/en/destinations/partner-airlines/star-alliance-partners.html))

```
        SWIP Coins
             │
             ├──1:1──► Star anchor    ──redeem on──►  25 Star Alliance carriers
             ├──1:1──► Oneworld anchor──redeem on──►  ~13 Oneworld carriers
             └──1:1──► SkyTeam anchor ──redeem on──►  ~19 SkyTeam carriers
                                                      ─────────────────────
                                                      ~57 airlines from 3 deals
```

> **So: three partnerships, not sixty. Your instinct in `G-02` was exactly right.**
> Just describe it as *"redeem across the alliance"*, never as *"transfer within the
> alliance"* — the second is false and a loyalty-savvy audience will catch it instantly,
> and that audience is your entire user base.

---

## 3. Air India `G-04`

You said, hedging: *"for example, this one, Air India, I guess, which is not under some
alliance. I'm not sure."*

**Correction:** Air India **joined Star Alliance on 11 July 2014**, the first Indian carrier
to do so. Its programme is **Maharaja Club** (renamed from Flying Returns). Vistara merged
into Air India in November 2024, so Club Vistara no longer exists as a separate currency.
([Air India — alliances](https://www.airindia.com/in/en/destinations/alliances-and-partnerships.html), [Magnify](https://magnify.club/partners/air-india/))

So Air India is not the non-aligned exception — **it is your single strongest Star Alliance
anchor candidate**, and §4 explains why.

---

## 4. The three-anchor strategy `G-02`

| Alliance | **Recommended anchor** | Why this one |
|---|---|---|
| **Star Alliance** | **Air India — Maharaja Club** | Home carrier, home market, home currency. Redemption across 25 carriers. And a specific opening: as of early 2026 **no major US transferable-currency programme transfers into Flying Returns/Maharaja Club** — not Amex, Chase, Capital One, Citi or Bilt. ([TransferPoints](https://transferpoints.com/airlines/air-india), [Magnify](https://magnify.club/partners/air-india/)) A programme starved of external inflow is a programme motivated to sign a new inbound partner. **This is your most winnable deal and your best negotiating position.** |
| **Oneworld** | **Qatar Airways Privilege Club (Avios)** | Avios is the one genuine multi-airline currency in existence — shared across British Airways, Iberia, Aer Lingus, Finnair and Qatar, and **movable between those programmes**. One Avios deal buys you five programmes and the exception to §2. Qatar also has enormous India–West capacity |
| **SkyTeam** | **Air France-KLM — Flying Blue** | The most partner-friendly SkyTeam programme by a distance, accepts transfers from essentially every major bank currency (so the integration pattern is well-trodden), strong India–Europe network, and a monthly Promo Rewards engine that gives SWIP marketing surface |

**Sequencing.** Do **not** try to sign three at once. Sign **one** — Air India, for the
reason above — prove transfer volume, then use that volume as the case for the other two.
An airline signs a loyalty partner on evidence of inbound miles purchased, not on a deck.

**Commercials to expect.** You are *buying miles* from the airline at a negotiated bulk
rate. That rate — not the display ratio — is your actual cost, and it is the number the
whole coin economy is built on. Negotiate it before you publish any earn rate.

---

## 5. The non-aligned carriers `G-03`

You were right that these exist and must be handled separately. The list that matters for
an Indian launch:

| Carrier | Programme | Alliance | Priority |
|---|---|---|---|
| **IndiGo** | BluChip | **None** | **P0** — India's largest carrier by a wide margin. If SWIP is an Indian travel product without IndiGo, it is not an Indian travel product |
| **Emirates** | Skywards | None | P1 — dominant on India–Gulf–West |
| **Etihad** | Etihad Guest | None | P1 |
| **Akasa Air** | Akasa Rewards | None | P2 |
| **SpiceJet** | SpiceClub | None | P3 |
| Air India Express | — | (Air India group) | via Air India |

Two corrections to assumptions people commonly make here, so you don't repeat them in a
pitch: **Qatar Airways is Oneworld** (since 2013) and **Turkish Airlines is Star Alliance**
(since 2008). Neither is a non-aligned carrier.

---

## 6. The coverage ladder `G-05`

You want **every airline in the world** reachable. Four tiers get you there, and only the
first needs deals.

| Tier | Mechanism | Coverage | Cost to SWIP | Ships |
|---|---|---|---|---|
| **1. Direct partners** | Coins → miles, 1:1 | 3 anchors + IndiGo + Emirates ≈ **5 programmes** | Bulk mile purchase | v2 |
| **2. Alliance redemption reach** | Anchor miles redeemed on any alliance partner's metal | **~57 airlines**, free, no extra deals | ₹0 | v2, day one |
| **3. Hotel-currency bridge** | Coins → **Marriott Bonvoy**, which itself transfers out to ~40 airline programmes | **+40 programmes**, including many outside all three alliances | One deal | v2.5 |
| **4. Cash-equivalent floor** | Coins spent directly on **any flight, any airline** inside SWIP Travel at a published fixed value | **Literally every airline that sells a ticket** | Your travel margin | v2 |

> **Tier 4 is the honest answer to "every airline in this world."**
> No loyalty programme on earth partners with every airline. But *every* airline sells
> tickets, and SWIP-as-travel-merchant can buy one. Publish a floor value —
> *"1 Coin ≥ ₹0.25 against any flight, always"* — and the promise is kept, permanently,
> with zero partner risk. Miles are the upside; the floor is the guarantee.
>
> This also quietly solves a problem you didn't raise: a loyalty currency with a visible
> floor cannot be devalued by a partner walking away.

---

## 7. The 1:1 versus 1:2 question `F-08`

You asked for 1:1, or 1:2 "to make it more lucrative."

### The arithmetic, on the ₹1,00,000 load from [04-BUSINESS-MODEL §3.2](04-BUSINESS-MODEL.md#32-the-per-100000-ladder)

| | 1 Coin : 1 mile | 1 Coin : 2 miles |
|---|---|---|
| Reward budget @ 0.40 % | ₹400 | ₹400 |
| Coins issued | 800 | 800 |
| Miles SWIP must buy | 800 | **1,600** |
| Cost @ ₹0.50/mile bulk | ₹400 ✅ | **₹800** ❌ |
| Gross contribution available | ₹905 | ₹905 |
| **Net after ops (₹150) and MDR spread** | **+₹355** | **−₹45** |

> **1:2 is not expensive. It is loss-making at the first rupee.** The company pays users to
> transact. That is not a growth loop, it is a leak, and it scales linearly with success.

### What to do instead — and it feels better than 1:2

Airlines fund **transfer bonuses themselves**, routinely, because they are selling you
miles and a bonus is their acquisition cost, not yours. Flying Blue, Avios programmes and
most major schemes run 20–40 % inbound transfer bonuses several times a year.

> **Ship 1:1 as the permanent, honest, always-on rate.**
> Then run **"1:1.4 to Flying Blue, this month only"** — funded by Air France-KLM.
>
> The user gets the surge of a bonus several times a year. SWIP's cost is unchanged.
> And a *permanent* 1:2 wouldn't even feel lucrative — a rate that never moves stops
> registering as a reward within about two months. Variability is the product.

### One more rule

**Never publish a rate you cannot hold for 24 months.** Devaluation is the single fastest
way to lose a points-and-miles audience, and a points-and-miles audience is not a market
segment for SWIP — it is the entire market. They will screenshot your launch rate and
hold it against you for years.

---

## 8. What the Rewards screen must show

Directly from `D-10` — *primary has to be visible*:

```
   ┌─────────────────────────────────────────────┐
   │   SWIP COINS                                │
   │                                             │
   │   12,480                                    │
   │   ≈ ₹3,120  ·  ≈ 12,480 miles               │
   │                                             │
   │   ● 9,200 available                         │
   │   ○ 3,280 vesting  →  12 Sep                │
   ├─────────────────────────────────────────────┤
   │   TRANSFER TO                               │
   │                                             │
   │   Air India Maharaja Club      1:1     →    │
   │   Qatar Privilege Club         1:1     →    │
   │   Flying Blue          1:1.4  ⚡ till 30 Sep │
   │   IndiGo BluChip               1:1     →    │
   │   Marriott Bonvoy              1:1     →    │
   ├─────────────────────────────────────────────┤
   │   Or spend on any flight, any airline       │
   │   Floor value ₹0.25 / Coin, always     →    │
   └─────────────────────────────────────────────┘
```

Note what is on screen without a tap: the balance, **both** valuations, what's vesting and
when, every rate, and the floor. Nothing is behind a disclosure. That is the trust posture
the whole company depends on.

---

## Sources

[Air India — alliances & partnerships](https://www.airindia.com/in/en/destinations/alliances-and-partnerships.html) · [Air India — Maharaja Club partner redemption](https://www.airindia.com/in/en/maharaja-club/redeem-points/partner-airlines.html) · [Air India — Star Alliance partners](https://www.airindia.com/in/en/destinations/partner-airlines/star-alliance-partners.html) · [Magnify — Maharaja Club & Star Alliance](https://magnify.club/partners/air-india/) · [TransferPoints — Air India transfer partners](https://transferpoints.com/airlines/air-india) · [Simple Flying — alliance status transfers](https://simpleflying.com/7-airline-status-transfers-alliance-partners/) · [Upgraded Points — flying to India on points](https://upgradedpoints.com/travel/best-ways-to-fly-to-india-with-points/)
