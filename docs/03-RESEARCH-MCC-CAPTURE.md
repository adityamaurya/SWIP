# SWIP — Research Dossier: How to Actually Capture an MCC

> Answers ideation IDs `C-02` … `C-14`, `E-04`, `E-05`.
> Everything below is either cited or derived from a cited primary spec.
> Where I could not verify something, it says **UNVERIFIED — field test required**,
> and there is a test protocol. I have not guessed and presented it as fact.

---

## 0. Executive answer

You asked one question in five shapes: *how do I learn the MCC of a purchase before or during the purchase?*

There are exactly **six** places in the world where an MCC physically exists in a form
a phone can reach. Not five, not seven. Here they are, ranked by how obtainable they are:

| # | Vector | Where the MCC lives | Can a phone get it? | Licence needed | SWIP version |
|---|---|---|---|---|---|
| 1 | **Merchant-presented QR** | EMVCo TLV **tag 52**, or UPI intent param `mc` | **Yes, trivially.** It is printed in the QR | None | **v1 — built** |
| 2 | **POS terminal, contactless** | EMV **tag `9F15`**, which the *card* can demand from the *terminal* via PDOL | **Yes, and this is the novel part** | None | **v1 — built (Android)** |
| 3 | **Payment link (Razorpay/Stripe/Cashfree)** | Nowhere in the URL. It lives in the acquirer's merchant record | **No — only inferable** | None | v1 heuristic, v2 definitive |
| 4 | **Card authorization message** | ISO 8583 **field 18** (Card Acceptor Business Code) | **Yes — but only if you are the issuer** | Issuer/BIN access | **v2 — the Probe Card** |
| 5 | **Bank statement / transaction alert** | Almost never present. Only the narration is | Mostly no | — | v2, low value |
| 6 | **A database somebody already built** | Someone else's capture, or a network's merchant API | **Yes** | Commercial | **v1 — and this is the moat** |

The strategic conclusion, which I want to state before the detail:

> **Vector 2 is your unfair advantage, and Vector 6 is your business.**
> Vector 1 is table stakes — anyone can build it in a weekend. Vector 2 is a genuinely
> novel use of a 20-year-old spec that, as far as I can find, no consumer app ships.
> Vector 6 is what makes SWIP defensible: every tap and every scan by every user makes
> the answer better for the next user, including at merchants where **no** live capture
> is possible. That is the answer to your hardest question — *"what do I do when there
> is no QR and I just have to hand over my card?"* You don't capture it. **You already
> know it, because someone else captured it.**

---

## 1. What an MCC actually is

A **Merchant Category Code** is a four-digit number classifying a merchant's line of
business, standardised as **ISO 18245** (current edition ISO 18245:2023). ([ISO](https://www.iso.org/standard/79450.html), [Wikipedia](https://en.wikipedia.org/wiki/ISO_18245))

Facts that matter for the product:

- **Ranges are semantic.** `0001–1499` agricultural, `1500–2999` contracted services,
  `4000–4799` transportation, `4800–4999` utilities, `5000–5599` retail, `5600–5699`
  clothing, `5700–7299` misc/services, `7300–7999` business & professional services,
  `8000–8999` professional services, `9000–9999` government. ([Wikipedia](https://en.wikipedia.org/wiki/Merchant_category_code))
- **There is no single canonical list.** Mastercard's October 2024 list contains **879**
  MCCs in 20 groups — 293 generic, 566 merchant-specific. Visa, Amex, Discover and
  RuPay each publish their own overlapping variants. ([Wikipedia](https://en.wikipedia.org/wiki/Merchant_category_code), [Classification.Codes](https://classification.codes/classifications/industry/mcc/))
- **This directly justifies your `D-05` requirement.** You asked for column 2 to say
  whether a code is published *nationally, internationally, or by RuPay*. That is
  exactly right and it is a real distinction — the same four digits can be defined by
  ISO, redefined by a network, and treated differently again by an Indian issuer.
  SWIP models this as a set, not a single value.
- **The merchant does not choose its MCC.** The **acquirer** assigns it at onboarding
  from the declared business type, and the networks audit and can force reclassification
  with fines. A wrong MCC causes declines, interchange downgrades and penalties.
  ([Visa Acceptance](https://support.visaacceptance.com/knowledgebase/knowledgearticle/?code=KA-09260))
  This single fact is the answer to `E-05`/`E-08`, and I come back to it in
  [04-BUSINESS-MODEL §5](04-BUSINESS-MODEL.md#5-the-mcc-question-answered-honestly).

### 1.1 The pain you described (`C-11`)

> *"People generally tap their card, disabling it first, and later on they call customer
> support and get the merchant category code by asking them what the merchant category
> code is."*

This is real and it is documented behaviour in the points-and-miles community. The
current state of the art for a consumer is: (a) make a small test transaction and wait
for it to post, (b) look it up in a static community-maintained table, or (c) ask the
issuer. ([The MileLion](https://milelion.com/2025/01/19/how-to-check-merchant-category-codes-mccs-before-making-a-purchase/), [SuiteSmile](https://suitesmile.com/blog/2025/06/05/how-to-check-merchant-category-code-mcc-before-paying/))

Existing tools are all **static lookup directories** — AwardWallet's merchant tool,
HeyMax, Chargebacks911, Swipesum, Classification.Codes, eflow. ([AwardWallet](https://awardwallet.com/merchants), [Classification.Codes](https://classification.codes/mcc-lookup))
Every one of them answers *"what MCC does this brand usually use?"*

**Nobody answers *"what MCC will this specific terminal, in front of me, right now, send?"***

That is the SWIP wedge.

---

## 2. Vector 1 — Merchant-presented QR  `C-03` `C-14`

### 2.1 The mechanism

EMVCo's **Merchant-Presented Mode (MPM)** specification defines a TLV
(tag-length-value) payload carried in the QR. **Root tag `52` is the Merchant Category
Code**: 4 numeric characters, and it is **mandatory**. ([EMVCo](https://www.emvco.com/processes/merchant-presented-qr-codes/), [MPM spec v1.1 PDF](https://mvallim.github.io/emv-qrcode/docs/EMVCo-Merchant-Presented-QR-Specification-v1.1.pdf), [EMV QR Hub](https://emvqrhub.com/learn/emv-qr-payload-format/))

Full root-tag map that SWIP's parser implements:

| Tag | Field | Notes |
|---|---|---|
| `00` | Payload Format Indicator | always `01` |
| `01` | Point of Initiation Method | `11` = static, `12` = dynamic |
| `02–51` | Merchant Account Information templates | `02–03` Visa, `04–05` Mastercard, `06–08` EMVCo, `09–10` Discover, `11–12` Amex, `13–14` JCB, `15–16` UnionPay, `26–51` domestic schemes (UPI, PromptPay, QRIS, PayNow…) |
| **`52`** | **Merchant Category Code** | **← the prize. 4 digits** |
| `53` | Transaction Currency | ISO 4217 numeric |
| `54` | Transaction Amount | absent on static QRs |
| `55–57` | Tip / convenience fee | |
| `58` | Country Code | ISO 3166-1 alpha-2 |
| `59` | Merchant Name | |
| `60` | Merchant City | |
| `61` | Postal Code | |
| `62` | Additional Data Template | sub-tags: `01` bill no, `03` store label, `05` reference, `07` terminal label, `08` purpose |
| `63` | CRC | CRC-16/CCITT-FALSE, poly `0x1021`, init `0xFFFF`, computed over the payload **including** the literal `6304` |
| `64` | Merchant Info — Language Template | local-script merchant name |
| `80–99` | Unreserved templates | scheme-private |

So: **for any merchant-presented QR built on EMVCo MPM, the MCC is simply *in the code*,
in plaintext, four digits, at tag 52.** No network call, no account, no licence. Offline.
On a plane. This is why `C-03` is not just feasible — it is the cheapest possible feature
in the entire product and it should be the first thing a new user ever does.

### 2.2 India specifically — there are TWO formats, and most apps only handle one

This is the single most common implementation mistake and I want you to know it up front.

1. **BharatQR** — EMVCo MPM TLV, as above. MCC at tag `52`.
   ([BharatQR](https://en.wikipedia.org/wiki/BharatQR))
2. **UPI intent URI** — *not* TLV. A URI:
   ```
   upi://pay?pa=merchant@bank&pn=Merchant%20Name&mc=5812&tid=…&tr=…&tn=…&am=100.00&cu=INR
   ```
   Here the MCC is the **`mc`** parameter. NPCI defines `mc` as the four-digit merchant
   category code used for merchant MIS, statistics and business reports.
   ([NPCI UPI Linking Spec 1.6](https://www.labnol.org/files/linking.pdf), [QRCrack NPCI guide](https://qrcrack.com/blog/upi-qr-codes-india-npci-specification))

A very large share of Indian merchant QRs are the **URI** form, and a large share of
those ship `mc=0000` — because P2P VPAs and small unregistered merchants have no assigned
category. SWIP must handle `0000` gracefully as *"this is a person-to-person or
unclassified handle"*, not as an error, and must then fall back to Vector 6.

### 2.3 CRC — why SWIP validates it

A mis-scanned or tampered QR that still decodes will produce a plausible-looking but wrong
MCC. SWIP computes CRC-16/CCITT-FALSE over the payload and refuses to display a code from a
QR that fails. For a finance app, showing a confidently wrong number is worse than showing
nothing. Implementation: `app/lib/data/sources/emv_qr_parser.dart`.

### 2.4 World coverage `C-14`

You said *"there could be many types of QR codes in this whole continent — China, Western
Europe, every damn country."* Correct, and here is the actual map.

**The good news: EMVCo MPM won.** PIX (Brazil), PromptPay (Thailand), DuitNow (Malaysia),
PayNow/SGQR (Singapore), BharatQR (India), HKQR (Hong Kong), QRIS (Indonesia), KHQR
(Cambodia), QR Ph (Philippines), VietQR (Vietnam), Bangla QR, Lao QR — all EMVCo-compliant
TLV underneath. ([EMV QR Hub — interoperability](https://emvqrhub.com/learn/qr-interoperability/), [QRIS](https://en.wikipedia.org/wiki/QRIS), [Thai QR Payment](https://en.wikipedia.org/wiki/Thai_QR_Payment))

The caveat, and SWIP handles it: *"EMVCo-compatible" does not mean identical.* Markets layer
on reserved merchant-account-ID ranges, mandatory sub-tags, and localised category handling.
A parser built only for one overlay will reject a valid foreign payload. **SWIP's parser is
deliberately overlay-agnostic: it parses the root TLV, reads tag 52, and never requires a
domestic sub-tag to be present.**

| Region | Scheme | Format | Tag 52 present | SWIP v1 |
|---|---|---|---|---|
| India | BharatQR | EMVCo TLV | Yes | ✅ |
| India | UPI intent | URI (`mc=`) | Yes | ✅ |
| Brazil | PIX | EMVCo TLV | Yes | ✅ |
| Thailand | PromptPay | EMVCo TLV | Yes | ✅ |
| Singapore | SGQR / PayNow | EMVCo TLV | Yes | ✅ |
| Indonesia | QRIS | EMVCo TLV | Yes | ✅ |
| Malaysia | DuitNow | EMVCo TLV | Yes | ✅ |
| Philippines | QR Ph | EMVCo TLV | Yes | ✅ |
| Vietnam | VietQR | EMVCo TLV | Yes | ✅ |
| Hong Kong | HKQR | EMVCo TLV | Yes | ✅ ([HKMA spec](https://www.hkma.gov.hk/media/eng/doc/key-functions/financial-infrastructure/infrastructure/retail-payment-initiatives/Common_QR_Code_Specification.pdf)) |
| Cambodia / Laos / Bangladesh | KHQR / LaoQR / BanglaQR | EMVCo TLV | Yes | ✅ |
| EU / SEPA | EPC069-12 QR | **Proprietary** (SEPA Credit Transfer) | **No MCC** | ⚠️ parsed, MCC unavailable → Vector 6 |
| China | Alipay | **Proprietary** (also 1D barcode) | **No** | ⚠️ identified only |
| China | WeChat Pay | **Proprietary** | **No** | ⚠️ identified only |

**China and the EU are the two genuine holes.** Alipay and Tenpay shipped proprietary QR
formats from late 2011, before EMVCo MPM existed, and have never fully migrated; Alipay
maintains its own code standard alongside EMVCo's. ([World Bank Focus Note on QR in payments](https://fastpayments.worldbank.org/sites/default/files/2021-10/QR_Codes_in_Payments_Final.pdf), [Kapronasia](https://www.kapronasia.com/china-payments-research-category/qr-codes-helped-define-alipay-and-wechat-pay-but-now-they-might-be-their-biggest-challenge.html))
The European EPC QR standard carries a SEPA credit transfer, which has no merchant category
concept at all. For all three, SWIP identifies the scheme and merchant handle and answers
from Vector 6 instead of failing.

---

## 3. Vector 2 — the POS tap  `C-04` `C-05`

**This is the most important section in this document.** You had an intuition —
*"instead of tapping his card he taps his application, and it'll get the merchant category
code accordingly"* — and you were right, for a reason you didn't know. Here is the reason.

### 3.1 How a contactless payment actually works

You said you weren't sure how the Visa/Mastercard infrastructure works on a POS
(`C-05`). It is an **APDU conversation** — a strict question-and-answer game over NFC
between the terminal (the reader) and the card (the tag). It runs roughly ten rounds and
finishes in under 500 ms. ([AndroidCrypto HCE tutorial](https://medium.com/@androidcrypto/how-to-emulate-a-credit-card-on-android-with-host-based-card-emulation-hce-in-java-0652342da0f1))

```
TERMINAL                                              CARD
   │
   │  1.  SELECT PPSE  ("2PAY.SYS.DDF01")
   ├─────────────────────────────────────────────────────►
   │                          FCI: list of AIDs (tag 4F) + priority
   ◄─────────────────────────────────────────────────────┤
   │
   │  2.  SELECT AID  (e.g. A0000000031010 = Visa)
   ├─────────────────────────────────────────────────────►
   │             FCI, and — crucially — the  P D O L  (tag 9F38)
   ◄─────────────────────────────────────────────────────┤
   │            ⇧ THE CARD TELLS THE TERMINAL WHAT DATA IT WANTS
   │
   │  3.  GET PROCESSING OPTIONS  (80 A8 00 00 …)
   │      …with the PDOL values the card asked for, filled in
   ├─────────────────────────────────────────────────────►
   │                                          AIP + AFL
   ◄─────────────────────────────────────────────────────┤
   │
   │  4.  READ RECORD × n,  then GENERATE AC
   ├─────────────────────────────────────────────────────►
```

### 3.2 The insight

Look at step 2 again.

**The card dictates the agenda.** The PDOL (Processing Options Data Object List, tag
`9F38`) is a list of tags that the *card* requires the *terminal* to hand over before the
card will agree to process anything. When a PDOL is present, the terminal is obliged to
send the values of the requested tags in the GPO command. ([EMV transaction flow — PDOL & contactless](https://mstcompany.net/blog/acquiring-emv-transaction-flow-part-4-pdol-and-contactless-cards-characteristic-features-of-qvsdc-and-quics), [GPO with and without PDOL](https://mstcompany.net/blog/acquiring-emv-transaction-flow-part-3-get-processing-options-with-and-without-pdol))

And one of the tags a card is entitled to request is:

> **`9F15` — Merchant Category Code.** *"Classifies the type of business being done by the
> merchant, represented according to ISO 8583:1993 for Card Acceptor Business Code."*
> Source: **terminal**. Length: 2 bytes (packed BCD, 4 digits).
> ([EMV Lab tag 9F15](https://emvlab.org/emvtags/show/t9F15/))

The PDOL is explicitly documented as being able to carry *"data objects describing the
business environment at the point of service"* — which is precisely what `9F15` is.

**Therefore:** an Android phone running Host Card Emulation, presenting itself as a payment
card whose PDOL requests `9F15`, will be handed the merchant category code by the terminal
— **as part of normal, spec-compliant EMV processing.** No exploit. No relay. No
interception. We are simply a card that asks a question cards are allowed to ask.

### 3.3 The SWIP "Listen" AID profile

SWIP registers a payment AID via Android HCE and responds to `SELECT AID` with an FCI whose
PDOL requests the full point-of-service context:

| Tag | Field | Why we want it |
|---|---|---|
| **`9F15`** | **Merchant Category Code** | **The answer** |
| `9F16` | Merchant Identifier (15 char) | Stable merchant key for Vector 6, even when 9F15 is blank |
| `9F1C` | Terminal Identification | Distinguishes lanes at one merchant |
| `9F4E` | Merchant Name and Location | Human-readable label |
| `9F1A` | Terminal Country Code | Nationally- vs internationally-acquired (`D-05`!) |
| `5F2A` | Transaction Currency Code | ditto |
| `9F02` | Amount, Authorised | Shows the user what would have been charged |
| `9A` / `9F21` | Transaction Date / Time | Ledger timestamp from the terminal itself |
| `9F35` | Terminal Type | Attended/unattended, merchant/cardholder-operated |
| `9F33` | Terminal Capabilities | Card-present context |
| `9F37` | Unpredictable Number | Required for a well-formed exchange |

Then — and this is the whole ethical design — **SWIP terminates the conversation.**
After capturing the GPO command data, the service returns `SW=6985` (*conditions of use
not satisfied*) and stops. The terminal displays a read error and prompts the merchant to
retry with a real card.

> **No transaction is created. No amount is authorised. No PAN exists. No money moves.**
> This is exactly what you described in `C-13`: *"they get their payment declined because
> there wouldn't be any payment done… it's not related to payments or money."*
> You described it for the virtual card. It is even truer here.

### 3.4 What is verified, and what must be field-tested

I will not oversell this. Here is the honest split.

**Verified from primary specs:**
- ✅ `9F15` exists, is the MCC, and its source is the terminal. ([EMV Lab](https://emvlab.org/emvtags/show/t9F15/))
- ✅ The PDOL mechanism lets a card demand terminal data objects, including
  point-of-service business-environment objects, and the terminal supplies them in GPO.
- ✅ Android HCE can present a payment AID and hold a full APDU conversation with a real
  POS terminal — there are working open-source implementations.
  ([AndroidCrypto/Android_HCE_Emulate_A_CreditCard](https://github.com/AndroidCrypto/Android_HCE_Emulate_A_CreditCard))

**UNVERIFIED — field test required:**
- ⚠️ **What fraction of real terminals have a non-zero `9F15` provisioned in the EMV
  kernel?** EMV requires the terminal to supply *something* of the right length for every
  PDOL tag it is asked for; if the kernel has no value configured it supplies zeros. MCC
  is always present in the *acquirer host* configuration, but it is not guaranteed to be
  pushed down into the terminal's kernel data store. **This is the one number that decides
  how good this feature is, and it cannot be looked up — it must be measured.**
- ⚠️ Whether `9F4E` (Merchant Name and Location) is populated by contactless kernels; it is
  more commonly a contact-interface element.
- ⚠️ Per-OEM Android AID-routing behaviour when Google Wallet is also installed.

**Field-test protocol — do this in week 1, before anything else:**

1. Build the `swip-probe` debug APK (`app/android/.../SwipListenService.kt`, already in
   this repo) with verbose APDU logging.
2. Tap **50 terminals** across a deliberately mixed sample: 10 large-format retail
   (Reliance/DMart-class), 10 QSR, 10 standalone Pine Labs/Ezetap merchants, 10 fuel/
   transit/unattended, 10 international if reachable.
3. Record for each: acquirer (from the terminal sticker), terminal make/model, and whether
   `9F15` came back non-zero.
4. **Decision gate:** if ≥ 40 % of terminals return a real `9F15`, Vector 2 is a headline
   feature and the product's differentiator. If < 15 %, demote it to a "bonus" capture and
   put the weight on Vector 6. Between the two, ship it as "works at many terminals" with
   an honest in-app hit-rate indicator.
5. Regardless of the `9F15` rate, `9F16` + `9F1C` + `9F1A` will almost always come back —
   which alone is enough to key Vector 6. **The feature has a floor.**

### 3.5 iOS reality `B-02`

You wanted both platforms. On this specific feature you cannot have both, and here is why.

Apple opened the NFC/Secure Element platform to third parties in **iOS 18.1**. But:
**HCE-based contactless transactions are available only in the European Economic Area.**
In Australia, Brazil, Canada, Japan, New Zealand, the UK and the US, Apple exposes
Secure-Element-based access instead, not HCE. And the entitlement requires Apple approval
plus PCI DSS compliance of the developer. ([Apple — HCE transactions in the EEA](https://developer.apple.com/support/hce-transactions-in-apps), [Apple — NFC & SE Platform](https://developer.apple.com/support/nfc-se-platform), [AtaDistance](https://atadistance.net/2024/08/19/ios-18-1-open-secure-element-and-nfc-transaction-clash-fun/))

**India is in neither list.** Therefore:

- **Android:** Vectors 1, 2, 3, 6 — full product.
- **iOS:** Vectors 1, 3, 6 — the Tap tab is replaced by an explainer card that says why,
  with a "notify me" toggle. Not hidden, not faked. Users respect a clear "Apple doesn't
  allow this yet" far more than a mysteriously missing feature.

This validates your instinct in `B-02` to lead with Android.

---

## 4. Vector 3 — payment links  `C-07` `C-08`

### 4.1 The bad news, stated plainly

You asked how the link scenario works. Here is the honest answer:

> **The MCC is not in the payment link. It cannot be. It is not data the merchant holds —
> it is data the merchant's *acquirer* holds about the merchant.**

When a merchant onboards to Razorpay, Stripe or Cashfree, the PSP classifies the business
and assigns an MCC in its own records. That MCC is injected into the ISO 8583 authorization
message at transaction time, on the server, at field 18. A `rzp.io/l/abc123` URL contains a
payment-link ID and nothing more.

So `C-08` — *"people put their info in and simply get the MCC"* — is accurate about the
merchant's experience but it happens on the PSP's server, invisibly, and there is no
consumer-facing API for it.

### 4.2 The good news — what *is* extractable

A payment link is still rich in **stable merchant identity**, which is exactly what Vector 6
needs. SWIP's link resolver extracts, without any credential:

| PSP | Stable key SWIP extracts | Where from |
|---|---|---|
| Razorpay | `rzp_live_xxxxxxxx` merchant key; merchant display name; logo URL | Checkout config on the link page |
| Stripe | `pk_live_…` publishable key; `acct_…` connected-account id; statement descriptor | Checkout session page |
| Cashfree | App ID / form slug; merchant name | Form page |
| PayPal / Paddle / Lemon Squeezy | Merchant/seller id | Page metadata |
| Generic | Registrable domain, OpenGraph title, favicon hash | HTML head |

That `(psp, merchant_key)` tuple is a **globally unique, permanent merchant identifier.**
The first SWIP user who pays that link and confirms the outcome pins the MCC for everyone
who ever opens that link again. That is Vector 6 doing the work.

### 4.3 The v1 answer SWIP actually ships

A **confidence-scored inference**, never a bare guess:

```
   ┌──────────────────────────────────────────────┐
   │  🔗  pages.razorpay.com/luxeflorist          │
   ├──────────────────────────────────────────────┤
   │  MCC  5992   Florists                        │
   │  ● Likely — 78 %                             │
   │                                              │
   │  Based on:                                   │
   │   • 3 SWIP users confirmed this merchant     │
   │   • Razorpay merchant key rzp_live_Lq…       │
   │   • Category signals from the page           │
   │                                              │
   │  ⓘ Not certain. Payment links never carry    │
   │    the MCC — it lives with the acquirer.     │
   │                                              │
   │  [ I paid — tell us what posted ]            │
   └──────────────────────────────────────────────┘
```

**The `I paid — tell us what posted` button is the entire growth loop.** It is the cheapest
possible contribution: the user already knows the answer two days later when the charge hits
their statement, and telling SWIP costs them one tap.

### 4.4 The v2 definitive answer

Route the payment through SWIP's own merchant-of-record or through the Probe Card
(Vector 4), and you are on the issuing side of the message, where field 18 is right there.

---

## 5. Vector 4 — the Probe Card  `C-09` `C-10` `C-12` `C-13`

This is your best idea in the entire brief and it deserves a careful answer.

### 5.1 Why it works

Every card authorization is an **ISO 8583** message. Two fields matter:

- **Field 18 — Card Acceptor Business Code.** *This is the MCC.*
- **Field 43 — Card Acceptor Name / Location.** The merchant name and city.

The issuer receives this message *before deciding whether to approve.* So an issuer — or an
issuer-processor acting for one — sees the MCC of an attempted transaction **at the moment
of the attempt**, and can decline it, and the merchant simply sees "declined". Which is
precisely your `C-13`: *the payment gets declined because there wouldn't be any payment
done; my system simply captures the payment that is tried.*

This is not theoretical. It is a **shipping product category** called real-time
authorization decisioning:

- **Lithic — Auth Stream Access (ASA).** A real-time HTTP interface to the authorization
  stream. Lithic delivers the full transaction payload — merchant id, descriptor, **MCC**,
  point-of-sale data, network fields — to your endpoint, and your response decides approve
  or decline. Declines carry reason codes such as `AUTH_RULE_BLOCKED_MCC`.
  ([Lithic — Authorization Intelligence](https://docs.lithic.com/docs/about-authorization-intelligence), [Lithic — real-time auth decisioning](https://www.lithic.com/blog/real-time-authorization-decisioning-now-available-in-sandbox))
- **Marqeta — JIT Funding + dynamic spend controls.** MCC-based restriction and real-time
  webhooks on transaction events. ([Marqeta — dynamic spend controls](https://www.marqeta.com/blog/rule-the-spend-from-start-to-end-real-time-customization-and-protection), [Marqeta — about transactions](https://www.marqeta.com/docs/developer-guides/about-transactions))
- **Stripe Issuing** exposes `merchant_data.category` and `merchant_data.category_code` on
  its real-time authorization webhook.

So: **build a card whose entire purpose is to decline, and report why.** A card that is
not a payment instrument at all — it is a *sensor*. You called it exactly right:
*"it's not related to payments or money."*

### 5.2 The naming

Do not call it a virtual card. Call it what it is:

> ### 🪪 **SWIP Probe** — *the card that never pays.*
> Tap it, dip it, or type it into a checkout. It always declines.
> It comes back with the MCC.

This framing solves three problems at once: it sets user expectations so a decline is a
success not a failure; it is honest to regulators; and it is genuinely differentiated
marketing.

### 5.3 What actually blocks you (`C-12` answered)

You asked whether it needs to be issued *by Visa or Mastercard* and wanted a workaround.
**The network is not the blocker.** Visa and Mastercard do not issue cards; banks do, under
a network licence. The blocker is the **issuer licence and the BIN**.

| Route | What it is | Time | Capital | Verdict |
|---|---|---|---|---|
| **A. Offshore issuer-processor** | Lithic / Stripe Issuing / Highnote / Marqeta on a US or EU programme. Cards are USD/EUR virtual cards | 4–10 weeks | Low (programme fees + a funding float) | ✅ **Do this first.** It is the fastest possible path to a working Probe Card, it proves the concept, and it *already works today for international e-commerce and payment links* — which is a chunk of `C-07` |
| **B. India: BaaS + sponsor bank** | A prepaid programme through an orchestrator (M2P, Zeta and similar) riding a sponsor bank's BIN (SBM, RBL, Yes, IndusInd, Federal, Utkarsh have all done fintech programmes). Fintechs issue prepaid/debit/credit and co-brand cards this way routinely — CRED×IndusInd, Scapia×Federal, PhonePe×HDFC, super.money×Axis. ([M2P](https://productgrowth.in/tools/banking-api/m2p/), [BIN sponsorship explained](https://sdk.finance/blog/bin-sponsorship-a-key-to-unlocking-card-issuance-in-fintech/), [Scapia×Federal](https://www.scapia.cards/newsroom/summer-release2025), [CRED×IndusInd](https://www.indusind.bank.in/in/en/about-us/mediabrand/FY/2025-2026/September/launch-of-cred-indusInd-bank-rupay-credit-card.html)) | 6–12 months | Medium — sponsor's diligence, not your balance sheet | ✅ **Do this second**, and only after Vector 2 has proven demand |
| **C. Own PPI licence** | RBI authorisation as a non-bank PPI issuer | 12–24 months | **₹5 cr net worth at application, ₹15 cr by end of year 3**, escrow with a scheduled commercial bank, quarterly auditor certification ([Draft RBI (PPI) Directions, 2026](https://www.medianama.com/2026/04/223-rbi-prepaid-payment-instruments-rules-wallet-limits-escrow-norms/), [Lexology](https://www.lexology.com/library/detail.aspx?g=35cfed04-f062-4c1e-9e38-7294773aa014), [Compliance Calendar](https://www.compliancecalendar.in/learn/ppi-license)) | ❌ **Not now.** This is a Series-A decision, not a v1 decision |

> ⚠️ **A live regulatory watch item.** The RBI issued **Draft PPI Directions on 22 April
> 2026** (comments closed 22 May 2026), covering capital, wallet limits (₹2 lakh), escrow
> norms and mandatory interoperability. Anything you build on route B or C must be
> re-checked against the final Directions before launch. Owner: whoever runs compliance.

### 5.4 The zero-cost interim: Probe Mode on the user's *own* card

Before any card exists, SWIP can ship 80 % of the value with none of the licensing:

**"Probe Mode"** — SWIP walks the user through a deliberate ₹1–₹10 transaction at the
merchant they're curious about, then, 24–72 h later, when it posts, prompts:
*"Your ₹1 probe at Blue Tokai — what category did it post as?"* The user answers once.
Everyone else gets it free, forever, via Vector 6.

Crude. Slow. Costs the user ₹1. **And it is exactly what the community does today by
hand** — SWIP just makes it one tap instead of a phone call to customer support (`C-11`).

### 5.5 Honest constraints on the Probe Card

I am flagging these because a finance product that ignores them gets shut down.

1. **Every probe is a real authorization attempt.** It consumes acquirer capacity and
   shows the merchant a decline. **Rate-limit hard:** N probes per user per day, one per
   merchant per 30 days, and a global circuit-breaker per acquirer.
2. **Card-testing detection.** Repeated declines across many merchants from one BIN looks
   exactly like carding to network fraud systems. This must be disclosed to the
   issuer-processor **in the programme application**, not discovered by them later. Lithic
   and Stripe Issuing both have programme-approval processes; declare the use case.
3. **Never $0-auth.** A zero-amount authorization is an account-verification message; it is
   handled differently and cannot be captured. ([Cybersource](https://developer.cybersource.com/docs/cybs/en-us/payments/developer/fdiglobal/so/payments/payments-processing-basic-intro/payments-processing-basic-zero-auth-intro.html)) Use a small non-zero amount and decline it.
4. **Disclose in-app** what a probe does, before the first one.

---

## 6. Vector 6 — the merchant graph *(this is the business)*

Not one of your explicit ideas, but it is the necessary consequence of all of them, and it
is what makes SWIP a company rather than a utility.

Every capture from every vector writes one row:

```
merchant_key   ← (psp, merchant_id) | 9F16+9F1A | UPI VPA | QR merchant account tmpl
mcc            ← 4 digits
publication    ← {national | international | rupay}
source_vector  ← qr | nfc | probe | link | user_confirmed
confidence     ← f(vector authority, agreement count, recency, reporter reputation)
geohash        ← coarse, 5-char (~4.9 km) — never precise location
observed_at
```

Consequences, in order of importance:

1. **It answers the unanswerable case.** Your hardest scenario (`C-06`) — no QR, must hand
   over the card — has no live capture path. But if any SWIP user has ever tapped that
   terminal, scanned that counter QR, or confirmed that statement line, **SWIP already
   knows.** The user opens the app and it says *"Blue Tokai, Powai — MCC 5812, Eating
   Places. Confirmed by 47 captures, most recent 3 days ago."*
2. **It compounds.** Static directories decay. A crowd-verified graph with recency
   weighting improves with every user. That is a real moat.
3. **It is the pitchable asset.** *"We have the world's only merchant-verified,
   terminal-level MCC graph"* is a fundable sentence. *"We parse QR codes"* is not.
4. **It seeds from public data on day one** so it is never empty: the Visa Developer
   Merchant Search and Mastercard merchant-identifier/locations APIs return category data
   for known merchants; Google Places categories map to MCC ranges; published issuer
   exclusion lists (e.g. Kotak's public MCC fee/reward list) enumerate the codes Indian
   issuers actually care about. ([Kotak MCC list PDF](https://www.kotak.bank.in/content/dam/Kotak/gsfcfiles/credit-cards/list-of-mccs-with-respect-to-revised-fees-and-rewards_june_01_2025.pdf), [Axis announcements](https://www.axis.bank.in/important-links/credit-card/important-announcement-on-credit-card))

**Privacy floor, non-negotiable for a finance app:** contributions are merchant-keyed, never
user-keyed; location is coarse geohash only; amounts are never uploaded; contribution is
opt-in with a visible toggle in Settings; and the local ledger works fully with sync off.

---

## 7. The 6540 problem  `E-04`

You said *"wallets are expensive, so it's included in all these types of applications"*.
Confirmed, and here is the specific number.

**Wallet loads code as MCC `6540` — "Stored Value Card Purchase/Load".** Indian issuers
almost universally exclude it from rewards *and* from milestone/annual-fee-waiver spend
accounting. Axis explicitly identifies wallet MCC as 6540 and excludes rent and wallet
spends from the fee-reversal threshold; Kotak publishes an MCC list governing revised fees
and reward exclusions. Loading Amazon Pay balance via a third party has been observed
posting as 6540 and earning nothing. Related codes — `6050`/`6051` quasi-cash, `4829` money
transfer — are excluded the same way. The pattern is global, not Indian: Singapore issuers
killed GrabPay top-up earning in 2020 for the same reason.
([Kotak MCC list](https://www.kotak.bank.in/content/dam/Kotak/gsfcfiles/credit-cards/list-of-mccs-with-respect-to-revised-fees-and-rewards_june_01_2025.pdf), [Axis](https://www.axis.bank.in/important-links/credit-card/important-announcement-on-credit-card), [Monzy India MCC list](https://blog.monzy.co/credit-card-guides/merchant-category-code-list-india-2025/), [The MileLion on GrabPay](https://milelion.com/2020/07/21/rip-no-more-credit-card-points-for-grabpay-top-ups/))

**So your instinct in `E-05` — "find a way to term this wallet so it carries a travel MCC" —
is aimed at exactly the right problem.** The method needs correcting, and that correction is
the heart of the business-model document. Continue to
[04-BUSINESS-MODEL §5](04-BUSINESS-MODEL.md#5-the-mcc-question-answered-honestly).

---

## 8. Vector 5 — statements, SMS and email (and why SWIP does *not* lead with it)

The obvious idea — read the bank's transaction SMS — is a **trap on Android**, and you
should know before you spend a sprint on it.

Google Play restricts `READ_SMS`/`RECEIVE_SMS` to apps that are the **default SMS handler**,
and permits them only for documented core functionality. Financial apps that auto-import
bank SMS to build a transaction list have been **explicitly rejected**, with Google's
reasoning that SMS is not core functionality for a non-SMS app. Google's guidance is to use
the SMS Retriever API or the Digital Credentials API instead — neither of which can read
arbitrary bank alerts. ([Play Console — SMS/Call Log policy](https://support.google.com/googleplay/android-developer/answer/10208820?hl=en), [Play Console — sensitive permissions](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en), [Bluecoins' account of removal](https://www.bluecoinsapp.com/google-policy-removing-sms-permissions/))

And it wouldn't even pay off: **bank SMS almost never contains the MCC.** It contains an
amount and a narration string.

**SWIP's stance:** no SMS permission, ever. Instead, `S-14 Confirm a capture` lets the user
paste or photograph a statement line, and an on-device parser extracts the narration to
strengthen the merchant graph. Zero permissions, zero policy risk, and — because the user
is *choosing* to contribute — better data.

*(For India, the RBI **Account Aggregator** framework is the compliant long-term path to
statement data. It yields narration, not MCC, so it is a Vector-6 enrichment source, not a
capture vector. Phase 3.)*

---

## 9. Summary: what ships when

| Vector | v1 (this repo) | v2 | v3 |
|---|---|---|---|
| 1. QR (global EMVCo + UPI URI) | ✅ full | | |
| 2. NFC tap (Android) | ✅ full | iOS EEA if entitled | |
| 3. Payment links | ✅ inference + confirm loop | definitive via probe/MoR | |
| 4. Probe Card | Probe Mode on own card | ✅ offshore issuer | India BaaS |
| 5. Statements | manual confirm only | | Account Aggregator |
| 6. Merchant graph | ✅ local + opt-in sync | ✅ network APIs seeded | licensing revenue |

---

## Sources

- [ISO 18245:2023 — Merchant category codes](https://www.iso.org/standard/79450.html) · [ISO 18245 (Wikipedia)](https://en.wikipedia.org/wiki/ISO_18245) · [Merchant category code (Wikipedia)](https://en.wikipedia.org/wiki/Merchant_category_code) · [Classification.Codes — MCC](https://classification.codes/classifications/industry/mcc/)
- [EMVCo — Merchant-Presented QR Codes](https://www.emvco.com/processes/merchant-presented-qr-codes/) · [EMVCo MPM Specification v1.1 (PDF)](https://mvallim.github.io/emv-qrcode/docs/EMVCo-Merchant-Presented-QR-Specification-v1.1.pdf) · [EMVCo — QR guidance & examples](https://www.emvco.com/resources/merchant-presented-qr-guidance-and-examples/) · [EMV QR payload format](https://emvqrhub.com/learn/emv-qr-payload-format/) · [QR interoperability](https://emvqrhub.com/learn/qr-interoperability/)
- [NPCI UPI Linking Specification 1.6 (PDF)](https://www.labnol.org/files/linking.pdf) · [NPCI UPI QR specification guide](https://qrcrack.com/blog/upi-qr-codes-india-npci-specification) · [BharatQR](https://en.wikipedia.org/wiki/BharatQR) · [UPI–BharatQR integration handbook](https://hasgeek.gitbook.io/50p-handbook/upi-bharat-qr-integration)
- [HKMA Common QR Code Specification (PDF)](https://www.hkma.gov.hk/media/eng/doc/key-functions/financial-infrastructure/infrastructure/retail-payment-initiatives/Common_QR_Code_Specification.pdf) · [QRIS](https://en.wikipedia.org/wiki/QRIS) · [Thai QR Payment](https://en.wikipedia.org/wiki/Thai_QR_Payment) · [World Bank — QR codes in payments (PDF)](https://fastpayments.worldbank.org/sites/default/files/2021-10/QR_Codes_in_Payments_Final.pdf) · [Kapronasia — Alipay/WeChat QR](https://www.kapronasia.com/china-payments-research-category/qr-codes-helped-define-alipay-and-wechat-pay-but-now-they-might-be-their-biggest-challenge.html)
- [EMV Lab — tag 9F15 Merchant Category Code](https://emvlab.org/emvtags/show/t9F15/) · [EMV transaction flow: GPO with/without PDOL](https://mstcompany.net/blog/acquiring-emv-transaction-flow-part-3-get-processing-options-with-and-without-pdol) · [EMV transaction flow: PDOL & contactless](https://mstcompany.net/blog/acquiring-emv-transaction-flow-part-4-pdol-and-contactless-cards-characteristic-features-of-qvsdc-and-quics) · [How to read contactless EMV cards](https://lifecycleintegrity.com/how-to-read-payment-cards/)
- [Android HCE credit-card emulation tutorial](https://medium.com/@androidcrypto/how-to-emulate-a-credit-card-on-android-with-host-based-card-emulation-hce-in-java-0652342da0f1) · [AndroidCrypto/Android_HCE_Emulate_A_CreditCard](https://github.com/AndroidCrypto/Android_HCE_Emulate_A_CreditCard) · [Host card emulation (Wikipedia)](https://en.wikipedia.org/wiki/Host_card_emulation)
- [Apple — HCE transactions in the EEA](https://developer.apple.com/support/hce-transactions-in-apps) · [Apple — NFC & SE Platform](https://developer.apple.com/support/nfc-se-platform) · [AtaDistance — iOS 18.1 open SE](https://atadistance.net/2024/08/19/ios-18-1-open-secure-element-and-nfc-transaction-clash-fun/)
- [Lithic — About Authorization Intelligence](https://docs.lithic.com/docs/about-authorization-intelligence) · [Lithic — real-time authorization decisioning](https://www.lithic.com/blog/real-time-authorization-decisioning-now-available-in-sandbox) · [Marqeta — dynamic spend controls](https://www.marqeta.com/blog/rule-the-spend-from-start-to-end-real-time-customization-and-protection) · [Marqeta — about transactions](https://www.marqeta.com/docs/developer-guides/about-transactions) · [Cybersource — zero-amount authorization](https://developer.cybersource.com/docs/cybs/en-us/payments/developer/fdiglobal/so/payments/payments-processing-basic-intro/payments-processing-basic-zero-auth-intro.html)
- [Draft RBI PPI Directions 2026 — Medianama](https://www.medianama.com/2026/04/223-rbi-prepaid-payment-instruments-rules-wallet-limits-escrow-norms/) · [Lexology — draft PPI directions](https://www.lexology.com/library/detail.aspx?g=35cfed04-f062-4c1e-9e38-7294773aa014) · [PPI licence guide](https://www.compliancecalendar.in/learn/ppi-license) · [SDK.finance — BIN sponsorship](https://sdk.finance/blog/bin-sponsorship-a-key-to-unlocking-card-issuance-in-fintech/) · [M2P Fintech](https://productgrowth.in/tools/banking-api/m2p/) · [Scapia × Federal Bank](https://www.scapia.cards/newsroom/summer-release2025) · [CRED × IndusInd](https://www.indusind.bank.in/in/en/about-us/mediabrand/FY/2025-2026/September/launch-of-cred-indusInd-bank-rupay-credit-card.html)
- [Kotak — MCC list for revised fees & rewards (PDF)](https://www.kotak.bank.in/content/dam/Kotak/gsfcfiles/credit-cards/list-of-mccs-with-respect-to-revised-fees-and-rewards_june_01_2025.pdf) · [Axis — credit card announcements](https://www.axis.bank.in/important-links/credit-card/important-announcement-on-credit-card) · [Monzy — India MCC list 2026](https://blog.monzy.co/credit-card-guides/merchant-category-code-list-india-2025/) · [The MileLion — GrabPay top-ups](https://milelion.com/2020/07/21/rip-no-more-credit-card-points-for-grabpay-top-ups/) · [The MileLion — how to check MCCs](https://milelion.com/2025/01/19/how-to-check-merchant-category-codes-mccs-before-making-a-purchase/) · [SuiteSmile — check MCC before paying](https://suitesmile.com/blog/2025/06/05/how-to-check-merchant-category-code-mcc-before-paying/) · [AwardWallet merchant lookup](https://awardwallet.com/merchants)
- [Play Console — SMS/Call Log permission policy](https://support.google.com/googleplay/android-developer/answer/10208820?hl=en) · [Play Console — sensitive permissions & APIs](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en) · [Bluecoins — Google SMS permission removal](https://www.bluecoinsapp.com/google-policy-removing-sms-permissions/)
- [Visa Acceptance — MCC](https://support.visaacceptance.com/knowledgebase/knowledgearticle/?code=KA-09260) · [Stripe — MCC guide](https://stripe.com/guides/merchant-category-codes)
