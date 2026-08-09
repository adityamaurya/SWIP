# Feedback round 1 — every item, with IDs

> From the first real install, 09 Aug 2026. Captured verbatim in intent, ID'd so
> nothing is lost, and each one tracked to done.
>
> **Rule, same as the ideation ledger: never delete a row.** If something is
> dropped, mark it and say why.

---

## ⚠️ First: a correction to what I told you about Vector 7

Your screenshots change the picture, and I want to be straight about it.

I said SWIP would appear in **Android's system chooser**. Looking at your
screenshots, that is **not what PVR and Amazon are showing you.**

| What I claimed | What your screenshots show |
|---|---|
| Android's own "open with" sheet | **A list the merchant app draws itself** |

Screenshot 2 (GPay · PhonePe · Airtel · Amazon · BOBCARD · CRED · DBS · Fi) and
screenshot 3 (Tata Neu · PhonePe · GPay · Paytm · CRED UPI) are **merchant-rendered
lists**, not the system chooser. Each row has the merchant's own chevron styling.

**So does SWIP appear or not? Genuinely unknown, and here is the honest split:**

The merchant builds that list one of two ways:

1. **By asking Android "who handles `upi://pay`?"** (`queryIntentActivities`).
   If so, **SWIP will appear**, because it now answers that question.
2. **From a fixed list of known UPI apps** shipped in their PSP's SDK. If so,
   SWIP will never appear, no matter what it registers.

**The evidence leans towards option 1.** That list includes **BOBCARD, DBS India
and Fi** — small apps nobody hardcodes. A fixed allowlist would show GPay,
PhonePe and Paytm and stop. Enumerating installed apps is what produces a tail
like that.

> **This is now the single most important unknown in the product**, and it takes
> you five minutes to settle: install the new build, go back to that PVR screen,
> and look for **"SWIP · read category"**. Screenshot it either way.

### What the Swiggy screenshots add

Swiggy is the clearest evidence yet, and it cuts both ways.

The header says **"Pay by any UPI App"** — the NPCI-mandated wording — and the
list underneath is long:

> Google Pay · PhonePe UPI · Paytm UPI · CRED UPI · **super.money** · Amazon Pay
> UPI · **Jupiter UPI** · **iMobile UPI** · **Kiwi UPI** · Airtel UPI

**The tail is what matters.** Kiwi, super.money, Jupiter, iMobile — plus BOBCARD,
DBS and Fi on the PVR screen. Nobody maintains a hand-written list that deep.

**Two readings, and I cannot tell which from a screenshot:**

| | Consequence for SWIP |
|---|---|
| **A. Swiggy asks Android who handles `upi://pay`** | SWIP appears. Done |
| **B. The payment SDK (Juspay/Razorpay) ships a maintained list of known UPI packages, and shows the ones installed** | SWIP never appears, however it registers |

Reading B is more likely than I first thought, precisely *because* the list is
so tidy. A raw package-manager query would surface anything that registered the
scheme; this list contains only genuine PSP apps. That smells like an
allowlist — a good one, kept current, but an allowlist.

**Which means the honest position is: 50/50, and one install settles it.**

> **You already have everything needed to answer this.** Install the newest
> build, go back to that Swiggy screen, and look for **"SWIP · read category"**.
> Nothing else in the product depends on a single unknown this cleanly.

If SWIP does not appear, §F-19 lists what we do instead — and the share-target
fallback works regardless of what any merchant does.

---

## A. Dashboard

| ID | What you asked | Status |
|---|---|---|
| `F-01` | Replace the static "last capture" hero with a **live camera viewfinder** in the same horizontal band — open the app, point at a QR, done | 📋 |
| `F-02` | **Tap the viewfinder → full-screen** scanner, for when the code will not line up | 📋 |
| `F-03` | Make the band a **swipeable carousel with dot indicators**: card 1 = live camera, card 2 = last capture. Camera is always the default | 📋 |
| `F-04` | Keep the recent-captures list below, unchanged | ✅ already |

> **Note on `F-01`.** A permanently live camera costs battery and holds the
> camera permission open. I will start it only while the dashboard is the
> foreground tab, and pause it the moment you switch away or background the app.
> Worth knowing so the behaviour is not a surprise.

## B. Ledger and the recent list

| ID | What you asked | Status |
|---|---|---|
| `F-05` | The MCC row design is right — leave it | ✅ keep |
| `F-06` | Filter toggle: **All / Hide uncategorised** | 📋 |
| `F-07` | **Collapsed rows shown as a dotted break**, the way a spreadsheet shows hidden rows — so you can see something is hidden rather than it silently vanishing | 📋 |

## C. NFC and links — "functional no matter what"

| ID | What you asked | Status |
|---|---|---|
| `F-08` | **NFC tap must work end to end**: ask for permission, prompt to enable NFC if off, tap the terminal, MCC in the bottom sheet | 📋 **next build** |
| `F-09` | **Link checking must work** — a screen where a payment link is pasted and resolved | 📋 **next build** |

The Kotlin HCE service compiles and is registered. What is missing is the Dart
side that turns it on, listens, and renders. That is the next thing I build.

## D. The capture bottom sheet

**The hierarchy you specified, in order:**

| ID | Element | Status |
|---|---|---|
| `F-10` | 1. **MCC code** | ✅ |
| `F-11` | 2. **Description of the code** | ✅ |
| `F-12` | 3. **Merchant name** | ⚠️ present but not prominent |
| `F-13` | 4. **Everything else captured**, below a separator, using **the field's own name from the source** — dynamic, not a fixed list | 📋 |

**Additions:**

| ID | What you asked | Status |
|---|---|---|
| `F-14` | **Domestic or international**, decided by comparing where you are now against your home country | 📋 |
| `F-15` | **Onboarding asks home country + currency** — the baseline `F-14` compares against | 📋 |
| `F-16` | When abroad: show **International**, the country, and the location | 📋 |
| `F-17` | **Source badge, top-right of the sheet**: QR · POS · App intent · Link · Unknown | 📋 |
| `F-18` | CTA keeps its label, with **grey subtext below** confirming it is saved to the ledger | 📋 |
| `F-40` | Geolocation captured with every capture, shown discreetly | 📋 |

## E. Uncategorised captures — the honest cases

You are right that people will point this at anything. Three cases you named,
plus what research turned up.

| ID | Case | What SWIP should say |
|---|---|---|
| `F-19` | **A personal UPI QR** — someone's `9820012345@ybl` GPay code | *"This is a personal UPI code, not a shop. Personal codes carry no category."* |
| `F-20` | **A plain web link** | *"That is a website, not a payment code."* |
| `F-21` | **A random QR with nothing in it** — wifi, contact card, plain text | *"Nothing payment-related in this code."* |
| `F-22` | Empty fields must be explained in **plain language, not technical jargon** | 📋 |
| `F-23` | **"View technical details"** below the OK button, for when you do want the raw payload | 📋 |
| `F-24` | The system should **group and learn** uncategorised types over time | 📋 |

**Other QR types found by research, which all land here:**
wifi (`WIFI:`), contact cards (`BEGIN:VCARD`), calendar events, plain text,
phone numbers (`tel:`), SMS (`smsto:`), geo pins (`geo:`), app store links,
crypto addresses (`bitcoin:`), EMV codes that fail their own checksum, and
merchant QRs where tag 52 is present but zero.

## F. Getting listed in the merchant's UPI list

| ID | What you asked | Status |
|---|---|---|
| `F-25` | Appear in PVR / Amazon / Flipkart's UPI app list so the capture happens in the real flow | ⚠️ **see the correction at the top** |

**If the field test shows SWIP does not appear**, the fallbacks in order of
honesty:

1. **Share-to-SWIP.** Every checkout has a "copy payment link" or share action.
   SWIP registers as a share target — one extra tap, works everywhere, no
   permission needed.
2. **Clipboard watch, opt-in only.** SWIP offers to read a UPI string you copied.
   Only on an explicit tap, never in the background.
3. **Screenshot read.** You screenshot the payment screen; SWIP reads the QR out
   of the image.

None is as clean as being in the list. All of them work regardless of what the
merchant does.

---

## Build order

Ordered by value against risk, not by the order you listed them.

| Priority | Items | Why |
|---|---|---|
| **1** | `F-08` `F-09` — NFC and links functional | You said no matter what, and they are the two vectors that exist but cannot be reached |
| **2** | `F-10`–`F-13`, `F-17`, `F-18`, `F-19`–`F-23` — the bottom sheet | Every vector funnels through this one screen, so it pays for itself |
| **3** | `F-01`–`F-03` — camera-first dashboard | Biggest change to how the app feels |
| **4** | `F-14`–`F-16`, `F-40` — location, home country, domestic/international | Needs a plugin; done after the build is stable |
| **5** | `F-06` `F-07` — ledger filters | Small, and better once there is more to filter |

---

## Not forgotten, deliberately deferred

| ID | Item | Why not now |
|---|---|---|
| `F-24` | Learning/grouping uncategorised types | Needs volume before there is a pattern to learn |
| — | Launcher icon still the Flutter placeholder | Needs PNG renders from the brand generator |
