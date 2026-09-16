# 43 — The Razorpay thing, in plain words

> *"I did not get the Razorpay key thing that you are telling me. Can you
> explain in very lame language… I am not technically in that area, so help me
> get a gauge of what is happening there."* — prompt 49

[`41`](41-RAZORPAY-EXPLAINED.md) is the accurate version. **This is the version
with no jargon in it.** Nothing here is dumbed down; it is the same facts with
the vocabulary removed.

---

## 1. The problem, with a real example

You walk up to a shop. There is a Paytm sticker on the counter. You scan it.

Inside that sticker, the *entire* message is this:

```
pay to: paytm.s27l8o9@pty
name:   Paytm
```

That is genuinely all of it. **The shop's name is not written on the sticker.**
The name field says "Paytm" — and every single Paytm sticker in India says
"Paytm", because Paytm printed them.

So SWIP can tell you "this is a Paytm shop", which you could already see,
because you are looking at a Paytm sticker.

---

## 2. How CRED shows a real name, then

CRED is not reading it off the sticker either. **The name is not there to
read.**

What CRED does is ask somebody. It sends that address — `paytm.s27l8o9@pty` —
to a company that handles payments, and that company looks it up in its records
and replies:

```
that address belongs to: SHRI BALAJI STORES
```

That is the whole trick. It is a phone call, not a magic decoder.

---

## 3. Why SWIP needs *your* account to make that phone call

The company CRED asks will only answer people who have an account with them.
CRED has one. SWIP does not — **and it cannot have one**, for a reason worth
understanding.

An account like that comes with a password. If SWIP had one password built into
the app, then that password is inside the app on every phone that installs it.
Anybody can open up an app file and read what is inside — it takes about two
minutes and no special skill. So the password would be public, and then anybody
could use it, and it is **our** account they would be using.

The only way around that is to have a server: a computer we own, sitting in the
middle, holding the password and passing questions along. SWIP deliberately has
no server. That is the whole promise of the app — nothing you scan ever leaves
your phone.

So the honest option left is: **if you want this, you bring your own account.**

---

## 4. What a "key" actually is

A key is just **a username and a password**, with fancier names:

| What Razorpay calls it | What it is |
|---|---|
| Key ID (`rzp_test_…`) | The username |
| Key secret | The password |

That is the entire mystery. When the app asks you to paste a "key id" and a
"key secret", it is asking you to paste a username and a password so it can
make that phone call on your behalf.

---

## 5. Test key versus live key

Razorpay gives you two sets:

| | What it can do |
|---|---|
| **Test** (`rzp_test_…`) | Works against a practice system. **Cannot move money.** Ever. |
| **Live** (`rzp_live_…`) | The real account. Can move real money. |

**Use the test one.** Keep using the test one.

Here is why that matters more than it sounds. Razorpay does not offer a
"look-but-don't-touch" password. The same password that lets SWIP ask *"whose
address is this?"* also lets whoever holds it:

* take payments,
* see every payment your account has ever received,
* send money back out as refunds.

There is no smaller version of it. So if it is sitting on a phone, and that
phone is lost, or backed up somewhere, or has some other dodgy app on it — that
is your live payment account sitting there.

The test password cannot do any of that, because there is no real money behind
it. **That is why the app recommends it and why the warning screen is as blunt
as it is.**

---

## 6. What you actually do, step by step

1. Go to **razorpay.com** and make a free account. You do not need a business.
   You do not need to take a single payment.
2. On their dashboard, find the **Test Mode** switch at the top and turn it on.
3. Go to **Account & Settings → API Keys → Generate Test Key**.
4. It shows you two strings. **Copy both.** The password half is shown **once
   and never again** — if you lose it, you just generate a new pair, no harm
   done.
5. In SWIP: **Settings → Merchant names**. Paste both.
6. Press **Test the key**.

That last button is the important one. It actually makes the phone call and
shows you what came back. You do not have to trust me about whether it works —
press it and read the answer.

---

## 7. What you get, and what you do not

**You get:** shop names in your ledger. Instead of thirty rows that all say
"Paytm", thirty rows with names you recognise.

**You do not get the category code.** Not from this, not from anything like it.

That is worth being blunt about because it is the obvious hope. The category
code is assigned by the **bank that signed the shop up**, and it lives inside
that bank's systems. It is told to Visa and Mastercard when a card is used. It
is not in any list anybody can look up.

This is exactly why CRED writes *"merchant **may** not accept RuPay CC"* — the
word *may* is them admitting they are guessing too, from the same scraps SWIP
has.

The category reaches your phone in **two ways only**:

1. The sticker happens to have it printed inside. [About one time in
   ten](42-MARKET-QR-CORPUS.md).
2. **You tap the shop's card machine.** That is the other half of SWIP, and it
   is the only route that works on a Paytm sticker.

---

## 8. One thing that might break, and what happens if it does

The service SWIP calls was built for a different purpose that India's payments
regulator has just switched off — manually typing somebody's payment address to
request money from them, discontinued 28 February 2026.

The name lookup itself is not affected. But a service whose main customer has
gone is a service that could be retired, so it is built as **one small
swappable piece**: if it disappears one day, one file changes and the rest of
the app does not notice. The app already treats "that service is gone" as "no
name available" rather than as an error.

Sources, so this is not just me saying it:
[PayU](https://docs.payu.in/docs/upi-collect-disablement-information) ·
[Cashfree](https://www.cashfree.com/docs/payments/manage/payment-methods/upi-collect) ·
[Razorpay](https://razorpay.com/blog/upi-intent-vs-collect-success-rates/)

---

## 9. The one-line version

**It is a free account you make in five minutes, it turns payment addresses
into shop names, it is switched off until you turn it on, it only ever sends an
address and nothing else, use the test password, and it has nothing to do with
the category code.**
