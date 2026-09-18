# 51 — Can converting a QR into a pay-by-app intent produce an MCC?

> *"can we translate these QR codes in such a way that they convert into
> pay-by-app intent? It's because, by using pay-by-app intent, it is getting
> the merchant category codes inside it properly detected … convert these QR
> codes into pay-by-intent and get the merchant category codes into it."*
> — prompt 55

**No — and the reason is worth five minutes, because the observation behind the
question is correct and points at something that does work.**

---

## 1. The one-line answer

**A UPI intent and a UPI QR are the same string in a different envelope.**
Converting one into the other cannot add a field that was not there, any more
than reading a letter aloud adds a sentence to it.

---

## 2. What the specification actually says

NPCI's **UPI Linking Specification** defines one URL format and lists the
carriers that may hold it. From the parameter table:

| Param | Meaning | Static | Dynamic |
|---|---|---|---|
| `pa` | Payee VPA | **M** | **M** |
| `pn` | Payee name | **M** | **M** |
| **`mc`** | **Payee merchant code** | **O** | **O** |
| `tr` | Transaction reference | O | C |
| `am` | Amount | O | **M** |
| `cu` | Currency | O | O |

Two things in that table settle the question.

**`mc` is optional — `O` — in both columns.** It is not required of a QR and it
is not required of an intent. Nothing anywhere obliges either to carry it.

**And the spec's own wording for `mc` is:**

> *"Payee merchant code **If present then needs to be passed as it is**"*

*Passed as it is.* The category is **forwarded, never generated.** That single
sentence is the whole answer: an intent is a courier, and a courier does not
write the letter.

**The carriers are interchangeable.** The specification treats *"QR, intent,
NFC, BLE, UHF"* as alternative ways of delivering one URI, with the same
encoding rules for all of them.

— [NPCI UPI Specifications for Deep Linking](https://github.com/bgagan911/RandomDocs/wiki/NPCI-UPI---Specifications-for-Deep-Linking)

### What this means in practice

The Paytm code from [`docs/46`](46-THE-CODE-YOU-SENT.md) is thirty-nine bytes:

```
upi://pay?pa=paytm.s27l8o9@pty&pn=Paytm
```

Fire that as an Android intent and it is still those thirty-nine bytes. SWIP
already does exactly this, every time *Continue payment* is pressed (`F-194`) —
**and it forwards the payload byte for byte on purpose**, because rebuilding it
would destroy the `sign=` block. There is no step in that path where a category
could appear.

---

## 3. So why does the intent vector seem to find categories?

**Because it does — and not because it is an intent.**

The observation is real. Intents that reach SWIP in the wild come from **online
checkouts**: a shopping app or a web checkout firing `upi://pay?…` through a
payment aggregator's SDK. Those payloads carry `mc` far more often than a
printed sticker does.

The cause is not the transport. It is **who minted the payload** — which is the
finding [`docs/42`](42-MARKET-QR-CORPUS.md) already measured from the other
side:

> Every Google Pay for Business code publishes `mc`. **Not one** Paytm, PhonePe
> or BharatPe code does. Five of forty-eight overall.

An online aggregator onboards a merchant with documents and a category, so the
category is in the string it builds. A sticker printed for a shop that signed up
on a phone in four minutes has a payee address and nothing else.

**Same rule, both sides: the acquirer decides.** Not the shop, not SWIP, and not
the envelope the string travels in.

### One sentence in SWIP was making this worse

The app's own guidance used to say:

> *"When a checkout hands the payment over, the category usually travels with
> it."*

True, and *"usually"* was carrying more weight than it could hold. `F-198`
rewrote it:

> *"An online checkout usually puts the category in the payment it hands over.
> A sticker on a counter usually does not."*

---

## 4. What does work, and it is now built

The question underneath the ask is *"get the MCC for a shop whose sticker does
not carry one."* That has an answer, and it was hiding in this project's own
market data.

**A shop with two stickers very often has the category on one of them.** Google
Pay for Business codes publish `mc`; the Paytm code taped beside it does not.
Both are on the same counter. The answer is a foot away from the code that was
scanned.

SWIP already had the machinery — `MerchantReconciler` proposes a link when two
captures share a place and a visit, and the user confirms. But it carried this
rule:

> *"Different identity spaces — one `emv:`, one `upi:`. Two QRs in one cell are
> two shops in a market; a tap and a QR are one counter."*

**That rule refused the exact case this question is about.** It is right for two
codes from the *same* payment company — a row of Paytm stickers down a street is
a row of different shops. It is wrong for a Google Pay code and a Paytm code
ninety seconds apart at one till.

### `F-198` — what changed

Two `upi:` captures can now teach each other, under two guards:

1. **Different acquirers.** A shop does not print two stickers from one PSP;
   two neighbours do. `acquirer` is read off the payload by
   `MerchantIdentifier`, so this is a fact about the code rather than a
   similarity score. **An unknown acquirer on either side refuses the link** —
   *"I do not know who issued this"* is the one state in which *they are
   different* must not be assumed.
2. **Three minutes, not twenty.** The long window exists for a sequence with a
   human in it: a tap that failed, a word with the cashier, then the QR.
   Reading the second code on a board is a deliberate act taken seconds after
   being told to.

Everything else is unchanged — same 1 km cell, exactly one side carrying a
category, and **the user confirms**. That last guard is the one carrying the
weight: the person was standing at the counter looking at both stickers.

And the app now says so when it finds nothing. A new route, second on the list
of what to try:

> **Look for the shop's other code** — *Google Pay stickers carry the category
> and Paytm, PhonePe and BharatPe ones do not. Scan the other code on the
> counter and SWIP will offer to join them.*

It sits second because it is **the only route on that list that needs nothing
from anybody.** A tap needs their terminal. A dynamic QR needs the cashier to
ring it up. A statement needs a payment first. This needs a second scan.

---

## 5. The honest ledger

| Claim | Verdict |
|---|---|
| A pay-by-app intent detects MCCs that a QR does not | ❌ Same string, same fields. `mc` is optional in both and *"passed as it is"* |
| Converting a scanned QR into an intent yields a category | ❌ Nothing in that path can write one |
| Intents in the wild carry MCCs more often | ✅ **True** — because online aggregators onboard merchants properly. The acquirer decides, not the envelope |
| The category for a sticker-only shop is unreachable | ❌ **Often it is on the next sticker.** `F-198` |

---

## 6. Where this sits against the other routes

[`docs/49`](49-EVERY-ROUTE-TO-AN-MCC.md) priced five routes. This is not a sixth
— it is route A getting better at its own job, for free:

* **A — read it from the QR.** Now reads it from *the shop's other QR* too,
  with a confirmation.
* **B — read it from the terminal.** Unchanged, and still the one that needs a
  corpus.
* **C — the ₹1 probe.** Still closed. The category is never returned to the
  paying app.
* **D — the Account Aggregator.** Still blocked; SWIP is not a regulated entity.
* **E — a wallet.** Still ₹5 crore.
* **F — infer it.** Unchanged, and still must be visibly a guess.

**The number that decides everything here is still uncounted**, and it is the
same one: how many terminals publish `9F15`. Twenty taps answers it.
