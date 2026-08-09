# Capturing the "Pay by app" flow, and the Paris phone-to-phone question

> Two things you asked about. One is buildable and is probably the **single
> highest-value feature left in v1**. The other is real but not available in
> India yet, and I explain exactly why.

---

## Part 1 — "Pay via app" on PVR, Swiggy, IRCTC, anywhere

### 1.1 What actually happens when you tap "Pay by any UPI app"

You described it precisely: book a ticket → checkout → *"Pay by UPI"* → a
bottom sheet appears listing GPay, PhonePe, Paytm.

Here is the mechanism, and it is better news than you expected.

**[NPCI mandates that every merchant show a "Pay by any UPI App" option on
Android](https://docs.payu.in/docs/upi-smart-intent-non-sdk-flow).** To do that,
the merchant app fires an **implicit Android intent** — it does not name a
specific app. It broadcasts, in effect: *"whoever can handle this, put your hand
up."* Android collects everyone who can, and that list **is** the bottom sheet.

The intent it fires looks like this:

```
upi://pay?pa=pvrcinemas@hdfcbank
        &pn=PVR%20Cinemas
        &mc=7832            ←  THE MERCHANT CATEGORY CODE
        &am=850.00
        &cu=INR
        &tr=PVR123456789
```

**`mc=7832` is the MCC.** `7832` is Motion Picture Theatres.

**It is already in the intent, before you pay.** Same `mc` parameter SWIP
already reads from UPI QR codes — the identical field, arriving through a
different door.

### 1.2 The design: capture and forward

SWIP does **not** need to become a payment app. It needs to be one of the hands
that goes up — read the category, then pass you straight through to the app you
actually pay with.

```
  PVR checkout
       │  fires implicit intent  upi://pay?...&mc=7832...
       ▼
  ┌──────────── Android chooser ─────────────┐
  │  GPay    PhonePe    Paytm    ● SWIP      │  ← SWIP appears here
  └──────────────────────────────────────────┘
       │  you pick SWIP
       ▼
  SWIP reads mc=7832  →  "Motion Picture Theatres"
       │                  saved to the ledger, ~200 ms
       ▼
  ┌── "Pay with" ────────────────────────────┐
  │  GPay    PhonePe    Paytm                │  ← SWIP hands the SAME intent on
  └──────────────────────────────────────────┘
       │
       ▼
  You pay exactly as normal. SWIP never touches the money.
```

**SWIP is a pane of glass you look through on the way to paying.** It reads the
label and steps aside. It never holds funds, never needs a PSP licence, never
becomes an NPCI-registered UPI app.

### 1.3 Why this is the best vector in the product

| Vector | Requires | Coverage |
|---|---|---|
| Scan QR | Pointing a camera at a printed code | Only where a QR exists |
| Tap POS | Physical terminal, Android, an unverified `9F15` | Card-present only |
| Payment link | Inference — never certain | Weak |
| **Pay-by-app intent** | **One tap, in flows you already use** | **Every online UPI checkout in India** |

It is the only vector where the MCC is **guaranteed present and exact**, arrives
**before** you pay, and needs **no extra behaviour** from you beyond picking SWIP
once instead of GPay.

`mc` is mandatory for merchant UPI collections, so this is not a hit-and-miss
vector like the POS tap. **If the sheet appears, the code is in it.**

### 1.4 The honest limits

I will not oversell this — three real gaps:

| Limit | Effect | Mitigation |
|---|---|---|
| Some merchants fire **explicit** intents naming GPay/PhonePe directly instead of showing a chooser | SWIP never appears | Nothing we can do. Affected apps are a minority because NPCI mandates the "any UPI app" option |
| **[UPI Smart Intent](https://www.paytmpayments.com/docs/upi-smart-intent)** lets merchants show only PSP apps that signalled UPI-readiness | SWIP may be filtered out of optimised sheets | SWIP still appears in the standard chooser. Needs field testing |
| **Card** checkouts have no equivalent intent | No capture | Covered by the merchant graph — see §1.6 |

**Field test, week 1:** open PVR, Swiggy, BookMyShow, IRCTC, Zomato, Amazon,
Flipkart, Uber. Reach the UPI sheet in each. **Count how many show SWIP.** That
number decides how good this feature is, exactly like the 50-terminal test
decides the POS tap.

### 1.5 Play Store and NPCI — how to stay clean

This is where care is needed. SWIP will sit in a list beside real payment apps.

**Non-negotiable rules:**

1. **Never render a payment UI.** No amount entry, no "Pay ₹850" button, no PIN
   screen, nothing resembling a transaction.
2. **State it on the screen itself:** *"SWIP does not make payments. It reads
   the category and hands you to your UPI app."*
3. **Forward within ~1 second.** A capture screen you have to dismiss will feel
   like an interception.
4. **Show it in the chooser label** — "SWIP · read category" rather than a name
   that could be mistaken for a wallet.
5. **Declare it in Play review notes** exactly as in
   [13-PLAY-STORE-LAUNCH §9.2](13-PLAY-STORE-LAUNCH.md).

> ⚠️ **The risk, stated plainly.** Registering for `upi://` puts SWIP in the same
> list as GPay. A reviewer could read that as impersonating a payment app. The
> defence is that SWIP is transparently a pass-through and says so on screen.
> **Get this in front of Play review early** — as its own small release, not
> bundled with everything else, so a rejection costs one feature and not a
> launch.

### 1.6 Card checkouts

When you pick **Credit card** instead of UPI, there is no intent and no MCC.
Nothing to capture at the moment of payment.

But the merchant is the same. If SWIP has ever seen `pvrcinemas@hdfcbank` — by
QR, by intent, or from another user's capture — the **merchant graph** already
knows PVR is `7832`, and answers from memory. That is what the graph is for, and
every intent capture makes it stronger.

---

## Part 2 — Geolocation

Yes, and it is cheap. **Where** a code was captured is genuinely useful: it
separates the Powai Blue Tokai from the Bandra one, and it makes the ledger feel
like a memory rather than a list.

**Design principles:**

- **Coarse by default.** ~100 m is enough to name a place; exact coordinates are
  more than we need and more than we should hold.
- **Ask at the second capture, not the first.** A location prompt on first run
  gets denied. Ask once there is a ledger worth pinning.
- **Never block a capture on it.** No location = the capture still saves.
- **Subtle in the UI**, as you said: a small place name on the row, the map only
  inside the detail screen.
- **Stays on the device**, like everything else, and appears in the export.

Schema is ready for it — `captures` gains `lat`, `lon`, `accuracy_m`,
`place_label`.

---

## Part 3 — Ledger: source badges and filters

Every capture already records its **vector**. What is missing is showing it
clearly and letting you filter.

| Badge | Meaning |
|---|---|
| `QR` | Scanned a merchant QR |
| `POS` | Tapped a card terminal over NFC |
| **`APP`** | **Captured from a "pay by app" intent — new** |
| `LINK` | Inferred from a payment link |
| `KNOWN` | Answered from the merchant graph |
| `YOU` | You told us |

Filters become chips across the top: **All · QR · POS · App · Link**, plus
confidence (Verified / Likely / Unknown) and a date range.

---

## Part 4 — The Paris photographer

### 4.1 What actually happened to you

Simple version, no jargon:

**His iPhone was the card machine.**

That is the whole trick. There was no card machine, because his phone *was* one.
You held your phone (or card) near his, your card details went across by NFC —
the same way they would to a shop terminal — and the payment went to his bank.

The feature is called **[Tap to Pay on
iPhone](https://developer.apple.com/tap-to-pay/)**. Apple lets an iPhone act as
a payment terminal, with no extra hardware. Photographers, market stalls and
taxi drivers use it because it costs nothing to own.

So the roles were:

| | |
|---|---|
| **You** | The card — your phone carried your card |
| **Him** | The shop — his phone acted as the till |

Nothing exotic. He just had the till in his pocket.

### 4.2 Can you do this in India today?

**No. Not with an iPhone.** Here is the current position, and it is changing.

| | Status in India, August 2026 |
|---|---|
| Adding an Indian card to Apple Wallet | ❌ Not supported |
| Accepting payments on an iPhone (Tap to Pay) | ❌ Not available |
| **Apple Pay in India** | ⏳ **Expected end-2026**, pending RBI approval ([Asianet](https://newsable.asianetnews.com/gallery/technology/apple-pay-india-launch-expected-by-mid-2026-with-upi-f6goscq)) |
| Accepting card payments on an **Android** phone | ✅ **Yes — "Tap to Phone" / SoftPOS**, via acquirers |

Apple is [in advanced talks with HDFC, ICICI and
Axis](https://techgenyz.com/apple-pay-india-launch-mobile-payments/), with card
payments first and UPI possibly later.

**But the Android equivalent already works here.** Visa Tap to Phone and
Mastercard Tap on Phone let an ordinary Android phone accept contactless cards.
That is the same experience you had in Paris, with the roles on Android.

### 4.3 How the money actually moves — the full chain

You asked for this at the most basic level. Here it is with nothing skipped.

**The cast:**

| Who | What they do |
|---|---|
| **You** | Paying |
| **Your bank** (issuer) | Gave you the card. Holds your money |
| **The photographer** | Being paid |
| **His bank** (acquirer) | Gave him the ability to accept cards |
| **Visa / Mastercard** | The road between the two banks |

**The steps, in order:**

1. **Tap.** Your phone and his phone talk over NFC — a radio that only works at
   about 4 cm. Your card number goes across, but as a **token**: a stand-in
   number useless to anyone else.
2. **Ask.** His phone sends the request to his bank: *"This card wants to pay
   €200. Allowed?"*
3. **Route.** His bank passes it to Visa, which finds your bank.
4. **Decide.** Your bank checks: is the card real, is there money, does this look
   like fraud? It says yes or no in about a second.
5. **Hold.** On yes, your bank *reserves* €200. Not yet moved — set aside.
6. **Settle.** That night, all the day's transactions are batched. Real money
   moves from your bank to his, minus a fee (**the MDR** — usually 1–2%). He
   receives roughly €197.
7. **Bill.** The €200 appears on your statement.

**Where SWIP fits:** at step 2, that request carries the **merchant category
code**. That single field is the entire reason this product exists.

**Cross-currency**, since you paid in Paris on an Indian card:

- The photographer was charged in **euros**. Your card is in **rupees**.
- At step 4 your bank converts at the network's rate that day.
- It adds a **foreign currency markup**, typically 1.5–3.5% — and *this is
  exactly the number a good travel card reduces to 0%*.
- Some terminals offer to charge you in rupees instead ("Dynamic Currency
  Conversion"). **Always decline.** The merchant's rate is worse than your
  bank's, every time.

### 4.4 Should SWIP do this?

**Not in v1, and the reason is structural rather than technical.**

Accepting card payments means becoming a payment acceptor. That requires:

- an **acquiring partner** (a bank or a licensed PA),
- **PCI MPoC** certification for the software,
- RBI's payment-aggregator rules if you touch settlement,
- fraud liability — you are now on the hook for chargebacks.

That is a different company from the one that shows you a category code. It is
the same jump as the Probe card in
[16-V2-PRD §3](16-V2-PRD.md), and it needs the same partner.

**But note what it would give you, because it is not nothing:** if SWIP were the
acceptance app, SWIP would *see the whole authorisation* — MCC included — for
every payment taken through it. That is the strongest possible version of the
merchant graph. **It belongs on the v3 roadmap, not the discard pile.**

---

## Part 5 — Build order

| Priority | Feature | Effort | Why |
|---|---|---|---|
| **1** | **UPI intent capture** | ~1 day | Highest-value vector in the product. Exact MCC, no hardware, no licence |
| 2 | Ledger badges + filters | ~half day | Needed the moment there are two vectors |
| 3 | Geolocation | ~1 day | Cheap, and makes the ledger feel alive |
| 4 | NFC Dart bridge | ~2 days | The Kotlin service exists but is unreachable |
| 5 | Tap to Phone | v3 | Needs an acquiring partner |

---

## What to test yourself this week

1. **Open PVR, BookMyShow, Swiggy, IRCTC, Amazon.** Reach the UPI payment sheet.
   **Count how many show a chooser rather than only GPay/PhonePe/Paytm.** That
   number is the ceiling on §1.
2. Note any that jump straight into one app — those are the explicit-intent
   cases SWIP cannot reach.

That is a 20-minute experiment and it tells us more than another week of
research.
