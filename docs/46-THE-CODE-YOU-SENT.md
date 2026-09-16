# 46 — The code you sent, decoded

> *"I am sharing the QR code which couldn't get the MCC man, why is this
> happening how can we get the MCC… please find the working for these QRs
> otherwise the whole app idea will fail"* — prompt 50

This page is short on purpose. It is one photograph, one answer, and the two
things that answer changes.

---

## 1. Here is everything inside that QR

Your photograph, decoded. Not summarised — **this is the file, in full**:

```
upi://pay?pa=paytm.s27l8o9@pty&pn=Paytm
```

**Thirty-nine bytes. Two fields.**

| Field | Value | What it is |
|---|---|---|
| `pa` | `paytm.s27l8o9@pty` | Where the money goes |
| `pn` | `Paytm` | A name — and it is Paytm's, not the shop's |

That is the entire contents. There is no `mc`. There is no merchant ID, no
terminal ID, no signature, no city, no amount. **Nothing was missed, nothing
failed to parse, and there is nothing hidden further in** — the QR is 39 bytes
long and you have just read all of them.

### And SWIP had already read it

That exact code is **entry 6 in the market corpus** —
[`42-MARKET-QR-CORPUS.md`](42-MARKET-QR-CORPUS.md), page 6 of the 52-page PDF
you sent two rounds ago, recorded as `mc: null`, `signed: false`. I decoded
today's photograph with a different image, in a different session, and got a
byte-identical result.

So this is not a code SWIP is failing on. It is a code SWIP has read correctly
twice, and both times the honest answer was *there is no category in here*.

---

## 2. Why the app said "A real shop, no category published"

Because that is exactly what it is.

Look at what the app told you in that screenshot, and notice how much of it is
true and useful:

* **"A real shop"** — SWIP knows this is a genuine business and not a person,
  from the `@pty` handle. Paytm only issues those after full merchant
  onboarding.
* **"RuPay credit card should work here"** — a real, actionable answer about
  the card in your pocket, from the same evidence.
* **"no category published"** — the shop has an MCC. Its bank knows it. It is
  not written on the sticker.

**The only thing missing is the one thing that is not in the bytes.** Nine of
every ten codes in your own market walk were like this
([`42`](42-MARKET-QR-CORPUS.md): 5 of 48 carry a usable category), and the
pattern there was the finding: **the acquirer decides.** Every Google Pay for
Business code publishes `mc`. Not one Paytm, PhonePe or BharatPe code does.

---

## 3. Razorpay has nothing to do with this, and that is the confusion

> *"the razorpay thing is not working i guess if the mcc is not getting
> detected"*

These are two separate things, and it is worth pulling them apart because the
disappointment is landing in the wrong place.

| | What it gives you | Does it give an MCC? |
|---|---|---|
| **The QR** | Whatever the acquirer printed | Sometimes. About 1 in 10 |
| **Razorpay lookup** | The **shop's name** for a payment address | **Never** |
| **Tapping their card machine** | The category, from the terminal | **Yes, when the terminal answers** |

**Razorpay was never going to produce a category.**
[`43` §7](43-RAZORPAY-IN-PLAIN-WORDS.md) says this outright and it is worth
repeating here because it is the single most expensive misunderstanding
available: the key turns `paytm.s27l8o9@pty` into something like *SHRI BALAJI
STORES*. It does not and cannot return `5411`. No commercial API does — the MCC
lives in the acquirer's switch ([`41`](41-RAZORPAY-EXPLAINED.md)).

So "Razorpay is not working" and "the MCC is not detected" cannot be the same
fault, because a working Razorpay key would not have changed that screen's
headline at all. **It would have changed the word *Paytm* into the shop's
name** — which is a real improvement, and a different one.

If the name is also not appearing, that is its own question and it has its own
answer: Settings → Merchant names, paste the key, press **Test the key**, and
read what comes back. Your earlier screenshot showed that button already
answering *"The key works."*

---

## 4. So how do you get the MCC for this shop?

**You tap their card machine.** That is not a consolation prize — it is the
other half of SWIP and the reason `Tap POS` exists.

The category is a fact the **terminal** holds and the **sticker** does not. A
Paytm QR is a payment address printed on plastic; a POS terminal is a device
that runs an EMV conversation and has the merchant's category in it. That is
why the app's own subtitle on that screen is *"Tap their card machine to find
it"* — it is the correct next step, not a fallback.

[`45`](45-WHY-A-POS-TAP-FAILS.md) is how to make that tap work and how to read
the black box when it does not.

---

## 5. What cannot be built, said plainly

I want to be exact here rather than encouraging, because you have asked for
this to be solved twice and deserve a real answer instead of a third attempt.

**There is no decoder, no library, no API and no amount of engineering that
extracts a merchant category from those 39 bytes.** The information is not
present. This is not a limit of SWIP's parser — it is a property of the
photograph. The same is true for CRED, for any bank's app, and for anyone else
who tries.

What *is* possible, and what SWIP already does:

1. **Read the codes that do carry it** — every Google Pay for Business sticker,
   and bank-issued codes like the `vyapar…@hdfcbank` one in your own
   screenshot, which came back **8999 Professional Services**. That one worked
   perfectly, from the same scanner, in the same session.
2. **Say which is which, honestly**, instead of showing a blank.
3. **Tell you the RuPay answer anyway**, from the handle, which is the question
   underneath the question.
4. **Get the category from the terminal** when the sticker has none.

---

## 6. The one-line version

**The MCC is not in that QR, and no app can take out what was never put in.
Paytm does not publish it, Google Pay does, and for a Paytm shop the way to the
category is their card machine.**
