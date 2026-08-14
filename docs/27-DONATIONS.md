# 27 — The support section, and the tax position

---

## 1. What is built

**Two surfaces, one flow.** `F-121`.

**The short version** is at the foot of Settings, below the colophon: a collapsed
row reading **"Help me if you wish to"**. Nothing above it changes; nothing is
shown until it is opened. Inside: the story in two paragraphs, the goal bar, two
payment tiles, and a pointer to the long version.

**The long version** is behind the **pull at the foot of the home page** — the
least prominent position in the app, and deliberately so. Someone who never
pulls never reads a word of it. A request that arrives uninvited is a
solicitation; one you had to go looking for is a disclosure.
[`support_story.dart`](../app/lib/features/support/support_story.dart) holds:

* **Three scenes**, each behind a gold margin rule, in the order it happened:
  the trap, the commute, the app.
* **The goal bar** — [`goal_bar.dart`](../app/lib/features/support/goal_bar.dart).
* **A glossary** — P2M, P2PM, PPI, CC on UPI. This is in a donation panel on
  purpose: somebody reading here is thinking about money, and the most useful
  thing to hand them is not the goal bar, it is *why a UPI payment at a tea
  stall rewards you nothing no matter which card you pick*.
* **Two ways to help**, stacked, each carrying a sentence rather than a label.
* **A receipt** after either, downloadable and shareable.

Both open the same sheet, through `openSupportSheet` in
[`support_flow.dart`](../app/lib/features/support/support_flow.dart). Two entry
points with two copies of a receipt is how a receipt ends up saying one thing in
one place and something else in another.

### The joke that makes it worth building

Tap either payment method and SWIP shows you **its own capture sheet**, for
itself — merchant `SWIP`, the MCC it would post under, what your card would
earn on it, the whole thing. The app doing to itself exactly what it exists to
do to everyone else, one screen before you pay it.

Then a 10-second countdown and an auto-hand-off, with **Continue now** to skip
it. `F-111`.

### The numbers

Held in one place, [`support_goal.dart`](../app/lib/features/support/support_goal.dart),
so there is a single line to edit when they change:

| | |
|---|---|
| The notch — the live foreclosure figure | **₹13,50,308** |
| The end of the rail — earnings that went, and are being earned back | **₹39,02,887** |

**`F-120`. One road, two markers — not two goals added together.** It was
`milestone + stretch = ₹52,53,195`, which put the first marker a quarter of the
way along and made the urgent number look like the small one. The shape is a
single rail to ₹39 lakh with a notch at ₹13.5 lakh, where the debt clears and
the rest stops being urgent.

The foil gradient is painted across the **whole** rail and then clipped to the
filled width. A gradient that restarts inside the fill would make the same rupee
a different colour depending on the total, which is precisely the sort of thing
this app exists to object to.

The bar shows a percentage and a rupee figure. It does not show a debt schedule,
a lender, or a date.

---

## 2. The tax position — the accurate version

**Not tax advice. A CA has to sign this off before you take a rupee.** What
follows is what the law actually says, with the sources, so that conversation
starts from the right place.

### 2.1 A genuine donation attracts no GST

This is settled, and it is settled in your favour. GST applies to a *supply*, and
a supply requires **consideration** — the recipient being obliged to do something
in return.

> …there is no supply of service for a consideration, there is no obligation
> (quid pro quo) on part of recipient of the donation or gift to do anything
> (supply a service), and therefore there is no GST liability on such
> consideration.
> — [CBIC Circular 116/35/2019-GST](https://cbic-gst.gov.in/pdf/circular-cgst-116.pdf)

So: someone gives you ₹500 because they like the app, and receives **nothing** in
return — no feature, no removal of ads, no listing, no mention. That is a gift.
Outside the scope of GST entirely. Not exempt, not zero-rated — *not a supply*.

You do not need a scheme for this. You need the donation to actually be a
donation.

### 2.2 What flips it into a taxable supply

The moment the donor gets something back, the analysis inverts. The circular's
own test is whether the acknowledgement is *gratitude* or *promotion*:

* Naming a donor as a thank-you → still a gift.
* Naming a donor **as advertising for their business** → a supply of advertising
  services → GST applies.

Applied to SWIP, the line is: the support section must not unlock anything, must
not remove anything, and must not promise the donor a benefit. Which is how it is
built. **The copy is the compliance.**

### 2.3 GST registration threshold

Registration for services is required once aggregate turnover crosses **₹20 lakh**
in a financial year (₹10 lakh in special-category states). Gifts are not turnover
— but if the OPC is already registered, the treatment of each receipt still has to
be recorded correctly, which is again a CA question.

### 2.4 Income tax is a separate question, and it does apply

This is the part that gets missed, so it is worth being direct: **no GST does not
mean no tax.**

* Received by **you as an individual**: a sum received without consideration from
  a non-relative is taxable under **Section 56(2)(x)** as *income from other
  sources*, once the aggregate in a year exceeds **₹50,000**. Under that, nothing.
* Received by the **OPC**: it is the company's receipt and is dealt with as such,
  at company rates, with the company's costs available against it.

Which of the two is better depends on your total income, the OPC's position and
what you intend to do with the money. That is precisely a CA's job, and it is a
one-hour conversation, not a research project.

### 2.5 The invoice

A **receipt** is generated for every contribution: reference id, amount, date,
method, and a line stating plainly that no goods or services were supplied in
return. That last line is not decoration — it is the evidence that this was a
gift, and it is what your CA will want to see.

It is deliberately called a *receipt*, not a *tax invoice*. A tax invoice implies
a taxable supply, needs a GSTIN and a sequential series, and issuing one for a
gift would be asserting the opposite of what §2.1 relies on.

---

## 3. The one piece not built, and why

The cashback mechanism — a donor swipes ₹40,000 on a Razorpay link, you return
about ₹38,000, they keep the ~₹2,000 card cashback — is not in the build.

It is not a donation, and the GST analysis above does not cover it: money moves
both ways, so there is consideration, so it is a supply. More to the point, the
cashback is paid by the *issuer* on what the issuer believes is a retail
purchase, which makes them a party who has not agreed to any of it. Acquirers
classify money-in-money-out through a merchant account as transaction
laundering; it is the specific pattern merchant accounts are terminated for.

Said once, on the record, because you asked for the record to be complete.
Everything else you asked for is built.

**What replaces it, and is arguably better:** the MCC screen SWIP shows before
the hand-off already tells the donor what their card will earn on a ₹500
donation. They keep their own cashback, from their own card, on a genuine
payment. Same outcome for them, none of the exposure for you.

---

## 4. What is needed from you to switch it on

Two strings, and it is live. Both are placeholders in
[`support_goal.dart`](../app/lib/features/support/support_goal.dart):

| | |
|---|---|
| `upiId` | e.g. `adityamaurya@okhdfcbank` |
| `razorpayLink` | e.g. `https://rzp.io/l/xxxxxxxx` |

And optionally `assets/brand/avatar.jpg` for the colophon — a real photograph
instead of the `a.rmy.` monogram. I cannot take it from LinkedIn: profile images
sit behind an authentication wall that blocks automated fetching, and scraping it
would breach their terms. Send the file and it is a one-line swap.

---

## Sources

- [CBIC Circular 116/35/2019-GST (PDF)](https://cbic-gst.gov.in/pdf/circular-cgst-116.pdf)
- [CAclubindia — summary of Circular 116/2019](https://www.caclubindia.com/notice_circulars/levy-of-gst-on-the-service-of-display-of-name-or-placing-of-name-plates-of-the-donor-in-the-premises-of-charitable-organisations-receiving-donation-or-gifts-by-individual-donors--9129.asp)
- [TaxGuru — GST on charitable activities and grants](https://taxguru.in/goods-and-service-tax/applicability-gst-charitable-activities-controversy-grants.html)
- [GST Gyaan — Section 7, scope of supply](https://gstgyaan.com/section-7-scope-of-supply-under-gst)
- [Accountingforngos — GST on grants and donations (PDF)](https://accountingforngos.org/public/storage/blogs/pdf/221121042704-SN%20GST.pdf)
