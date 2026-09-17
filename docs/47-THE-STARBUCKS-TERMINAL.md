# 47 — The Starbucks terminal, decoded byte by byte

> *"I went to Starbucks and tried to tap at the POS terminal… the contactless
> limit has been exceeded, I'm not sure what that error is… the terminal did
> not identify itself, I'm not sure why those details came in."* — prompt 51

**This is the most complete POS exchange SWIP has ever recorded, and it
answers the project's central question with bytes rather than reasoning.**

Everything below is decoded from the APDU log and
`SWIP_PosTrace_2026-09-17_19-30-28.jsonl`.

---

## 1. The exchange worked perfectly

Read the trace in order and nothing failed:

| Line | What happened |
|---|---|
| `nfc.state isDefaultPayment: **true**` | SWIP held the contactless slot. `docs/45`'s failure #3 did not happen |
| `hce.field` | The terminal's field reached SWIP |
| `hce.select.ppse` | It opened with `SELECT 2PAY.SYS.DDF01` and **SWIP answered** — `F-140`'s AID registration, working |
| `hce.select.aid A0000000031010` | It chose Visa |
| `hce.select.aid A0000000041010` | Then Mastercard |
| `hce.gpo bytes: 69` | It asked for processing options and sent **all 69 bytes SWIP requested** |
| `hce.end outcome: **read**` | A complete, successful EMV conversation |

There is no failure anywhere in this trace. Failures 1–6 of
[`45`](45-WHY-A-POS-TAP-FAILS.md) are all absent.

---

## 2. What SWIP asked for

From the AID response, SWIP's PDOL — the list of things it asks a terminal to
send:

```
9F38 23   9F15 02   9F16 0F   9F1C 08   9F1A 02   5F2A 02   9F02 06
          9A   03   9F21 03   9F35 01   9F33 03   9F37 04   9F4E 14
```

Twelve fields, 69 bytes. The four that identify the shop are the first, the
second, the third and the last:

* **`9F15` — the merchant category code.** The whole product.
* `9F16` — the merchant identifier
* `9F1C` — the terminal serial number
* `9F4E` — the merchant name and location

---

## 3. What came back

The GPO command, split against that list:

```
80 A8 00 00 47 83 45
   0000                                  9F15  merchant category   ← ZERO
   000000000000000000000000000000        9F16  merchant id         ← ZERO
   0000000000000000                      9F1C  terminal serial     ← ZERO
   0356                                  9F1A  country = India         ✓
   0356                                  5F2A  currency = INR          ✓
   000000050400                          9F02  amount = 504.00         ✓
   260917                                9A    date = 2026-09-17       ✓
   185801                                9F21  time = 18:58:01         ✓
   22                                    9F35  terminal type           ✓
   E000C8                                9F33  terminal capabilities   ✓
   5A9C1D3B                              9F37  unpredictable number    ✓
   0000000000000000000000000000000000000000   9F4E  merchant name  ← ZERO
```

**Eight fields answered truthfully. The four that say who the shop is came
back as zeros.**

That is not a rounding of the truth. The amount is exactly ₹504.00, matching
the terminal's own screen in the photograph. The date and time are correct to
the second. The country and currency are right. **The terminal knew precisely
what it was doing and filled the merchant-identity fields with nothing.**

`hce.tags` records the same finding from the other side: `count: 8`, and
`9F15` is not in the list. SWIP dropped the four zero fields as padding rather
than reporting `0000` as a category — which is `F-154`'s rule doing its job on
live hardware for the first time.

---

## 4. So "This terminal did not identify itself" was exactly right

The screen in the second screenshot is not a failure message and not a guess.
It is the only honest thing that could be said about those bytes, and it is now
provable to the byte.

---

## 5. Why a terminal does this, and what it means for SWIP

**The category is not the terminal's to give.** An MCC is assigned by the
acquiring bank and lives in the **acquirer's switch** — it is attached to the
transaction during authorisation, on the network, after the card has gone. A
payment terminal needs the amount, the currency, the date and its own
capabilities to run an EMV kernel. It does not need to know its own category to
take a payment, so many are simply never provisioned with one.

This is the same fact [`41`](41-RAZORPAY-EXPLAINED.md) records about VPA
lookups, arriving from the other direction: *the MCC lives in the acquirer's
switch.* `docs/34` reasoned that a terminal would carry it. **This trace is the
first evidence that at least some do not**, and it is strong evidence because
everything else in the same response is correct.

### What this does and does not change

It does **not** mean tapping is pointless. It means the tap has the same shape
as the QR: **some sources carry a category and some do not, and which is which
is decided by the acquirer, not by the shop and not by SWIP.** `docs/42` found
5 of 48 QR codes carried one. The equivalent number for terminals is currently
**0 of 1**, which is a sample of one and must be reported as such.

**This is the single most important number in the project and it needs a
corpus.** One terminal is an anecdote. `F-187`'s black box is already the
instrument — every tap writes a `hce.tags` line, and whether `9F15` is in it is
the whole question.

---

## 6. "Contactless Limit exceed. Please dip your Card"

A separate thing, and not a limit problem.

₹504 is far below India's ₹5,000 contactless ceiling, so the message is not
literally true. What happened is this: SWIP read the response and then
**declined** — `Result: Declined by SWIP · SW=6985`, visible in the app's own
screenshot. `6985` is EMV's *"conditions of use not satisfied"*, and a card
returning it means *I will not do this transaction over contactless.*

**The overwhelmingly common reason a real card says that is the tap limit**, so
terminals map `6985` straight to their limit message. The terminal is not
reporting a fact about your card; it is guessing at why a card refused, and
guessing the usual reason.

It is the expected ending. SWIP's own green banner says so before the tap:
*"Nothing is paid — it reads the category and stops, so the terminal will show
an error. That is the expected ending, not a failure."* The wording on the
terminal is just less informative than ours.

**Worth saying plainly: the shop's payment was not affected.** Nothing was
authorised, nothing was reserved, and dipping the card afterwards works
normally.

---

## 7. What to do with this

1. **Tap more terminals.** The black box is built and it costs nothing. The
   question *"how many terminals publish `9F15`"* is answerable in a week of
   ordinary shopping, and it decides how much of SWIP's promise rests on the
   POS path.
2. **The app should say which of the two it was.** "This terminal did not
   identify itself" is correct but reads as a fault. It is the same finding as
   *"a real shop, no category published"* on the QR side, and it deserves the
   same calm framing.
3. **Nothing here needs a code fix to the reader.** The reader is correct. What
   is missing is data about the world.
