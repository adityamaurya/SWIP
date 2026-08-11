# 24 — The card and netbanking problem

> *"that is where people are unable to figure out the MCC when there is no UPI
> or POS terminal to tap, and they are doing payment from these two methods, we
> need to crack this man"*
> — prompt 27

This is the honest answer, including the parts that are "no".

---

## 1. Where the MCC actually travels

The MCC is not a property of a payment page. It is a **field in the
authorization message**, and it is written by the merchant's acquirer.

```
   merchant ──▶ payment gateway ──▶ ACQUIRER ──▶ card network ──▶ ISSUER
                                       │                            │
                                 writes the MCC              reads the MCC,
                                                        decides rewards & limits
```

Two parties see it: the **acquirer** who sets it, and the **issuer** who acts on
it. Everyone else — including the person actually paying — is outside the
message.

That is the whole difficulty in one sentence, and it explains why the three
routes that *do* work in SWIP work:

| Route | Why it can see the MCC |
|---|---|
| `QR SCAN` | The merchant **publishes** it in the QR — EMVCo tag `52`, or UPI `mc` |
| `POS TAP` | The **terminal** hands it over when asked — EMV tag `9F15` |
| `APP DIRECT` | The merchant's own intent carries `mc=` before payment |

In all three the merchant is *volunteering* the code before the money moves. In
a card or netbanking checkout, nobody volunteers anything.

---

## 2. Card payments: the MCC is right there, and you still cannot reach it

Here is the frustrating part. In EMV 3-D Secure — the OTP step you go through
on every Indian card payment — the authentication request (**AReq**) carries a
field literally named `mcc`:

> The `mcc` field is defined as a Merchant Category Code, String, 4 characters,
> part of the merchant object in the AReq. It is **required when
> `messageCategory` is `01`** (payment authentication), and the Directory
> Server validates it — an invalid MCC is rejected with its own error.
> — [3DSecure.io, EMV 3DS 2.2.0 specification](https://docs.3dsecure.io/3dsv2/specification_220.html)

So during the exact moment you are staring at the OTP screen, your category
**is being transmitted**. Just not to you:

```
merchant's 3DS Server ──AReq(mcc)──▶ Directory Server ──▶ ACS (your bank)
                                                            │
                                              renders the OTP page you see
```

The AReq is server-to-server. What reaches your phone is the **ACS challenge
page**: an issuer-hosted form showing merchant name, amount and card last-4.
The `CReq` your browser posts back contains only transaction IDs and a window
size. **The MCC is in the conversation happening around you, not in the page in
front of you.**

There is no permission, no API and no parsing trick that changes this. An app
that is not the acquirer and not the issuer is not a party to the message.

---

## 3. Netbanking: there is no MCC to find

This one has a cleaner answer than expected, and it is worth stating plainly
because it changes the advice rather than the engineering.

**A netbanking payment is not a card transaction.** It is a debit from your
bank account, routed by an aggregator (BillDesk, Razorpay, PayU) to the
merchant. No card network is involved, so:

* there is **no authorization message**, therefore no MCC field;
* there is **no card**, therefore no card rewards — accelerated *or* base;
* your statement shows the **aggregator**, not the shop.

Where an MCC does appear on aggregated rails, it is usually the aggregator's
own, not the merchant's:

> When using third-party platforms like wallets or payment gateways, the MCC
> often reflects the aggregator, not the merchant, which could result in
> missing out on accelerated rewards.
> — [Open Money, MCC list for India](https://open.money/blog/merchant-category-code-list-in-india/)

So the correct SWIP feature for netbanking is **not** a capture. It is a
warning, delivered before the tap:

> **Netbanking earns nothing.** This is a bank transfer, not a card payment —
> there is no category and no reward. If this shop takes a card or a UPI QR,
> that is where your points are.

That is a better product than any amount of cleverness, because it changes the
decision while the decision is still open. It is `F-99` below.

---

## 4. The "dummy details that fail" idea — assessed properly

The proposal:

> *put dummy bank/card details in, it fails, and the declined info gets
> captured via cloud or someway and becomes visible on SW/P*

**As stated, it cannot work, for a specific reason.** A decline is only visible
to the parties in the authorization — and the MCC-bearing decline is delivered
to the **issuer of the card that was used**. With a made-up card number there is
no issuer: the gateway rejects it on a Luhn check or the network returns
"invalid card" long before any issuer has an opinion, and there is no one to
notify SWIP because SWIP is nobody's issuer.

There is also a real cost to trying: repeated failed authorizations against a
merchant raise their decline ratio, trip acquirer fraud rules, and are the kind
of traffic that gets cards blocked and merchants fined. It is not a neutral
probe.

**But the instinct behind it is exactly right**, and there is a version that
works — the one corporate card platforms already run:

> Real-time enforcement means the MCC check happens during authorization; the
> issuer evaluates the card's rules in the moment, declines anything out of
> policy, and **can fire a notification to the cardholder at the same time**.
> — [Corpay, Merchant Category Codes explained](https://www.corpay.com/resources/blog/merchant-category-codes)

Read that again with SWIP in mind. The platform knows the MCC *at the moment of
the decline* because **it is the issuer**. That is the whole trick, and it is
not a trick — it is a licence.

### Vector 4, properly stated

Issue a real SWIP virtual card, through a BIN sponsor / issuer partner, with a
policy of **decline everything**. The user enters it at any checkout. The
authorization travels the normal path, arrives at SWIP-as-issuer carrying
`mcc`, SWIP reads it, declines, and shows you the category — **before** you pay
with your real card.

* It works on **any card checkout on earth**, no merchant cooperation.
* It is a legitimate, non-abusive authorization: a real card, honestly declined
  by its own issuer under its own policy.
* It is the only route that gets the MCC **before** the money moves.

The cost is honest too: it needs an issuing partner, a BIN, KYC, and a
compliance posture SWIP does not have today. This is a company decision, not a
sprint. The empty `lib/features/virtualcard/` directory in this repo is where it
was already anticipated.

---

## 5. What can be built now, without a licence

Ranked by value per unit of work.

### `F-99` — Warn before a rewardless rail *(small, high value)*

Detect that the user is about to pay by netbanking or a wallet top-up and say
what it costs them. No capture, no permission, no network call. Pure copy in
front of a decision.

### `F-100` — Descriptor → MCC from the graph *(medium, high value)*

The one thing a card checkout **does** show you is the **merchant descriptor** —
the name the acquirer registered, which is also the name that lands on your
statement. That string is a join key.

```
statement line   →   descriptor "CULINARY BRANDS INDIA"  →  MCC 5499
card checkout    →   descriptor "CULINARY BRANDS INDIA"  →  answer, instantly
```

SWIP already does exactly this for UPI handles: `F-50` reads
`…/paytm.s233ffl@pty/…/5451` off a statement and keys it to the VPA. The card
version is the same mechanism with a fuzzier key — descriptors vary in casing,
truncation and suffixes, so it needs normalisation and a confidence floor, but
it is the same idea and it reuses `merchant_alias` unchanged.

**This is the highest-value thing available without becoming an issuer**, and it
turns every statement a user shares into permanent knowledge about card
merchants, not just UPI ones.

### `F-101` — Read the category out of the issuer's own app *(medium)*

> Leading Indian applications like Axis Mobile, HDFC PayZapp and ICICI iMobile
> often display transaction lists grouped by spending category, which are
> derived from the underlying MCC.
> — [SaveSage, how merchant categories affect rewards](https://savesage.club/blogs/how-merchant-categories-affect-your-credit-card-rewards-in-india)

Same share-a-screenshot route as `F-50`, aimed at the card statement rather than
the account statement. Post-hoc, but it feeds `F-100` for ever after.

### What is deliberately **not** proposed

* **Accessibility service / notification listener** to scrape OTP SMS or the
  checkout page. It would work. It also requires the most invasive permission
  Android has, would be read as spyware, and is a Play Store policy fight SWIP
  should not pick for a category code.
* **Screen-reading the ACS page.** Same objection, plus the MCC is not on it.
* **Asking the PSP.** Razorpay, PayU and BillDesk expose the MCC to the
  *merchant*, never to the payer.

---

## 6. The honest summary

| Question | Answer |
|---|---|
| Is the MCC present during a card payment? | **Yes** — in the 3DS AReq, required field |
| Can SWIP see it from the phone? | **No.** Server-to-server, acquirer to issuer |
| Can the OTP page be read for it? | **No.** It shows merchant, amount, last-4 |
| Is there an MCC for netbanking? | **No.** Not a card transaction at all |
| Do netbanking payments earn card rewards? | **No** — which is the useful thing to say |
| Does the "dummy details" trick work? | **No**, and it has a real cost |
| Is there a version that works? | **Yes** — SWIP issues the card and reads its own declines |
| Anything good available today? | **Yes** — `F-100`, descriptor matching from statements |

The short version: **for cards, SWIP has to be the issuer to see it live, or the
merchant has to have been seen before.** The second is buildable this week. The
first is a company.

---

## Sources

- [3DSecure.io — EMV 3DS 2.2.0 specification](https://docs.3dsecure.io/3dsv2/specification_220.html)
- [3DSecure.io — EMV 3DS 2.1.0 specification](https://docs.3dsecure.io/3dsv2/specification_210.html)
- [US Payments Forum — EMV 3-D Secure white paper (PDF)](https://www.uspaymentsforum.org/wp-content/uploads/2020/03/EMV-3DS-WP-FINAL-March-2020.pdf)
- [Elavon — 3D Secure 2 concepts](https://developer.elavon.com/products/3dsecure2/v1/3ds2-concepts)
- [Corpay — Merchant Category Codes explained](https://www.corpay.com/resources/blog/merchant-category-codes)
- [Open Money — MCC list for India](https://open.money/blog/merchant-category-code-list-in-india/)
- [SaveSage — How merchant categories affect your credit card rewards in India](https://savesage.club/blogs/how-merchant-categories-affect-your-credit-card-rewards-in-india)
- [Wikipedia — Merchant category code (ISO 18245)](https://en.wikipedia.org/wiki/Merchant_category_code)
