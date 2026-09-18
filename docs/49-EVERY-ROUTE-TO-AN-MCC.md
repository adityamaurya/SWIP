# 49 — Every route to an MCC, priced and checked

> *"What could be the possibilities for how we could get the MCC for the
> person? … I have been through a set of resources … tell me one way that we
> could get out of it."* — prompt 54

You sent a research document. It is a good one — better than most of what is
written about this — and this page does two things with it: **confirms the
parts that hold up**, and **corrects the two that do not**, because one of
those two is the plan you were most excited about.

Then it prices all of it, because the difference between these routes is not
difficulty. It is **who is allowed to do them.**

---

## 0. The one-paragraph answer

**There are five routes. One is built and shipping, one is built and needs a
corpus, one needs a licence SWIP cannot get today, one needs ₹5–15 crore, and
one is cheap, legal and only ever a guess.**

The ₹1-probe idea does not work — not because it is hard, but because the MCC
is never sent back to the paying app. The wallet idea works, and it is the most
expensive thing in Indian fintech to start. The realistic next move is the
fifth route plus more taps.

---

## 1. Route A — read it out of the QR · **BUILT · FREE · WORKS ~10% OF THE TIME**

Parse `mc=` from the payload. No API, no permission, no partner.

The problem is not the parser, it is the world:

| | Codes | Carry a usable `mc` |
|---|---|---|
| Google Pay for Business | 5 | **5** |
| Paytm | 14 | 0 |
| PhonePe | 15 | 0 |
| BharatPe | 6 | 0 |
| Bank-issued | 8 | 0 (one blank `mc=`) |

**5 of 48.** That is [`docs/42`](42-MARKET-QR-CORPUS.md), from one market walk,
and it is the single most important number this project has measured. **The
acquirer decides**, not the shop and not SWIP.

Your research says the same thing in §2 and it is right.

---

## 2. Route B — read it off the card machine · **BUILT · FREE · UNKNOWN HIT RATE**

Tap the terminal, run the EMV exchange, pull tag `9F15` out of the GPO
response, then decline. Your document's §4 describes this accurately, including
the detail that matters — **decline before any cryptogram is generated** — and
it is what SWIP already does.

**One correction to your document.** It says this is *"the most deterministic,
mathematically absolute method."* It is deterministic about what the terminal
sends. It is not a guarantee that the terminal has anything to send.

[`docs/47`](47-THE-STARBUCKS-TERMINAL.md) is the proof, from your own tap: a
complete, successful exchange in which the amount, date, time, country,
currency and terminal capabilities were **correct to the byte**, and `9F15`,
`9F16`, `9F1C` and `9F4E` were **all zeros**. An MCC is assigned by the
acquirer and lives in the acquirer's switch; a terminal does not need one to
run an EMV kernel, so many are never provisioned with one.

**That is a sample of one.** The number that decides how much of SWIP rests on
this route is *how many terminals publish `9F15`*, and the only way to learn it
is to tap more of them. The instrument is built and costs nothing — `F-187`'s
POS black box writes a `hce.tags` line per tap, and whether `9F15` is in it is
the whole question.

**This is the highest-value unpaid work available to this project.** Twenty
taps over a fortnight of ordinary shopping answers it.

---

## 3. Route C — the ₹1 probe · **DOES NOT WORK**

> *"we could simply get him to make a payment of ₹1 to that QR code, and as
> soon as the payment is done, we get the MCC code right from this payment
> confirmation."*

This is the idea to let go of, and I want to be exact about why, because the
reason is not "it is hard".

**The MCC is never sent to the paying app.** A UPI payment response to a TPAP
carries the transaction status, an RRN and a reference — not the merchant's
category. The category is attached by the **acquirer** during settlement, on
the network, travelling from the acquiring bank to the issuing bank. It goes
*around* the payer's phone, not through it.

So the ₹1 would be spent and nothing would come back. Not "a small amount of
data" — nothing.

### And the second half of the idea has a worse problem

> *"He simply makes a ₹1 payment … He loses the payment … It is very important
> for us to close the payment and get the MCC code."*

You saw this yourself. A thousand shops a day at ₹1 is ₹1,000 a day of the
user's money paid to strangers, unrecoverable, because **a UPI push to a
merchant VPA has no reversal mechanism available to the payer.** There is no
"undo". A refund is a decision the merchant makes.

Even if the MCC did come back, a product whose categorisation method is
"spend a rupee at every shop you walk past" is one the user abandons in a week.

### The half of it that is right

Your instinct that *a completed transaction knows the category* is correct.
That is Route D, and it is where that instinct leads.

---

## 4. Route D — the bank statement, via Account Aggregator · **BLOCKED ON A LICENCE**

> *"For Federal Bank, whenever we make a payment, if we extract the statement
> from them … I get to see the merchant category code extension at the very end
> of each statement line."*

Your document's §5 builds a whole architecture on this, and it is the part I
had to go and check rather than agree with. **Two corrections, one of them
fatal for now.**

### Correction 1 — SWIP cannot be an FIU

The Account Aggregator framework has three roles: FIP (the bank that holds the
data), AA (an RBI-licensed NBFC that moves it), and FIU (the app that consumes
it). Your document says SWIP would register as an FIU "or partner closely with
an existing licensed FIU entity".

Sahamati — the AA ecosystem's own self-regulatory body — states the eligibility
rule without hedging:

> *"Any entity registered and regulated by any of the financial sector
> regulators viz. RBI, SEBI, IRDAI, PFRDA or Department of Revenue … is
> eligible to be an FIU, AA or FIP … **you cannot be an FIU or FIP if you are
> not a regulated entity.**"*
> — [sahamati.org.in/faq](https://sahamati.org.in/faq/)

SWIP is not regulated by any of those five. It is an app that reads a QR code
and does not touch money — which has been its defining property since round one
and is why it can ship at all. **That property is exactly what disqualifies
it.**

"Partner with a licensed FIU" is not a workaround either. The FIU is the entity
the consent is granted *to*; data reaching a non-FIU through one is the thing
the framework exists to prevent.

### Correction 2 — the ReBIT schema has no MCC field

Your document states that AA data *"frequently include extended transactional
metadata fields, specifically the MCC, the counterparty VPA, and the terminal
identifier."*

The ReBIT `deposit` schema's `Transaction` element carries exactly these
attributes: **`type`, `mode`, `amount`, `currentBalance`, `transactionTimestamp`,
`valueDate`, `txnId`, `narration`, `reference`.**

**There is no MCC field.** A published sample narration reads:

```
UPI/935314560764/getsimpl/simpl@axisbank/Axis Bank
```

A reference number, a name, a VPA and a bank. No category.
— [ReBIT deposit schema](https://specifications.rebit.org.in/api_schema/account_aggregator/documentation/deposit.html)

So what you see on your Federal Bank statement is real — some banks do print a
category on **card** transaction lines — but it is in a **free-text narration
column**, in whatever format that bank chose, and it is not a structured field
any standard obliges them to provide. An app built on parsing it would work for
Federal Bank and break on the next bank, silently.

**Verdict: not available today. Worth revisiting the day SWIP has a regulated
partner, and not before.**

---

## 5. Route E — a wallet or prepaid card · **WORKS · ₹5–15 CRORE**

> *"since we have prepaid cards facilitated for this wallet, we could get these
> cards tapped under this POS … we will simply capture the cancelled payment …
> we will get the POS merchant category report from this platform."*

**This one is technically sound**, and it is the only route that gets the MCC
from a *declined* transaction legitimately — because the authorisation message
reaching the issuer's switch carries the MCC whether it is approved or not.

That is also the catch, and it is the whole catch: **you have to be the
issuer**, or its program manager.

### What it actually costs

| Requirement | Detail |
|---|---|
| **Authorisation** | A Certificate of Authorisation under the Payment and Settlement Systems Act, 2007, from RBI |
| **Net worth** | **₹5 crore at application, scaling to ₹15 crore within three financial years** and maintained after |
| **Incorporation** | Indian company, with PPI issuance in the Memorandum of Association |
| **Plus** | KYC/AML, a sponsor bank or BIN, a card management system, settlement, dispute handling |

([RBI's draft Master Direction on PPIs, 2026](https://ksandk.com/newsletter/rbi-draft-ppi-directions-2026/))

The alternative is a **BIN sponsor** — an existing licensed issuer whose
programme you ride on, with a processor like M2P, Zeta or Juspay in the middle.
That is the model your M2P articles describe, and it is real: it drops the
licence requirement but not the KYB, the capital, the compliance or the
commercial agreement with a bank.

### The honest framing

This is not "phase two of SWIP". It is **a different company**, with a
compliance function, that happens to also know shop categories. Worth wanting.
Not worth confusing with a sprint.

---

## 6. Route F — infer it · **CHEAP · LEGAL · ALWAYS A GUESS**

Your document's §6 and §7: resolve the VPA to a legal name, look the name up in
the GST registry, translate the HSN/SAC code to an MCC; or geolocate the scan
and map a Google Places `place_type` to an MCC.

Both work. Both are buildable this month. Both are **inference**, and the
document says so: *"not perfectly analogous to the exact four-digit code
assigned by an acquiring bank's internal risk department."*

**That sentence is the entire design problem**, because SWIP's promise is
*which card to use*, and a wrong MCC is worse than no MCC: the user pays with
the wrong card and finds out on the statement.

CRED's hedge is the right model and this project has matched it since round
one — *"MERCHANT MAY NOT ACCEPT RUPAY CC"*. The word *may* is doing the work.

**If this is built, it must be visibly a guess.** A different colour, a
different word, never the same hero number a published `mc=` gets. SWIP already
has the machinery: `MccConfidence` has a `likely` value and the UI already
renders it differently.

**Recommended, with that constraint.** The GST route resolves formal merchants;
the Places route covers the kirana that has no GSTIN. Neither needs a licence.

---

## 7. Your competitive question, answered

> *"My biggest fear … is that CRED has this wallet system. Any day, it could
> simply start showing the MCC codes in its wallet system."*

**It could. And the fear is aimed at the wrong risk.**

CRED already has everything it needs: a large user base, an RBI-registered
entity, card rails, and — with CRED Pay and its prepaid instrument — exactly
the issuer position Route E describes. If CRED decides to show MCCs, it can.

So SWIP cannot win on *having* the data. Two things are still true:

1. **Nobody has done it.** The category is not shown by CRED, PhonePe, GPay,
   Paytm, or any bank app, for a reason that is not technical: showing it
   invites the question *why can't I use my card here*, which is a support
   cost, and none of them sells that answer.
2. **SWIP's position is the one they cannot copy without giving something up.**
   No account, no server, nothing uploaded. CRED's model requires the opposite.
   A company that has built its business on knowing what you spend cannot
   credibly ship the app that knows nothing about you.

The defensible thing is not the MCC. It is **the corpus** — Route B's answer to
"how many terminals publish `9F15`", and Route A's 5-in-48. Nobody else is
measuring this, and every route above gets more accurate with it.

---

## 8. The recommendation, in order

1. **Ship the payment hand-off.** Done this round, `F-194` — it makes SWIP
   useful at the counter whether or not the category is found, which is the
   first time that has been true.
2. **Tap twenty terminals.** Free, already instrumented, and it decides how
   much of the product rests on Route B. *This is the highest-value thing you
   personally can do.*
3. **Build Route F behind a visible hedge.** Weeks, not quarters. It turns "no
   category" into "probably a pharmacy" without ever claiming more.
4. **Revisit Route D** when there is a regulated partner to stand behind.
5. **Route E is a company**, not a feature. File it as an ambition.

**Route C is closed.** The MCC does not come back from a payment.

---

## 9. Vendors, more than one per layer

> *"do not stick to only one vendor because we are not sure if that is best or
> not"*

| Layer | Options |
|---|---|
| VPA → name | Razorpay, Cashfree, Decentro, Juspay. **None returns an MCC** — [`docs/41`](41-RAZORPAY-EXPLAINED.md) |
| GST lookup | ClearTax, Signzy, Karza (Perfios), SurePass, ExpressGST |
| Places | Google Places, Mapbox, HERE, OpenStreetMap/Nominatim (free, thinner in India) |
| Card issuing / PPI | M2P, Zeta, Juspay, Yap, Decentro — all need the licence or a sponsor bank first |
| Account Aggregator | Finvu, Onemoney, CAMS Finserv, Perfios AA, Setu AA — **all need you to be an FIU** |

Nothing above should be integrated before the corpus in §8.2 exists, because
the corpus is what tells you which layer is worth paying for.

---

## 10. What was corrected, in one place

| Claim in the research | Status |
|---|---|
| The QR often has no `mc` and the acquirer decides | ✅ Confirmed — measured, 5 of 48 |
| Tag `9F15` from a POS tap, then decline | ✅ Confirmed and built |
| POS interrogation is *"mathematically absolute"* | ⚠️ Deterministic about what is sent; **`docs/47` is a terminal that sent zeros** |
| AA data *"frequently includes … the MCC"* | ❌ **The ReBIT deposit schema has no MCC field.** It is narration text when it appears at all |
| Register as an FIU, or partner with one | ❌ **Not possible — FIUs must be regulated entities.** SWIP is not |
| GST/HSN → MCC and Places → MCC | ✅ Buildable, and must be labelled a guess |
| ₹1 probe returns the MCC *(yours, not the document's)* | ❌ The category is never returned to the paying app |
