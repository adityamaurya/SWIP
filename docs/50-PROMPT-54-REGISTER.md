# 50 — Prompt 54, every ask, tracked

> *"When I say priorities of getting MCC, it doesn't mean you have to discard
> it, queue it, keep it, or procrastinate it. You have to first implement the
> features surrounding this MCC port, get it implemented, and then you have to
> start building the very same session. The next important things, don't keep
> it logged simply and keep it piled up. Implement these as well."*

Fair, and taken. This round built two features and did not only file the rest.
What is still filed is filed **with a reason that is not "later"** — and for
three of them the reason is that they are not possible, which is a different
answer and is argued in [`49`](49-EVERY-ROUTE-TO-AN-MCC.md) rather than
asserted here.

**Status key** — ✅ built this round · 🔬 answered with evidence · ❌ cannot be
done, with the reason · 📋 planned, with what it is waiting on.

---

## A. The MCC routes — the research you sent

| # | Quoted ask | Status |
|---|---|---|
| A1 | *"What could be the possibilities for how we could get the MCC for the person?"* | 🔬 [`49`](49-EVERY-ROUTE-TO-AN-MCC.md) — **five routes**, each priced, with what it needs regulatorily |
| A2 | *"we could simply get him to make a payment of ₹1 to that QR code, and as soon as the payment is done, we get the MCC code right from this payment confirmation"* | ❌ [`49` §3](49-EVERY-ROUTE-TO-AN-MCC.md) — **the MCC is never returned to the paying app.** It is attached by the acquirer during settlement and travels acquirer→issuer, around the phone |
| A3 | *"I'm not sure how we could get these refunded because he's paying the merchant directly"* | 🔬 You cannot. A UPI push to a merchant has **no reversal available to the payer** — a refund is the merchant's decision. You spotted the hole yourself and it is the deeper of the two problems |
| A4 | *"For Federal Bank … I get to see the merchant category code extension at the very end of each statement line"* | 🔬 True, and it does not generalise. It is **free-text narration** in that bank's own format. The ReBIT schema that standardises statement data has **no MCC field** — [`49` §4](49-EVERY-ROUTE-TO-AN-MCC.md) |
| A5 | *"let's say we have a wallet system … we could get these cards tapped under this POS … we will get the POS merchant category report"* | 🔬 **Technically sound, and it is a licence.** You must *be* the issuer: PSS Act authorisation and **₹5 cr net worth rising to ₹15 cr**. [`49` §5](49-EVERY-ROUTE-TO-AN-MCC.md) |
| A6 | *"find me a set of vendors who are very easy to partner with"* | 🔬 [`49` §9](49-EVERY-ROUTE-TO-AN-MCC.md) — **more than one per layer**, as asked. None should be integrated before A8 |
| A7 | *"go through the RTF file extensively"* | 🔬 Read in full. Confirmed on four points, **corrected on three** — [`49` §10](49-EVERY-ROUTE-TO-AN-MCC.md) |
| A8 | *"the major issue is not getting the MCC"* | 📋 **Waiting on twenty POS taps.** The instrument is built and costs nothing; `docs/47` is a sample of one and the number decides how much of SWIP rests on that route. **This is the highest-value thing available and it is not code** |

---

## B. The payment hand-off — built

| # | Quoted ask | Status |
|---|---|---|
| B1 | *"I could also have continued payment in this pop-up which I get for the MCC … I don't have to close this dropdown, this modal, and then go to the payment app and again scan"* | ✅ `F-194` — **Continue payment**, full width above the pair |
| B2 | *"It gives an option of a list of apps which can make payment to this giver"* | ✅ `F-194` — SWIP's own sheet, with the apps' real icons |
| B3 | *"This payment address will then be fetched into other apps when I click Choose"* | ✅ `F-194` — and **the original payload goes on byte for byte**, because a signed QR rebuilt from `pa`+`pn` loses its signature |
| B4 | *"For now, let them first … select the application from this list of apps, and then put their amount into that chosen app"* | ✅ No `am=` is ever sent. There is a test asserting it |
| B5 | *"sometimes in the future … we will give them an input for the amount as well"* | 📋 One argument — `UpiHandoff.compose` already takes an amount and nothing reaches it |
| B6 | *"the same in the floater window … a button below in the very same window to continue the payment"* | ✅ `F-194` — the footer is shared by both windows, so the hovering card has it too |

---

## C. Apparatus and process

| # | Quoted ask | Status |
|---|---|---|
| C1 | *"can you help me create a master export file for all the types of exports … so that you have a mega export file?"* | ✅ `F-195` — all three recorders and the phone, in one file |
| C2 | *"Have it in the build debug APK at the very end, at the very lowest part of it"* | ✅ Last row of the Diagnostics block, which only draws on a debug build |
| C3 | *"I hope you are updating the lectures wherein these functionalities are being documented"* | ✅ [`CHANGELOG`](CHANGELOG.md), [`21`](21-PROMPT-LEDGER.md), [`28`](28-CONVERSATION-LOG.md), and this page |
| C4 | *"I'm not sure how that Razorpay thing … works. I'm unable to use it"* | 📋 [`43`](43-RAZORPAY-IN-PLAIN-WORDS.md) explains it and clearly has not landed. **The next attempt should be the screen, not another page** — see §E |

---

## D. The roadmap you set out

Filed as a roadmap because that is what it is — each of these is weeks, and
none is blocked on anything but sequence.

| # | Quoted ask | Status |
|---|---|---|
| D1 | *"they start putting their credit cards and the details, maybe by tapping, like how Zomato or district does"* | 📋 Reading a card by NFC is `ReadPaymentCard`-shaped and SWIP already runs HCE. **Storing card data is the hard half** and changes SWIP's security posture — it needs its own page before any code |
| D2 | *"we get the MCC, and we start recommending which would be the best credit card"* | 📋 The natural next feature **after** D1, and the first one that makes the ledger pay for itself |
| D3 | *"putting in intelligence … airlines or air miles, whatever criteria of the cards, how much the limits are, whether they might have achieved some milestones"* | 📋 A rules engine over D1's card list |
| D4 | *"If a recommended card is rejected … ask them why the deviation happened"* | 📋 The cheapest way to learn whether D2 is any good, and it should be built **with** D2, not after |
| D5 | *"agents will start crawling, firstly, into the messages, keeping track and mapping the expenses"* | 📋 ⚠️ **`READ_SMS` is a restricted Play permission** — the same class as `QUERY_ALL_PACKAGES` in §B and the Doze exemption in [`36`](36-DEVIATIONS.md) D-45. It is granted to apps whose core purpose is SMS, and a rejection here costs the listing, not a feature. Needs the same treatment `F-194` gave package visibility: find the narrow form, or decline it |
| D6 | *"an agent which is keeping a type of offers going on in the entire world of credit cards"* | 📋 And it is a **server**, which SWIP does not have. Worth saying out loud before it is designed, because "no server" is the product's main security claim |
| D7 | *"the next agent would be keeping track of the credit cards that that person should have instead"* | 📋 Same |

---

## E. Still open from prompt 51

Sixteen items were registered in [`48`](48-PROMPT-51-REGISTER.md) and two of
them closed this round as a side effect (E10, E11 — the payment hand-off).
**Fourteen remain**, and the order in `48` §H still holds: the scan black box
first, because it is what makes the zoom and low-light complaints measurable
instead of argued about.

Two bubble faults from prompt 51 are still unfixed and still holding the
temporary bubble trace in the tree — the flicker on close and the glyph not
staying a cross. [`38` §8](38-BUBBLE-TRACE.md) records why that hold is a
decision rather than an oversight.

---

## F. The one thing to say plainly

You asked for this to be **implemented, not piled up**, and for the MCC work
not to be used as a reason to defer everything else. Both happened: the payment
hand-off and the master export are in this build.

But the honest headline is the correction, not the features. **Two of the three
routes you were most hopeful about cannot be built** — the ₹1 probe because the
category never comes back to the phone, and the Account Aggregator route
because SWIP is not a regulated entity and the standard schema has no field for
it anyway. The third, the wallet, works and costs ₹5 crore to begin.

That leaves the two SWIP already has, and the thing neither of us can shortcut:
**more taps.** Twenty terminals answers the only question that decides what
this product is.
