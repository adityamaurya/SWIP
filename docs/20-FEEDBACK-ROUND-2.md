# Feedback round 2 — the counter test

> From the second real install, 09 Aug 2026, with photographs taken at an actual
> shop counter. Same rule as always: **never delete a row.**
>
> Previous round: [19-FEEDBACK-ROUND-1](19-FEEDBACK-ROUND-1.md).

---

## ⚠️ First: Vector 7 is settled, and I was wrong

I said [50/50](19-FEEDBACK-ROUND-1.md#what-the-swiggy-screenshots-add), and that
one install would settle it. It settled it. **SWIP does not appear in Swiggy's
UPI list.**

The screenshot shows the list in full:

> Unlock Swiggy UPI · Google Pay · PhonePe UPI · Paytm UPI · CRED UPI ·
> Amazon Pay UPI · Jupiter UPI · iMobile UPI · Kiwi UPI · Airtel UPI

SWIP registered the `upi://pay` intent filter, was installed, and still is not
there. That is **reading B** from last round: the payment SDK ships a maintained
allowlist of known UPI packages and shows the ones installed. A raw
package-manager query would have surfaced SWIP; an allowlist cannot, no matter
what SWIP registers.

**What this costs and what it does not.** It costs the in-checkout capture on
big apps — Swiggy, PVR, Amazon. It costs nothing on the vector that actually
carries the category: a merchant's own QR sticker still works, and the pay-by-app
handler still works for any merchant whose checkout *does* use the system
chooser. Vector 7 code stays; it is now opportunistic rather than a plan.

| ID | Item | Status |
|---|---|---|
| `F-41` | SWIP in the merchant's in-app UPI list | ❌ **confirmed not possible** via intent registration on allowlist-based checkouts |
| `F-43` | SWIP now appears in some "trusted apps" list on the phone | 🔍 **work in progress** — you flagged this and asked to hold. Noted, not yet chased. Worth a screenshot of exactly where you saw it |

**The fallbacks are now the plan, not the contingency.** In order of honesty:

1. **Share-to-SWIP.** Register as a share target. Every checkout has a copy or
   share action; one extra tap, works everywhere, no permission needed, no
   allowlist to get onto.
2. **Clipboard check, opt-in.** SWIP offers to read a UPI string you copied —
   only on an explicit tap, never in the background.
3. **Screenshot read.** Screenshot the payment screen, SWIP reads the QR out of
   the image.

---

## 🔴 `F-42` — the merchant that "would not scan". The fatal one.

Two shops, both photographed, both scanned, both landing as
**"Unknown category · Paytm"**. One of them was even offering RuPay credit card
payment, which means it is unambiguously a registered merchant.

### What is actually in those stickers

The two handles are visible in your photographs:

| Sticker | Handle | Paytm's app resolved it to |
|---|---|---|
| "Paytm UPI Transfer" | `paytm.s28uaa5@pty` | Akruti Enterprise |
| "Best Wishes / Accepted Here" | `paytmqr6twbbd@ptys` | Shravan Singh Bhavar Singh Balot |

The payload is a `upi://pay?…` with `pa`, a generic `pn`, `mode=02` and a
signature. **There is no `mc` in it.** That is not SWIP failing to read — the
four digits are not in the sticker. Paytm's own app shows the shop's name
because it *asks its server* what that handle resolves to; the printed code
never carried it.

So the honest answer to "why is it not scanning the MCC" is: **it scanned
everything that was there, and the category was not there.** No parser can fix
that, and inventing a plausible one is precisely the behaviour this product
exists to replace.

### The real defect, which was next to it

SWIP read `pn=Paytm` and printed **Paytm as the merchant**. Five captures at
five different shops all said "Paytm". The payment company was being presented
as the shop — confident, and wrong, on the one line a person reads first.

That is fixed in
[`merchant_identity.dart`](../app/lib/data/sources/merchant_identity.dart):

| Before | After |
|---|---|
| `pn` printed as the merchant, whatever it said | Placeholder names (Paytm, PhonePe, Merchant, UPI, …) are **rejected**. A name is real or absent — never borrowed from the PSP |
| No name → "Unknown" | Falls back to **the payee handle** — `paytmqr6twbbd@ptys` — which is printed on the sticker in front of you and can be checked |
| PSP invisible or mistaken for the shop | PSP shown in its own labelled field, "Payment company" |
| "Unknown category" for a shop and for a friend's personal code alike | A `paytmqr…@ptys` handle, or a signed `mode=02`, **proves a registered business**. The sheet now says *"A real shop — its category was not in the code"* and says what to do about it |

The last row is the one that matters at a counter. The question being asked is
not "what is this code" — it is **"will this earn?"** — and "a registered
business whose bank did not publish a category" answers that far better than
"Unknown".

### What still cannot be recovered, and the three ways round it

The category for those two shops does not exist in any QR they own. It can only
come from somewhere else:

1. **Tap the shop's card machine** (`F-08`, built). EMV tag `9F15` comes from
   the terminal, not the sticker.
2. **Type it in once** when it appears on your statement. The merchant graph is
   keyed on `upi:paytmqr6twbbd@ptys`, so every past and future capture of that
   handle inherits it — including from a different phone, once sync exists.
3. **A second QR at the same shop.** Many shops carry both a Paytm sticker and
   a BharatQR/bank sticker, and the bank one often does carry tag 52.

Covered by tests in
[`merchant_identity_test.dart`](../app/test/merchant_identity_test.dart),
including the two handles above.

---

## `F-44` — ledger hierarchy reversed

> *"in the ledger, the priority has to be given to the merchant name and then
> the category… On the left, first would be the merchant registered name and
> then the merchant description based on the code."*

Done, and it reverses `D-05`. The reasoning holds up: in the field you are
standing in front of a shop you can already see, so the row's job is **"which
visit was this"** first and **"what was it filed as"** second.

| Line | Before | After |
|---|---|---|
| 1 | Category name | **Merchant** — registered name, or the payee handle |
| 2 | Publication chips | **Category** from the code |
| 3 | Confidence · merchant · vector | Confidence · Domestic/Intl · payment company · vector |

## `F-45` — the capture sheet keeps code-first

> *"When it is showing from the model while capturing, the priority will be the
> same as in the merchant code, and then the merchant description and actual
> merchant name registered."*

Unchanged from `F-10`–`F-12`, which is what you asked for: **code → what the
code means → the registered merchant name.** The two screens deliberately
disagree, and that is correct — the sheet appears when you are *deciding*, the
ledger when you are *recalling*.

---

## Priorities 3, 4, 5 — built this round

| ID | Item | Status |
|---|---|---|
| `F-01` | Live camera in the top band, always looking | ✅ [`live_viewfinder.dart`](../app/lib/widgets/live_viewfinder.dart) |
| `F-02` | Tap the viewfinder → full-screen scanner | ✅ |
| `F-03` | Swipeable carousel, dots, camera default, same card size | ✅ [`dashboard_page.dart`](../app/lib/features/dashboard/dashboard_page.dart) |
| `F-14` | Domestic or international | ✅ [`home_market.dart`](../app/lib/core/settings/home_market.dart) |
| `F-15` | Onboarding asks home country + currency | ✅ [`home_market_page.dart`](../app/lib/features/onboarding/home_market_page.dart) |
| `F-16` | Abroad shows International + country | ✅ badge on the sheet, chip on the row |
| `F-06` | All / Hide uncategorised | ✅ [`ledger_page.dart`](../app/lib/features/ledger/ledger_page.dart) |
| `F-07` | Collapsed rows as a dotted break | ✅ tap the break to expand |
| `F-40` | Geolocation on every capture | ✅ **built** — see below |

### `F-40` — built, and here is the shape of it

Deferred from the first pass of this round, then built on its own once the rest
was green. Code:
[`capture_location.dart`](../app/lib/core/location/capture_location.dart).

**The privacy shape is the design, not a footnote.** Your ledger is exported to
your own Drive, so it travels. A file holding the exact coordinates of every
shop you have ever paid at is not something this app is willing to create.

| Decision | Why |
|---|---|
| **Off by default** | The permission is requested the moment you flip the switch in Settings — not at first run. An app that wants your location before it has shown you anything useful gets denied for ever |
| **Coarse only** | `ACCESS_COARSE_LOCATION` is the only permission added. No fine, no background |
| **The raw fix never reaches storage** | Reduced to a **6-character geohash** — a cell of roughly 1.2 km × 0.6 km — before the row is built |
| **The toggle reflects reality** | Tap Deny at the system prompt and the switch goes back off and says so. A switch that stays on after a denial is a lie, and it is the kind that gets noticed |
| **It can never fail a capture** | Refused permission, location services off, no fix indoors within 8 s — all three mean "no location", none of them means "no capture" |

Fetched inside
[`CaptureRepository.record`](../app/lib/data/repositories/capture_repository.dart)
rather than at each capture screen, so *"captured with every capture"* is
structurally true: a vector added next year gets location without anyone
remembering to wire it.

The geohash is hand-written rather than a dependency — thirty lines, no platform
surface, and one fewer package in the supply chain of an app whose whole pitch
is that it does not send your spending anywhere. Pinned against Niemeyer's
reference vector in
[`geohash_test.dart`](../app/test/geohash_test.dart), including the precision,
so a future *"let us make it more accurate"* fails loudly.

**A side effect that improves `F-14`.** The device's country now beats the
payload's when deciding domestic vs international. That is what the original ask
actually said — *"comparing where you are now against your home country"* — and
the two genuinely differ: a QR issued to a Singapore-registered merchant and
scanned by you in Mumbai carries `SG` in its payload while you are standing in
India. Your card cares where you are.

Schema `v1 → v2`, additive and nullable, so a ledger already on a phone survives
untouched and simply has no location for its older rows — which is the truth
about them.

---

## `S-24` — share-to-SWIP, built

The answer to `F-41`, and the thing that survives the Swiggy finding.
Code: [`share_capture.dart`](../app/lib/features/capture_share/share_capture.dart).

**It was half-built already, and that was the bug.** The `text/plain` share
filter had been in
[the manifest](../app/android/app/src/main/AndroidManifest.xml) since the first
commit with nothing behind it — SWIP appeared in your share sheet and did
nothing when you picked it. Exactly the same class of failure as Tap and Link:
registered, never wired.

| Share this | SWIP does |
|---|---|
| **Text** — a payment link, or a `upi://pay?…` string copied off a checkout | Resolves it through the same `CaptureResolver` as a scan, so the two can never describe one merchant differently |
| **Image** — a screenshot of a payment screen | Reads the QR out of the picture |

If a screenshot has no readable code — which is exactly what a Swiggy payment
screen looks like, since it shows a list of apps rather than a QR — SWIP says
so and points at the screen's own *copy link* action instead. **A share target
that silently goes nowhere is worse than not having one.**

Why this works when Vector 7 did not: the share sheet is the one list nobody
curates. No merchant, no PSP, no SDK vendor holds a veto over it. One extra tap
that works everywhere beats zero taps that work nowhere.

---

## The camera, and what it costs

`F-01` asked for the feed to be live whenever the app is open. It is — with one
limit worth knowing about, because it will look like a bug otherwise:

**The camera stops when Home is not the visible tab, and when the app is
backgrounded.** Tabs stay alive in an `IndexedStack`, so without that gate SWIP
would hold the camera open behind the Ledger — a battery drain, and a green
privacy dot on your status bar with no camera visible on screen. That is the
kind of thing that gets an app uninstalled.

It restarts the instant you come back to Home.

---

## Still open, carried forward

| ID | Item | Why not yet |
|---|---|---|
| `F-24` | Learn and group uncategorised merchants | Needs volume before there is a pattern |
| `F-43` | The "trusted apps" listing you spotted | Waiting on a screenshot of where |
| — | ~~Share-to-SWIP target~~ | ✅ **built** — `S-24`, above |
| — | Launcher icon still the Flutter placeholder | Needs PNG renders from the brand generator |
| — | 50-terminal `9F15` field test | Only you can run it |
