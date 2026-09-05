# 29 — Why those QRs would not scan

> *"there are multiple issues where in the scanner won't scan few qr codes
> despite them either having a merchant qr with rupay cc enabled and then qrs
> with being a merchant qr but they have disabled the payment to the merchant
> qr deiabled"*

I decoded every QR you sent, from the photographs, before writing a line of
code. Three separate faults, not one. **Two of them are in SWIP.**

---

## 1. What is actually inside your QRs

Decoded with OpenCV from the original photographs. These are the exact payloads
your phone was pointed at.

### 1.1 Shree Beauty Centre — SVC Co-operative Bank

```
upi://pay?pa=SVCMERC00306934@svcbank&pn=SVCMERC00306934&mc=&tr=00306934
        &tn=&am=&mam=&cu=INR&refUrl=https://svcbank.com/
```

Read that again: **`mc=`**. Not absent. **Present and empty.**

This is the single most informative payload in the set, and SWIP was throwing
the information away:

| Signal | Value | What it means |
|---|---|---|
| `pa=SVCMERC00306934@svcbank` | `…MERC…` | A **bank-acquired merchant**. SVC Co-operative Bank mints `SVCMERC` + merchant ID for onboarded businesses. This is not a person |
| `mc=` | empty | The acquirer built a merchant QR **and left the category blank**. That is a bank operations failure, not a small-merchant tier |
| `tr=00306934` | present | A merchant reference |
| `refUrl` | `svcbank.com` | The acquiring bank names itself |

And the payment failed with *"merchant doesn't accept credit cards or overdraft
accounts"*. So: a **real, fully acquired merchant, whose acquirer has not
enabled credit-card-on-UPI, and did not publish a category.** Three different
facts, and SWIP could state all three from the QR alone.

What SWIP did instead: `_clean()` turns `""` into `null`, `mcc` returns `null`,
`hasMalformedMcc` returns `false`. The empty `mc=` was indistinguishable from a
QR that never had the field. **Fixed** — see §3.2.

### 1.2 Wellness Forever — the Pine Labs terminal (`PC-32`)

```
upi://pay?pa=WFMLMH2@ybl&pn=WELLNESS%20FOREVER%20MH%202&am=76.66&mam=76.66
        &tr=PINE2269706791&tn=Payment%20for%202053457707
        &mc=5912&mode=15&purpose=00&invoiceNo=26203S25030
```

**`mc=5912`. Drug Stores and Pharmacies.** It is right there.

This is the proof that dynamic POS QRs *do* carry the category. `mode=15` is a
dynamic merchant QR; `tr=PINE…` names Pine Labs as the terminal vendor. This one
should have worked — and the reason it did not is §2, not the payload.

### 1.3 The Paytm sticker

```
upi://pay?pa=paytmqr70ivq3@ptys&pn=Paytm
```

Two fields. No `mc`, no `mode`, no `sign`. `@ptys` is Paytm's small-merchant
handle. SWIP's existing reading — *"A real shop, no category published"* plus
the RuPay warning — is **correct**, and stays.

---

## 2. The bug that made the scanner go dead: `noDuplicates`

This is the big one, it explains the force-quit, and it is four words of
configuration.

Both `live_viewfinder.dart` and `scan_page.dart` created their controller with:

```dart
MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, …)
```

Here is what that does inside the plugin, from
`mobile_scanner-5.2.3/android/src/main/kotlin/…/MobileScanner.kt`:

```kotlin
private var lastScanned: List<String?>? = null
…
if (detectionSpeed == DetectionSpeed.NO_DUPLICATES) {
    val newScannedBarcodes = barcodes.mapNotNull { it.rawValue }.sorted()
    if (newScannedBarcodes == lastScanned) {
        return@addOnSuccessListener      // <-- silently drops it
    }
    if (newScannedBarcodes.isNotEmpty()) { lastScanned = newScannedBarcodes }
}
```

`lastScanned` is **one slot**, and it is cleared in exactly two places:
`stop()` and `dispose()`.

So:

1. You scan the Shree Beauty QR. It fires. `lastScanned = [that payload]`.
2. You close the sheet. You point at **the same QR** again.
3. `newScannedBarcodes == lastScanned` → **the plugin returns without telling
   Flutter anything.** No callback. No error. Nothing.
4. It stays dead for that code until the camera is stopped.

> **That is your force-quit.** Killing the app disposes the controller, which
> nulls `lastScanned`, which is why the QR "started to function" again.

It also perfectly matches *"won't scan a few QR codes"* — the few it will not
scan are **the ones you just scanned**. A different QR in between clears the
slot, which is why it looked random.

**Fix:** `DetectionSpeed.normal` (a 250 ms throttle, which is what we actually
wanted) and SWIP does its own de-duplication in Dart, over a time window, with a
key it controls. Same code, pointed at again, ten seconds later: fires.

---

## 3. The other two faults

### 3.1 A small QR in a big frame

No `cameraResolution` was ever passed, so the plugin took the platform default.
On the 4096 × 3072 photographs, OpenCV needed the image scaled to **0.6×**
before it could lock onto the SVC code. Analysis resolution matters.

Now set explicitly, plus **pinch-to-zoom** (the plugin exposes `setZoomScale`),
plus a **"scan from a photo"** fallback: `MobileScannerController.analyzeImage()`
runs the same ML Kit detector over a saved image, so a code the live camera
cannot hold — bad light, glare on a plastic stand, a code behind glass — can
still be read from a photograph.

### 3.2 `mc=` present and empty

A new state, `MccPublication`, replaces the old boolean thinking:

| State | Payload | What SWIP says |
|---|---|---|
| `published` | `mc=5912` | The category, plainly |
| `unclassified` | `mc=0000` | Merchant exists, category deliberately zero |
| `blank` | `mc=` | **"Their bank left the category blank"** — new |
| `malformed` | `mc=59` | The PSP generated a non-conformant QR |
| `absent` | no `mc` | Nothing was published |

`blank` is not `absent`. `blank` means somebody built a merchant QR and did not
fill the field in — worth saying out loud, because it is the acquirer's fault
and it is fixable by the merchant asking their bank.

---

## 4. How CRED does it, as far as it can be established

You asked how CRED knows to grey out a RuPay card. It is not one lookup, and
none of it is magic. The evidence is in your own screenshots:

* Screenshot A shows two RuPay cards with **"MERCHANT MAY NOT ACCEPT RUPAY CC"**
  — note **"may"**. That hedge is the tell. CRED is *inferring*, not reading a
  fact. If they had an authoritative flag they would say "does not".
* Screenshot B, a different merchant, shows **"merchant accepts RuPay"** as a
  confident statement near the payee — that one they know.

So the model is: **a payload-derived prior, corrected by observed outcomes.**

| Layer | Available to CRED | Available to SWIP |
|---|---|---|
| VPA handle pattern (`@ptys` vs `@paytm`, `SVCMERC`, `WFMLMH2@ybl`) | yes | **yes** |
| `mc` present / blank / absent | yes | **yes** |
| `mode`, `orgid`, `sign`, `tr` prefix | yes | **yes** |
| Their own historical decline data across millions of payments | **yes** | no |
| NPCI/acquirer merchant directory as a licensed PSP | **yes** | no |

SWIP has the first three of five. That is enough for an honest hedge, and it is
why the copy must read **"may not"** — the same word CRED uses — rather than a
claim we cannot support.

The fifth layer is the one SWIP can *earn*: when a payment fails at a merchant,
the user can tell SWIP once, and that merchant key is remembered forever on that
device and shared through the merchant graph. Your own decline history is the
part of CRED's advantage that is reproducible without a licence.

---

## 5. The scoring model that ships

`RupayCcOutlook` — five states, each with the evidence attached, never a bare
colour:

| Outlook | Triggered by | Copy |
|---|---|---|
| `blocked` | Small-merchant handle (`@ptys` sticker, no `mode`/`sign`) | "RuPay credit card will not work here" |
| `unlikely` | Bank-acquired merchant with `mc=` blank, or a known past decline at this key | "This merchant may not accept RuPay credit card" |
| `likely` | `mc` published and non-zero, full-merchant handle | "RuPay credit card should work here" |
| `confirmed` | The user recorded a successful card payment at this key | "You have paid by card here before" |
| `unknown` | Nothing decisive | Nothing shown — silence beats a guess |

Note that `blocked` is the only absolute, and it is absolute because it is
NPCI policy rather than a merchant setting: credit card on UPI is **not
permitted** at P2PM codes.

---

## 6. Sources

- NPCI, [Operating circular for RuPay Credit Cards linked to UPI](https://www.npci.org.in/PDF/npci/rupay/2022/Operating-circular-for-RuPay-Credit-Cards-linked-to-UPI.pdf)
  — P2P, P2PM and card-to-card are not permitted for RuPay credit card on UPI
- NPCI UPI Linking Specification 1.6 — the `mc`, `mode`, `orgid`, `sign` parameters
- `mobile_scanner` 5.2.3 source, `MobileScanner.kt` lines 85–103 — the
  `lastScanned` slot
- [`23-MCC-DETECTION-MATRIX`](23-MCC-DETECTION-MATRIX.md) — the full route table
- [`22-FEEDBACK-ROUND-3`](22-FEEDBACK-ROUND-3.md) — P2M vs P2PM evidence
