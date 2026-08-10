# Feedback round 3 — cracking the Paytm QR

> From the counter test at Snowberry and two shops, 09–10 Aug 2026, with CRED
> screenshots that turned out to be the decisive evidence.
>
> Original prompt, verbatim: [21-PROMPT-LEDGER § Prompt 19](21-PROMPT-LEDGER.md#prompt-19--the-counter-test-part-two-current).
> Previous round: [20-FEEDBACK-ROUND-2](20-FEEDBACK-ROUND-2.md).
>
> **Never delete a row.**

---

# 🔑 `F-46`–`F-48` — the answer, and it was in your screenshots

You asked how CRED knows. **Your own screenshots answer it**, and the answer also
explains why there is no MCC. This is the most important finding in the project
so far.

## The evidence you captured

Three handles, three CRED screens:

| Shop | Handle | CRED said |
|---|---|---|
| "Best Wishes" sticker | `paytmqr6twbbd@ptys` | **"MERCHANT DOES NOT ACCEPT RUPAY CC"** on both RuPay cards |
| Akruti Enterprise | `paytm.s28uaa5@pty` | RuPay cards selectable |
| Snowberry | `paytm.s233ffl@pty` | Cards selectable — you paid ₹1 |

And separately: **Snowberry's POS tap gave SWIP the MCC.** The same shop's Paytm
QR gave nothing.

## What that combination proves

NPCI splits merchants into two tiers, and everything follows from which tier a
shop is in:

| | **P2M** — full merchant | **P2PM** — small merchant |
|---|---|---|
| Onboarding | Full KYC, formal acquisition | Light-touch |
| **MCC** | **Assigned** | **None assigned** |
| RuPay credit card on UPI | **Allowed** | **Not allowed** |
| Inward limit | Normal | Merchants crossing ₹1,00,000 for three consecutive months must be moved to P2M *"with applicable Merchant Category Codes"* |

Two independent sources confirm both halves:

- NPCI's own RuPay-CC-on-UPI FAQ: RuPay credit card on UPI is **for merchant
  (P2M) payments only**; restricted categories explicitly include **P2P and
  P2PM** — [npci.org.in FAQ](https://www.npci.org.in/what-we-do/rupay/rupay-credit-card-on-upi/faqs),
  [Razorpay docs](https://razorpay.com/docs/payments/payment-methods/upi/cc-on-upi/)
- The P2PM inward-limit circular: crossing ₹1 lakh for three months forces
  acquisition **under P2M with applicable MCCs** — i.e. **P2PM merchants do not
  have one** — [taxguru summary](https://taxguru.in/finance/implementation-maximum-upi-credit-limits-p2pm-merchants.html)

### So:

> **"Best Wishes" has no MCC because it is a P2PM merchant.** That is not SWIP
> failing to read the code, and it is not Paytm hiding anything. **A P2PM
> merchant has no merchant category code to read.** CRED greys out the RuPay
> cards for exactly the same underlying reason.

The two facts you saw as separate — *"CRED knows about RuPay"* and *"there's no
MCC"* — **are the same fact.** RuPay-CC acceptance and having an MCC are both
consequences of being P2M.

## How CRED actually knows — and why SWIP cannot do it the same way

CRED is a **UPI TPAP**: a certified third-party application provider with a
sponsor bank and NPCI membership. When it sees a VPA it calls NPCI's
**ValidateAddress** (`ReqValAdd`), and the response carries the merchant's
registered name, its type, and its acceptance rules. That is why CRED can print
"Shravan Singh Bhavar Singh Balot" from a sticker that only says
`paytmqr6twbbd@ptys`, and why it knows about RuPay before you pay. Paytm's own
app does the same thing against its own servers.

**SWIP is not a PSP and does not hold funds** — deliberately, and that is what
keeps it out of RBI's PPI regime entirely
([12-COMPLIANCE-RISK](12-COMPLIANCE-RISK.md)). So `ReqValAdd` is closed to us.

I am not going to pretend otherwise, and I am not going to fake it. What I can
do is get to the same answer by other routes — and three of them work.

## What SWIP now does about it, without being a PSP

### 1. `F-46` — prove the merchant tier from the handle. **Built.**

The handle prefix is minted by the PSP at onboarding and a shop cannot choose
it. Your three samples split perfectly along the tier line:

| Handle shape | Tier | Your evidence |
|---|---|---|
| `paytmqr…@ptys` | **P2PM**, small merchant | RuPay refused |
| `paytm.s…@pty` | **P2M**, soundbox / full merchant | RuPay accepted, ×2 |

`paytm.s…` is Paytm's **Soundbox / All-in-One** series — the box that speaks the
amount aloud. A shop only gets one after full onboarding. `paytmqr…` is the
basic printed sticker.

**This is a hypothesis with n=3, and it is labelled as one in the app.** It is
not stated as certain, and every capture records what it predicted so your own
usage either confirms it or kills it. If you hit a `paytmqr…` shop that *does*
take RuPay CC, that single capture disproves it and I will say so.

### 2. `F-47` — the notifier line CRED shows. **Built.**

The capture sheet now carries a line saying whether the shop looks like it can
take a RuPay credit card, with the reasoning attached rather than as a bare
verdict:

> **RuPay credit card: likely accepted** — this looks like a fully-onboarded
> merchant, so a RuPay credit card on UPI should work here.

> **RuPay credit card: likely not accepted** — this looks like a small-merchant
> (P2PM) code. NPCI does not allow credit card on UPI at those, which is also
> why there is no category.

### 3. `F-48`/`F-49`/`F-50` — three real routes to the missing MCC

The digits do not exist in that QR. They exist in three other places, and SWIP
can reach all three:

| Route | How | Status |
|---|---|---|
| **The terminal** | EMV tag `9F15` over NFC. **This already worked at Snowberry.** | ✅ built |
| **Your statement** | You proved it: ₹1 via Federal Bank, MCC visible on the statement. **Built** — see below | ✅ `S-25` |
| **Another sticker** | Many shops carry both a Paytm sticker and a bank/BharatQR one; the bank one often does carry EMVCo tag `52` | ✅ works today |

**And the piece that makes all three pay off — `F-49`.**

At Snowberry you got the MCC from the terminal, and the QR still knew nothing.
That is because the two captures are filed under **different merchant keys**:

```
POS tap  →  emv:356:<terminal's merchant id>
QR scan  →  upi:paytm.s233ffl@pty
```

Same shop, same counter, three minutes apart — and no link between them. So the
knowledge from the tap cannot answer the QR.

**The fix is merchant reconciliation**, and geolocation is what makes it
possible: two captures inside the same ~1 km cell within a short window, one
carrying an MCC and one not, are almost certainly the same shop. SWIP proposes
the link, **you confirm it**, and from then on that Paytm handle answers with
Snowberry's real category — for you, and for anyone else once sync exists.

This is the "workaround" you asked for, and it is better than a workaround: it
is how the merchant graph was always supposed to earn its keep.

### `F-50` — the statement loop. **Built, and better than specced.**

You sent the line, and it changed the plan. I had specced *"type the four digits
in"*. The line makes that unnecessary:

```
UPIOUT/658724829452/paytm.s233ffl@pty/Demo/5451
          RRN         Snowberry's VPA   note   MCC
```

**5451 is Dairy Products Stores.** Snowberry sells ice cream. Correct.

The category is not the valuable half — **the VPA beside it is**. A category
alone is a fact about one payment. A category *paired with the handle that was
paid* is a fact about a **merchant**, and that handle is byte-for-byte what a QR
scan produces. So SWIP never has to ask which shop a line belongs to, and a
paste teaches it every UPI merchant in the statement at once.

| | |
|---|---|
| Where | Settings ▸ **Learn from a bank statement** — or select the lines in a PDF viewer and **share to SWIP** |
| What it keeps | The handle and its category. Amounts and balances are ignored |
| Back-fill | Every uncategorised capture already stored for that merchant gets the code retroactively |
| Confidence | **Verified** — and it earns it. This is what the acquirer posted after the money moved, not a prediction made before |

Code: [`statement_parser.dart`](../app/lib/data/sources/statement_parser.dart) ·
[`S-25`](../app/lib/features/statement/statement_import_page.dart) ·
[tests](../app/test/statement_parser_test.dart)

**The design decision worth checking.** Fields are identified by *shape*, not by
a per-bank regex table that would rot — a VPA looks like `x@y`, an RRN is 12
digits, an MCC is 4 digits **and resolves in the offline table**. That last
clause is load-bearing: without it a four-digit transaction note would be adopted
as a category and taught to the merchant graph permanently.

**And a bug worth recording.** The first version split only on `/`, so it worked
on the bare narration I quoted from your screenshot and found **nothing** in an
actual pasted row — where date and amount columns surround the narration. CI
caught it. The fix segments first and reads words inside each segment, with the
rule that a category must be the **first word of its own segment** — otherwise an
amount printed without decimals (`TFR 5451`) becomes a category. Three regression
tests now cover it.

---

# The rest of the round

## `F-51`, `F-52` — geolocation

| ID | Item | Status |
|---|---|---|
| `F-51` | Not working at all | ✅ **fixed** |
| `F-52` | Must be granular: *"karsavadavli, Thane"*, not "Mumbai, Maharashtra" | ✅ **fixed** |

**Why it was not working.** Three causes, all real:

1. **It is off by default and nothing told you.** The toggle sits in Settings and
   there was no prompt anywhere else. Now the capture sheet shows a one-line
   offer when location is off and a capture had nowhere attached to it.
2. **The label was being truncated to one part.** The old code took the *first*
   non-empty of `subLocality, locality, administrativeArea` and printed that with
   the country — so at best "Kasarvadavali, IN". Now it composes
   **`subLocality, locality`** → **"Kasarvadavali, Thane"**, exactly your format,
   falling back sensibly anywhere in the world.
3. **An 8-second timeout with no fallback.** Indoors at a counter that fails
   often. It now falls back to the last known position before giving up.

## `F-53` — which mode detected the MCC

Built. The sheet now leads with an explicit, unmissable line:

> **Read from the shop's card terminal** · EMV tag 9F15
> **Read from the QR code** · UPI `mc`
> **Read from a payment link** · inferred, never verified
> **Answered from what SWIP already knew** · merchant graph

## `F-54`–`F-56` — NFC readiness

| ID | Item | Status |
|---|---|---|
| `F-54` | Check on the home screen whether NFC is on | ✅ the Tap tile now reflects real NFC state, not just hardware |
| `F-55` | **Red warning**: SWIP must be the default contactless payment app, or GPay intercepts | ✅ built, with a button straight to the settings screen |
| `F-56` | Card turns **green** when SWIP is the default | ✅ built, re-checked on every resume |

This was a real gap. Android routes the contactless field to whichever app holds
the default-payment slot, so on any phone with GPay set up, **the tap was going
to GPay and SWIP would simply never see the terminal.** Nothing in the app said
so.

## `F-57` — the super list

[23-MCC-DETECTION-MATRIX](23-MCC-DETECTION-MATRIX.md) — every route SWIP has to
an MCC, what each one actually reads, how far it gets, and where it fails.

## `F-58`, `F-59` — two new payment scenarios

| ID | Scenario | Status |
|---|---|---|
| `F-58` | **In-app wallet top-up** with a custom amount, then a choice of UPI / UPI app / credit card / netbanking | 📋 specced below |
| `F-59` | The second one | 🔍 **held open** — *"i frogot due to doorway effect"*. Left blank on purpose; I am not going to invent one and have it look like your idea |

**On `F-58`** — this one matters more than it looks. A wallet top-up is one of
the few places where the category is *predictable and bad*: loading a wallet
posts as **MCC 6540 (non-financial institutions — stored value)**, which most
Indian issuers exclude from rewards entirely, and which is on the RuPay-CC-on-UPI
restricted list. So the useful thing SWIP can say is not "here is the code" but:

> **This is a wallet top-up. It will almost certainly post as 6540 and earn
> nothing on most cards — including no reward on the spend you make from the
> wallet afterwards.**

That is a genuinely valuable warning and it needs no capture at all. Detection:
the checkout URL/intent naming a wallet load, or the merchant handle belonging to
a known wallet operator.

## `F-60`, `F-61` — the camera, and the popping modal

You are right, and the research backs you.

> *"Modals are the most intrusive UX pattern"* — and lighter, in-place patterns
> are dramatically less disruptive —
> [Plotline, mobile modals](https://www.plotline.so/blog/mobile-app-modals);
> [NN/g on interruption](https://www.nngroup.com/articles/permission-requests/)

The failure was mine and it was a design error, not a bug: a full-height modal is
the correct response to *a deliberate scan*, and completely wrong as the response
to *ambient scanning the user did not ask for*. A camera that is always looking
must answer **quietly**.

| ID | Item | Status |
|---|---|---|
| `F-60` | Research whether always-on + modal is right | ✅ **it is not** |
| `F-61` | Condensed card: MCC, merchant, universal MCC description, detection type, chevron to expand | ✅ **built** |
| `F-62` | Cards stack to the right, swipeable, last 1 minute | 📋 next pass |
| `F-63` | Pull-string *"vieeeeewww older scans"*, `e` stretching, >4 `e`s opens the ledger | 📋 next pass |
| `F-66` | Single tap morphs the camera region into a square | 📋 next pass |
| `F-67` | Double tap enters the standalone camera screen | 📋 next pass |
| `F-68` | Tap / double-tap ripple with a hand indicator | 📋 next pass |

**What changed now:** the inline viewfinder no longer opens a modal at all. A
scan produces a compact card that slides in under the camera, and the full sheet
only appears if you tap the chevron. The full-screen scanner still opens the full
sheet, because there the scan *was* deliberate.

## `F-64` — uncategorised copy

Built. The old copy was three or four sentences of explanation per case. Now each
case is **a headline you can read in one glance, and one short line under it**,
with the long version behind the chevron.

| Case | Before | After |
|---|---|---|
| Personal UPI code | *"This is someone paying as a person, not a registered business. Personal codes never carry a category — so there is nothing for your card to earn on here."* | **"A person, not a shop"** · *No category exists. Nothing to earn.* |
| Registered shop, no MCC | four sentences | **"A real shop, no category published"** · *Tap their card machine to find it.* |
| Website | two sentences | **"A website"** · *Not a payment code.* |
| Damaged | three sentences | **"Damaged code"** · *Failed its own checksum. Scan again.* |

## `F-43` — trusted apps

🔍 **Still need this.** The prompt says *"i have also shared you the trusted
apps"*, but the images in it are: Amazon and Swiggy checkout screens, the three
CRED payment screens, the two Paytm stickers, the Snowberry sticker, SWIP's own
dashboard, and a GitHub Actions page. **No trusted-apps screen among them.**

Rather than guess which Android screen you meant — it could be *Tap & pay*,
*Special app access*, *Autofill*, or a device-maker's own security panel — I have
left this open. One screenshot settles it, and the answer changes what it is
worth chasing.

---

## Carried forward

| ID | Item | Why not yet |
|---|---|---|
| `F-24` | Learn and group uncategorised merchants | `F-49` reconciliation is the first half of this |
| `F-59` | The forgotten second scenario | Waiting on you |
| `F-62`, `F-63`, `F-66`–`F-68` | The camera interaction set | Next pass — the intrusiveness fix shipped first because it was actively annoying |
| — | Launcher icon still the Flutter placeholder | Needs PNG renders from the brand generator |
| — | 50-terminal `9F15` field test | Only you can run it |
