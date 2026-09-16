# 42 — 52 QR codes from one market walk

> *"sharing you multiple QRs I went to market the other day, it failed on major
> of the Paytm QRs, help me get it resolved man, lets do it lets resolve this
> otherwise the app is super useless… find a way, no matter how you can do it,
> just do it, and get me the MCC code from these QR codes. Find a pattern for
> which QR codes are not new, are tough to scan, and are not giving away MCC
> codes directly."* — prompt 48

52 photographs, one afternoon, one market. This is the largest field sample
this project has, and it settles several arguments.

**The headline, before anything else: the app is not failing on your Paytm
codes. It is reading them perfectly and telling you the truth, which is that
Paytm does not publish a category. Fourteen out of fourteen.**

---

## 1. What was done

Every page image was extracted from the PDF and decoded with **pyzbar**
(libzbar), **OpenCV's `QRCodeDetector`** and **`QRCodeDetectorAruco`**, each
over a ladder of preprocessing: greyscale, four rescales, Otsu and adaptive
thresholds, CLAHE, unsharp masking, morphological closing, three rotations and
three centre crops — first match wins.

**48 of 52 decoded.** 44 of those on the very first attempt, from the raw
photograph with no preprocessing at all.

The four that did not are §5, and they got a further seven minutes each of
finder-pattern clustering and an exhaustive sliding-window sweep with
rotations. They still did not decode, and §5 explains why that is the correct
answer rather than a failure.

---

## 2. The distribution, which is the whole product in one table

| | Codes | Carry `mc` | `mc=0000` | **A usable category** |
|---|---|---|---|---|
| **PhonePe** (`@ybl`) | 24 | 22 | 22 | **0** |
| **Paytm** (`@pty`, `@ptys`, `@pta`, `@paytm`) | 14 | 0 | 0 | **0** |
| **BharatPe** (`@fbpe`, `@unitype`, `@yesbankltd`) | 5 | 0 | 0 | **0** |
| **Google Pay for Business** (`@okbizaxis`, `@okbizicici`) | 3 | 3 | 0 | **3** |
| **Vyapar** (`@hdfcbank`) | 2 | 2 | 0 | **2** |
| **Total** | **48** | 27 | 22 | **5** |

**Five out of forty-eight.** That is roughly one in ten, and it matches the
earlier 10-code corpus and the owner's own 85-capture export exactly.

The five that do carry one:

| Page | Brand | MCC | What it means |
|---|---|---|---|
| 3 | Google Pay | `5411` | Grocery stores, supermarkets |
| 16 | Google Pay | `5411` | Grocery stores, supermarkets |
| 32 | Google Pay | `5399` | Miscellaneous general merchandise |
| 4, 5 | Vyapar / HDFC | `8999` | Professional services |

---

## 3. The pattern, stated plainly

**The acquirer decides, and the shop has no say in it.**

Every Google Pay for Business QR in this sample publishes an MCC. **Not one**
Paytm, PhonePe or BharatPe QR does. This is not about the size of the shop, the
category, or how new the sticker is — the same vegetable stall would publish a
category on a Google Pay code and not on a PhonePe one.

Three distinct shapes, and they mean different things:

### Absent — Paytm and BharatPe

```
upi://pay?pa=paytm.s27l8o9@pty&pn=Paytm
upi://pay?pa=BHARATPE.9J0B0E7A5G447437@fbpe&pn=Verified Merchant&cu=INR&tn=Pay to BharatPe
```

There is **no `mc` parameter at all.** Nineteen of the forty-eight are this
shape. No app can read a category out of these, CRED included. It is not in the
bytes.

### Present and zeroed — PhonePe

```
upi://pay?pa=Q472112445@ybl&pn=PhonePeMerchant&mc=0000&mode=02&purpose=00
```

Twenty-two of the forty-eight. `mc=0000` is **the acquirer filling the field in
with nothing** — a different statement from never publishing one, and worth
saying differently. SWIP keeps the literal `0000` so it can say *"the acquirer
left this blank"*, while `hasMcc` returns false so `0000` never reaches a screen
as a category.

### Published — Google Pay for Business, and bank-acquired billers

```
upi://pay?pa=gpay-11252478681@okbizaxis&mc=5411&pn=Google%20Pay%20Merchant&oobe=fos123&qrst=…
```

Five of the forty-eight.

---

## 4. Four things the corpus proved that reading could not

### The `sign=` block is not a JWT

Three of the twenty-four PhonePe codes carry one. Decoded, it is a raw **DER
ECDSA signature** — an ASN.1 `SEQUENCE` of two `INTEGER`s, `r` and `s`:

```
SEQUENCE len=69
  INTEGER len=32  00b1935b4f54f4b988a8d9af…
  INTEGER len=33  009fca6bf2562e3a62da4048…
```

It carries **no payload of its own**, so there is nothing to extract from it and
no extra field hiding inside. Its only use is as proof that NPCI minted the
code, verifiable with a public key that is not published to app developers. So
it is a *presence* signal and nothing more — which is exactly how
`merchant_identity.dart` already uses it, and now for a recorded reason rather
than an assumed one.

### Five payment handles were missing from the app

`@pta`, `@okbizaxis`, `@okbizicici`, `@unitype` and `@fbpe` were all unknown to
SWIP. Five real shops in this sample would have shown a blank where the payment
company goes — including **all three of the Google Pay codes**, which are the
only ones in the corpus that carry a category.

A gap like that cannot be found by reading: the handle map has fifty entries and
looks exhaustive, and `pta` was missing while `pty`, `ptys`, `ptsbi`, `ptaxis`,
`pthdfc` and `ptyes` were all present. Fixed in `F-182`, and
`test/market_qr_corpus_test.dart` now asserts that **every acquirer in the
corpus is named**.

### `pn=Default` was becoming a shop's name

The two Vyapar codes carry `pn=Default` — a billing app's unset form field. It
walked straight through `_genericNames`, because every entry in that list was
PSP *branding*: "Paytm", "Verified Merchant", "Google Pay Merchant". This one is
not branding, so nothing about it looked wrong.

Two shops in one afternoon would have been filed in the ledger as a business
called **Default**.

**It was found by this corpus's test failing on its first CI run**, which is the
best argument for the fixture: nothing in `merchant_identity.dart` looked wrong,
and re-reading that list a third time would not have suggested it.

### The payment company is never the shop

Forty-eight codes, and the `pn` field names **not one actual business**. Every
value is a placeholder printed by the PSP: `Paytm`, `PhonePeMerchant`,
`Verified Merchant`, `Google Pay Merchant`, `Default`.

That is the entire argument for the merchant-name lookup in
[`41`](41-RAZORPAY-EXPLAINED.md), and it is now a test rather than a claim.

---

## 5. The four that would not decode, and why that is the right answer

Not one of them is a software problem, and this is the part worth being exact
about.

| Page | What is in the photograph |
|---|---|
| **14** | A Paytm card rotated about 100°, with a plastic-wrapped idol resting across the lower-left of the code |
| **22** | A PhonePe soundbox in a dark stall. Laplacian variance **15** — the other three measure 111, 226 and 298. It is badly out of focus, the card is soiled, and the code is small in frame |
| **33** | A BharatPe card lying among green chillies, bent, with chillies across it and the printed modules scuffed away |
| **41** | A BharatPe card upside down with **onion skins lying across the data area**, on top of a printed centre logo that was already spending the error-correction budget |

**A QR code at the error-correction level these are printed at carries roughly
15% redundancy.** Past that the bytes are not in the photograph, and no
preprocessing invents them. Each of these four got finder-pattern clustering,
then an exhaustive sliding-window sweep — every tile at four window sizes, each
rotated through twelve angles, each binarised seven ways. Around **seven minutes
of compute per photograph**, and all four came back empty.

That is not the decoder giving up. It is the decoder being correct.

### What was built because of it

`F-183`. The scanner used to show a live camera and a static caption forever. A
viewfinder that silently reads nothing is indistinguishable from a broken app —
**which is exactly how it got reported.**

After seven seconds of a running camera with nothing read, the caption becomes:

> Still looking. Usually one of these:
> Something is resting on the code · the card is dirty or worn
> it is too dark — try the torch · hold a little steadier

Four lines, and **each one names a failure that actually happened in this
sample**, in the order it occurred. Three of the four the user can fix by
moving something, which is the whole reason for saying it.

It deliberately does not say *"try again"* or *"make sure the QR is valid"*. A
code that will not read is not a code somebody typed wrong.

---

## 6. So how do you get an MCC out of a Paytm sticker?

**You do not, and neither does anybody else.** It is worth being blunt about
this because it is the question the product exists to answer.

The MCC is assigned by the **acquiring bank** when the merchant is onboarded,
and it lives in the acquirer's switch. It is disclosed to the card networks
during authorisation. It reaches a phone in exactly two ways:

1. **The acquirer chose to print it in the QR** — tag 52, or `mc=`. Five times
   out of forty-eight here.
2. **The shop's card machine tells you**, over NFC. That is SWIP's Vector 2,
   and it is the *only* route that works on a Paytm sticker.

There is no third way. No commercial API returns an MCC for a VPA — not
Razorpay, not Cashfree, not Decentro, not Juspay. That is why CRED writes
**"MERCHANT MAY NOT ACCEPT RUPAY CC"**: the word *may* is them inferring from
exactly the same evidence SWIP has.

**What SWIP can still tell you about all forty-eight**, without a category:

* **Which payment company** minted the address — now correct for all 48
* **Whether the payee is a registered business or a person** — all 48 carry a
  handle a PSP mints at onboarding, so none is a person
* **Which NPCI tier**, which decides whether a RuPay credit card can work at all
* **That the category is absent rather than unknown**, and that the card machine
  is the way to get it

That is the honest product, and this corpus is what it is built on.

---

## 7. What is in the repository now

| | |
|---|---|
| The 48 payloads, verbatim | [`test/fixtures/market_qr_corpus.json`](../app/test/fixtures/market_qr_corpus.json) |
| The assertions over them | [`test/market_qr_corpus_test.dart`](../app/test/market_qr_corpus_test.dart) |
| The five handle fixes | [`merchant_identity.dart`](../app/lib/data/sources/merchant_identity.dart) |
| The scanner's stuck state | [`scan_page.dart`](../app/lib/features/capture_qr/scan_page.dart) |

The test pins **five of forty-eight** as the number that carry a category. If a
change makes that go up, it is a real improvement and the number should be
edited deliberately. If it goes down, something broke.

---

## 8. Honest caveats

* **The photographs are not the app.** These were decoded from stills; the phone
  decodes a live stream, where the user can move, focus and light the subject.
  Real-world decode rate should be *better* than 48/52, not worse.
* **One market, one afternoon, one city.** The Google-Pay-publishes /
  Paytm-does-not pattern matches two earlier samples, but three samples from the
  same country is not a law.
* **No page here is paired with what a payment app said about it**, unlike the
  63-page PDF behind [`test/pdf_qr_corpus_test.dart`](../app/test/pdf_qr_corpus_test.dart).
  So this corpus proves what is in the codes, not whether SWIP's RuPay verdict
  matches a second opinion.
