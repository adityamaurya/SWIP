# 41 — The Razorpay key, explained

> *"what to do with the Razorpay key ID? I have gone into test mode and given
> the app a test ID and key access key. Now what should I do? What will help?
> What is that Razorpay thing section just below 'Scan me anywhere' telling me
> about? What is that feature going to need?"* — prompt 48

Written because the owner could not understand the screen, and **that is the
screen's fault.** If the person who commissioned the feature cannot tell what it
does, nobody downloading the app can.

---

## 1. What it is, in one sentence

**It turns a payment address into a shop's real name.**

That is all. It is the *only* thing in SWIP that ever contacts a server, it is
**off** until you switch it on, and it has nothing to do with the MCC.

---

## 2. Why it exists

Scan a Paytm sticker and the payload says this, in full:

```
upi://pay?pa=paytm.s27l8o9@pty&pn=Paytm
```

`pn` is the *payee name* and it says **"Paytm"**. Not the shop. Every Paytm
sticker in India says "Paytm", so on its own SWIP can only tell you that you are
about to pay a Paytm merchant — which you could see from the sticker.

CRED shows the actual shop name for that same code. It is not doing anything
magic and it is not reading it out of the QR, **because the name is not in the
QR**. It is asking a payment provider *"who owns this address?"* and printing
the answer.

SWIP can make the same request. It needs an account to make it with, and the
only honest way to do that in an app with no server is for you to bring your
own.

---

## 3. What actually happens on the wire

One HTTPS request, only when a scanned shop has no name, and only once per shop
ever:

```
POST https://api.razorpay.com/v1/payments/validate/vpa
Authorization: Basic base64(key_id:key_secret)
Content-Type: application/json

{"vpa": "paytm.s27l8o9@pty"}
```

and the answer:

```json
{"vpa": "paytm.s27l8o9@pty", "success": true, "customer_name": "SHRI BALAJI STORES"}
```

**What is sent:** the payment address, and nothing else. Never a capture, never
an amount, never your location, never anything from your ledger. The answer is
stored on the phone so the same shop is never looked up twice.

**What comes back:** a name and a yes/no. Look at the response fields — there is
no MCC in it. §6.

---

## 4. Your test key: what to do with it

You have `rzp_test_…` and its secret. Here is the whole sequence.

| Step | Where |
|---|---|
| 1 | SWIP → **Settings** → **Merchant names** |
| 2 | Turn **Look up merchant names** on |
| 3 | Paste the **key id** (`rzp_test_…`) and the **key secret** |
| 4 | Press **Test the key** |
| 5 | Read what it says |

**Step 5 is the answer to your question**, and it is worth being exact about
why. Razorpay's own documentation is not reachable from the machine this is
written on — it is blocked by this environment's network policy, which is
recorded in `CLAUDE.md` and is why three constants in
[`merchant_directory.dart`](../app/lib/data/sources/merchant_directory.dart)
were once shipped unverified. So rather than tell you what a test key will do,
**the app asks Razorpay and shows you the reply.** That button exists precisely
so that neither of us has to guess.

What the three outcomes mean:

| It says | What it means | Do this |
|---|---|---|
| A name came back | It works. Leave it on | Nothing |
| **401 / authentication failed** | The key id and secret do not match, or there is a stray space | Re-paste both. The secret is only shown **once** by Razorpay — if you lost it, generate a new pair |
| **Anything about the endpoint being unavailable** | The account or the mode does not have access to this API | §5 |

### Test key or live key?

**Start with the test key. Always.**

A Razorpay key pair is not read-only — Razorpay does not issue a read-only key.
The same credentials that resolve an address can **create orders, list every
payment on the account, and issue refunds.** A `rzp_test_` key operates on a
sandbox and **cannot move money**, which is why the screen recommends it and why
it is what you should keep in the app.

A live key in a phone's `SharedPreferences` is readable by anything with root
and travels in device backups. That is a real, specific risk, not a
disclaimer — and it is why the only design that removes it entirely is a server
holding the key, which SWIP deliberately does not have.

---

## 5. The honest risk, which you should know before you rely on this

**This endpoint's main reason for existing has just been withdrawn.**

`validate/vpa` was built so a merchant could check an address *before sending a
UPI collect request*. NPCI has **deprecated the UPI Collect flow, effective 28
February 2026** — customers can no longer pay or register mandates by typing a
VPA by hand. That date has passed.

Confirmed from three independent payment providers, not one:

* [PayU — UPI Collect Disablement](https://docs.payu.in/docs/upi-collect-disablement-information)
* [Cashfree — UPI Collect Deprecation](https://www.cashfree.com/docs/payments/manage/payment-methods/upi-collect)
* [Razorpay — UPI Intent vs Collect](https://razorpay.com/blog/upi-intent-vs-collect-success-rates/)

Narrow exemptions remain — **MCC 6012 and 6211** (IPO and secondary-market),
iOS, mandate management, and cross-border.

**What this means for SWIP:** the endpoint is a *name lookup* and nothing else,
so it is not affected by the collect rules directly. But an API whose principal
customer has been switched off is an API that can be retired. This feature is
therefore built as **one named file behind an injected transport**, so that if
the endpoint disappears, one class changes and nothing else in the app notices.
The app already treats a 404 from it as "no name available" rather than as an
error.

---

## 6. What it will **not** do, ever

**It does not give you the MCC.**

Worth saying flatly because it is the obvious hope and it is wrong. There is no
commercial API in India that returns a merchant category code for a VPA. The
MCC lives in the **acquiring bank's switch**, and it is disclosed to the card
networks during authorisation — not to a public lookup.

That is not SWIP being underpowered. It is why CRED writes **"MERCHANT MAY NOT
ACCEPT RUPAY CC"** — the word *may* is the tell that they are inferring it too,
from exactly the same evidence SWIP has.

The MCC comes from two places and only two: **the QR payload itself** (EMVCo tag
52 or `mc=`), or **the shop's card machine over NFC**. See
[`42`](42-MARKET-QR-CORPUS.md) for how often the first one is actually there.

---

## 7. So is it worth turning on?

**Yes, for one reason:** without it, a Paytm capture in your ledger reads
"Paytm", and after thirty of them your ledger is thirty rows that all say
Paytm. With it, they are thirty shop names you recognise.

**It will not tell you which card to use.** That is the other half of the
product and it comes from the QR and the terminal.

---

## 8. What was built this round

`F-181`. The screen was a wall of correct, necessary warnings with two text
fields at the bottom, and the owner — who asked for the feature — could not
tell what it was for.

So the warnings stay, because they are true and they belong before the switch
rather than after it, but the **first run is now a four-screen walkthrough**,
matching the pattern `F-159` established for the floating bubble:

1. **What this does** — the Paytm payload, in full, with its `pn=Paytm`
2. **What leaves your phone** — the exact request, and the list of what is never
   sent
3. **What a Razorpay key can do** — the real risk, and why to use a test key
4. **Get your key** — the literal click path on razorpay.com, then the two
   fields and the test button

The settings screen is what you see afterwards.

---

## 9. Where the code is

| Thing | File |
|---|---|
| The API client and the three constants | [`merchant_directory.dart`](../app/lib/data/sources/merchant_directory.dart) |
| Where the key is stored, and `usable` | [`merchant_lookup.dart`](../app/lib/features/lookup/merchant_lookup.dart) |
| The settings screen | [`lookup_settings_page.dart`](../app/lib/features/lookup/lookup_settings_page.dart) |
| **The new walkthrough** | [`lookup_wizard.dart`](../app/lib/features/lookup/lookup_wizard.dart) |
| The injected transport the gate allows | [`directory_transport.dart`](../app/lib/data/sources/directory_transport.dart) |
