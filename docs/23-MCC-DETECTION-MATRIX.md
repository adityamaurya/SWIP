# The MCC detection matrix — every way SWIP can know

> `F-57`. *"ME A SUPER LIST WHERE IN WE HAVE SUPPORTED WAYs WE ARE IDENTIFYING
> THE MCC FROM THESE SCENARIOS"*
>
> One row per route. What it reads, where the value physically comes from, how
> often it works, and **what makes it fail** — because a route that fails silently
> is worse than one that never existed.
>
> Confidence words mean exactly what they mean everywhere else in SWIP:
> **Verified** = read from the transaction · **Likely** = inferred ·
> **Unknown** = SWIP does not know and says so.

---

## The one-line summary

**An MCC is assigned by the acquiring bank when a merchant is onboarded.** It is
not a property of a shop, a QR, or a payment. It shows up in some payloads and
not others, and no amount of parsing conjures it into a payload that does not
carry it. Every route below is a different place the same assigned value surfaces.

---

## A. Routes that **read** the code — Verified

| # | Route | Reads | Where the value comes from | Works when | Fails when |
|---|---|---|---|---|---|
| **A1** | **POS terminal tap** — Vector 2 | EMV tag `9F15` | The terminal's own kernel, provisioned by the acquirer | The merchant is P2M/card-acquired, has a contactless terminal, and **SWIP is the default contactless payment app** | No terminal · terminal's `9F15` unprovisioned (returns zeros) · another wallet holds the default-payment slot · no HCE hardware · iOS |
| **A2** | **EMVCo merchant QR** (BharatQR, PIX, QRIS, PayNow, PromptPay, DuitNow, VietQR, +30) | TLV tag `52` | Written into the code by the acquirer at issuance | The sticker is EMVCo and the acquirer populated tag 52 | Payload fails CRC · tag 52 absent or `0000` · it is a UPI-intent QR, not EMVCo |
| **A3** | **UPI intent QR with `mc`** | `mc` query parameter | Set by the merchant's PSP | The PSP writes `mc` — many do | **P2PM merchant: no MCC exists** · PSP omits it · `mc=0000` |
| **A4** | **Pay-by-app intent** — Vector 7 | `mc` in the `upi://pay` intent | The merchant's own PSP, at checkout | The checkout uses Android's real chooser | Checkout uses an SDK allowlist — [most big apps do](20-FEEDBACK-ROUND-2.md) |
| **A5** | **Share-to-SWIP, text** — `S-24` | Whatever the shared string carries | As A3/A4 | The checkout exposes a copy/share action | Nothing shareable on screen |
| **A6** | **Share-to-SWIP, screenshot** — `S-24` | The QR inside the image | As A2/A3 | The screen actually shows a code | The screen shows a list of apps, not a code |

## B. Routes that **remember** — Verified or Likely

| # | Route | Reads | Works when | Fails when |
|---|---|---|---|---|
| **B1** | **Merchant graph** — Vector 6 | The stored answer for this merchant key | This merchant has been captured before by any route | First encounter · the key does not match |
| **B2** | **Merchant reconciliation** — `F-49` 📋 | Links a POS capture to a QR capture at the same place and time | Location is on and both captures are in the same cell | Location off · captures far apart in time |
| **B3** | **You told SWIP** — Vector 5 | Four digits you typed | You read them off a statement | — |
| **B4** | **The ₹1 statement loop** — `F-50` 📋 | The MCC your bank prints on the statement | Your bank shows it — **Federal Bank does** | Bank does not print the MCC |

## C. Routes that **infer** — Likely, never Verified

| # | Route | Reads | Honest limit |
|---|---|---|---|
| **C1** | **Payment link** — Vector 3 | PSP + merchant slug | An MCC is **never** encoded in a URL. This identifies the merchant so B1 can answer next time |
| **C2** | **Merchant tier from handle** — `F-46` | `paytmqr…` vs `paytm.s…` | Gives *P2M or P2PM*, and therefore *whether an MCC can exist at all* — not the code itself. n=3, labelled as a hypothesis |
| **C3** | **Known-category merchants** | A wallet top-up posts as `6540` | A strong prediction, not a reading |

## D. Routes SWIP **will not** take

| # | Route | Why not |
|---|---|---|
| **D1** | **NPCI ValidateAddress** (`ReqValAdd`) | **This is how CRED does it.** It needs TPAP certification, a sponsor bank and NPCI membership. Becoming a PSP would drag SWIP into RBI's PPI regime, which the whole architecture exists to stay out of — [12-COMPLIANCE-RISK](12-COMPLIANCE-RISK.md) |
| **D2** | **Reading bank SMS** | Play policy restricts SMS to default handlers and has rejected finance apps for it. And bank SMS carries a narration, not an MCC — [03-RESEARCH §8](03-RESEARCH-MCC-CAPTURE.md) |
| **D3** | **Screen-scraping other apps** | Accessibility-service abuse. A hard no |
| **D4** | **Guessing from the shop's name** | "Café" in a name is not a category. Guessing in grey is the exact failure SWIP exists to replace |

---

## Which route fires, in order

```
payload
  ├─ UPI intent?      → mc present?        → A3  Verified
  │                   → handle tier        → C2  (can an MCC even exist?)
  ├─ EMVCo TLV?       → CRC ok? tag 52?    → A2  Verified
  ├─ payment link?    → PSP + slug         → C1  Likely
  └─ none of these    → named for what it is, no invented category

then, whatever the payload gave:
  merchant key known? → B1  fills a blank, or flags a conflict
  still blank?        → offer B2 / B4 — the ways to teach it permanently
```

---

## The uncomfortable table

Where each route stands **today**, on real Indian shops:

| Scenario | Best route | Result |
|---|---|---|
| Snowberry — POS terminal | A1 | ✅ **MCC read.** Proven at the counter |
| Snowberry — their Paytm QR | A3 → B2 | ⚠️ No `mc`; needs reconciliation with the tap |
| "Best Wishes" — P2PM sticker | C2 | ✅ Correctly says *no category exists, and RuPay CC will not work* |
| Akruti Enterprise — soundbox | C2 → B4 | ⚠️ P2M, so an MCC exists somewhere; ₹1 loop gets it |
| A bank BharatQR sticker | A2 | ✅ Usually works |
| Swiggy / PVR checkout | A5 / A6 | ⚠️ One extra tap; A4 is closed |
| Wallet top-up | C3 | ✅ Predicts `6540` and warns it will earn nothing |
| A friend's GPay code | — | ✅ Correctly says *a person, not a shop* |

**The honest state of play:** SWIP reads the code wherever the code exists, says
so plainly wherever it does not, and now has two routes — reconciliation and the
₹1 loop — to permanently learn the ones that are missing. What it will not do is
manufacture a number, which is the one thing that would make it worse than
useless.

---

## Sources

- [NPCI — RuPay Credit Card on UPI FAQs](https://www.npci.org.in/what-we-do/rupay/rupay-credit-card-on-upi/faqs)
- [Razorpay — RuPay Credit Card on UPI](https://razorpay.com/docs/payments/payment-methods/upi/cc-on-upi/)
- [P2PM inward credit limits and the move to P2M with applicable MCCs](https://taxguru.in/finance/implementation-maximum-upi-credit-limits-p2pm-merchants.html)
- [UPI QR specification — `pa`, `pn`, `mc`, `mode`, `orgid`, `sign`](https://qrcrack.com/blog/upi-qr-codes-india-npci-specification)
- [UPI Procedural Guidelines (NPCI)](https://yashada.org/yashada_2019/pdfs/e_library_cit/edpri_UPI_Procedural_Guidelines.pdf)
- [Merchant category code — overview](https://en.wikipedia.org/wiki/Merchant_category_code)
