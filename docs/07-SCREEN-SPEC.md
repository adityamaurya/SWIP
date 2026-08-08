# SWIP — Screen Specification

> Answers ideation IDs `A-09`, `C-01` … `C-14`, `D-01` … `D-10`, `H-04`.
> Every screen, every state, every toggle. Screen IDs (`S-nn`) are the shared vocabulary
> between this file, the Flutter routes, and the Figma frames — they must match all three.
>
> Wireframes are structural, not pixel-accurate. The Figma file
> ([11-FIGMA](11-FIGMA.md)) is the visual source of truth.

---

## Navigation

**Three destinations and one action.** No more. `A-09` asks for a dashboard you *enter and
do the things on*, and every extra tab is a decision the user has to make before doing
anything.

```
   ┌────────────────────────────────────────────────┐
   │                                                │
   │                  content                       │
   │                                                │
   ├────────────────────────────────────────────────┤
   │   ⌂ Home      ▤ Ledger    ▭ Cards        ⚙     │
   │              ╭──────────────╮                  │
   │              │   ⊕ CAPTURE  │  ← gold pill,    │
   │              ╰──────────────╯    floats above  │
   └────────────────────────────────────────────────┘
```

`⊕ CAPTURE` opens `S-20`, the capture chooser — the single door to all three live vectors.
Settings is a header icon, not a tab; it is visited monthly, not daily.

---

## Screen index

| ID | Screen | Ships |
|---|---|---|
| `S-00` | Splash | v1 |
| `S-01` | **Dashboard** | v1 |
| `S-02` | Scan QR (camera) | v1 |
| `S-03` | Tap POS (NFC) — Android | v1 |
| `S-04` | **Ledger** | v1 |
| `S-05` | Capture detail | v1 |
| `S-06` | MCC detail | v1 |
| `S-07` | Merchant detail | v1 |
| `S-08` | Check a link | v1 |
| `S-09` | MCC directory | v1 |
| `S-10` | Cards | v1 |
| `S-11` | Card detail | v1 |
| `S-12` | Settings | v1 |
| `S-13` | Confirm a capture | v1 |
| `S-14` | Onboarding (3 panels) | v1 |
| `S-15` | Permission primers | v1 |
| `S-16` | Search | v1 |
| `S-17` | Insights (Pro) | v1.5 |
| `S-18` | SWIP Probe | v2 |
| `S-19` | Travel Credit | v2 |
| `S-20` | Capture chooser (sheet) | v1 |
| `S-21` | SWIP Coins | v2 |
| `S-22` | Tap unavailable (iOS) | v1 |

---

## S-00 Splash

Ink field. Foil wordmark, `foilSweep` once, 900 ms. Holds only as long as DB open + migration.
**No progress bar** — if it takes long enough to need one, fix the startup, don't decorate it.

---

## S-01 Dashboard

**The most important screen in the product.** `A-09` (minimal, straight to doing),
`D-03` (ledger table on the dashboard itself), `D-10` (primary always visible).

```
┌──────────────────────────────────────────────────┐
│  SWIP                                       ⚙    │   wordmark-ink, 20px
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  LAST CAPTURE                              │  │   InkCard, black
│  │                                            │  │
│  │  5812          ● Verified                  │  │   mcc 34/700 gold
│  │  Eating Places, Restaurants                │  │   bodyL, white
│  │                                            │  │
│  │  Blue Tokai · Powai        ⌁ Tap · 2h ago  │  │   bodyS, ink/300
│  │  [ NATIONAL ] [ INTL ]                     │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐           │
│  │   ▣     │  │   ⌁     │  │   🔗    │           │   CaptureTiles
│  │  Scan   │  │  Tap    │  │  Link   │           │   96dp tall
│  │   QR    │  │  POS    │  │  check  │           │
│  └─────────┘  └─────────┘  └─────────┘           │
│                                                  │
│  RECENT                              See all →   │   label, ink/500
│  ┌────────────────────────────────────────────┐  │
│  │ 5812  Eating Places, Restaurants    08 Aug │  │
│  │ ●     Blue Tokai · Powai            4:12PM │  │
│  ├────────────────────────────────────────────┤  │
│  │ 5541  Service Stations              08 Aug │  │
│  │ ●     HP Petrol · Andheri          11:04AM │  │
│  ├────────────────────────────────────────────┤  │
│  │ 6513  Real Estate Agents            07 Aug │  │
│  │ ●     rzp.io/l/rentpay              9:30PM │  │
│  ├────────────────────────────────────────────┤  │
│  │ 4722  Travel Agencies               07 Aug │  │
│  │ ●     MakeMyTrip                    6:15PM │  │
│  ├────────────────────────────────────────────┤  │
│  │ 5411  Grocery Stores                06 Aug │  │
│  │ ●     DMart · Powai                 7:48PM │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│         ⌂        ▤     ⊕CAPTURE     ▭       ⚙    │
└──────────────────────────────────────────────────┘
```

**Composition rules**

1. Exactly **five** recent rows. Not four, not ten. Five fits above the fold on a 6.1"
   device with the hero and tiles, and the sixth row is what turns a dashboard into a list.
2. The hero shows the **last capture**, not a summary statistic. The user's question when
   opening SWIP is *"what did that come out as?"*, not *"how am I doing this month?"*
3. Capture tiles are **always in the same place**, always three, never reordered by
   recency. Muscle memory beats personalisation for an action done 20× a week.
4. On iOS the Tap tile is present but dimmed with a small `ⓘ`, routing to `S-22`. It is
   never hidden — a missing feature reads as a bug, an explained one reads as honesty.

**States**

| State | Treatment |
|---|---|
| First run, zero captures | Hero replaced by `EmptyState`: *"Scan any payment QR. You'll see its category before you pay."* + arrow to the Scan tile. Recent section absent entirely |
| 1–4 captures | Hero present, Recent shows what exists, no "See all" |
| Offline | No banner. Everything works — parsing and the local graph are offline-first. A ⚡ appears only on rows awaiting sync |
| Sync off | Identical, minus the ⚡ |

---

## S-04 Ledger

`D-01` simple · `D-02` every vector writes here · `D-04` `D-05` `D-06` `D-07` `D-08` `D-09`.

```
┌──────────────────────────────────────────────────┐
│  ←   Ledger                          🔍    ⋮     │
│                                                  │
│  [ All ] [ Scan ] [ Tap ] [ Link ]     ⇅ Newest  │   filter chips
│                                                  │
│  AUGUST 2026                          12 captures│   sticky section head
│  ┌────────────────────────────────────────────┐  │
│  │ 5812   Eating Places, Restaurants   08 Aug │  │
│  │        [NATIONAL] [INTL]                   │  │
│  │ ●Ver   Blue Tokai · Powai   ⌁       4:12PM │  │
│  ├────────────────────────────────────────────┤  │
│  │ 6513   Real Estate Agents, Rentals  07 Aug │  │
│  │        [NATIONAL]                          │  │
│  │ ●Lik   rzp.io/l/rentpay     🔗      9:30PM │  │
│  └────────────────────────────────────────────┘  │
│  JULY 2026                            31 captures│
│  ...                                             │
└──────────────────────────────────────────────────┘
```

### S-04.1 Row anatomy

| Zone | Content | Type | Rule |
|---|---|---|---|
| **Col 1** | **MCC**, 4 digits | `mcc` 20/700, `goldInk` | `D-04`. **Never truncated, never wrapped, fixed 56 dp** |
| **Col 2 line 1** | Detailed category name | `bodyM` ink/900 | `D-05`. Max 2 lines, then ellipsis |
| **Col 2 line 2** | Publication chips | `labelS` | `NATIONAL` · `INTL` · `RUPAY`, in that order |
| **Col 2 line 3** | Confidence + merchant + vector glyph | `bodyS` ink/500 | Merchant ellipsises before anything else does |
| **Col 3** | The time cell | see S-04.3 | Fixed 64 dp, right-aligned |

**`D-10` enforced in code:** columns 1 and 2 line 1 have `overflow: visible` on the MCC and
a 2-line clamp on the category. Everything that must give, gives in the merchant string.

### S-04.2 Publication chips `D-05`

You asked for column 2 to say whether the code is published nationally, internationally, or
by RuPay. A code can be more than one, so this is a **set**, not a value.

| Chip | Meaning | Border / Text |
|---|---|---|
| `NATIONAL` | Defined in the domestic scheme's list (NPCI/RuPay for India) | ink/300 · ink/700 |
| `INTL` | In the ISO 18245 / Visa / Mastercard international list | info · info |
| `RUPAY` | Explicitly published by RuPay, possibly with a different definition | gold/700 · goldInk |

When definitions **differ** between publications, the row shows the domestic one and `S-06`
displays both side by side under a `conflict` header. Silently picking one would be the
single most damaging thing this app could do.

### S-04.3 The time cell `D-07`

You gave three instructions here, in sequence, and the third revised the second:

1. *"time and date in relative format — 2 hours ago"*
2. *"the time below it will be replaced with date and time"*
3. *"you could swap it first — keep the time just below the day, the date and the month"*

Instruction 3 is final and it is what ships as **default**. Instruction 1 is preserved as
the alternate state, because it is genuinely better for very recent captures.

```
   DEFAULT (Absolute)            ALTERNATE (Relative)
   ┌──────────┐                  ┌──────────┐
   │  08 Aug  │  label 13/600    │  2h ago  │  label 13/600
   │  4:12 PM │  bodyS ink/500   │          │  vertically centred
   └──────────┘                  └──────────┘
```

- **Day + date + month on top, time directly below.** Exactly instruction 3.
- **Tap any time cell to toggle** the whole ledger between the two. Global, persisted,
  animated with `micro`. Also in Settings → Display → *Time format*.
- Today's captures always show `4:12 PM` on line 2 with `Today` on line 1, in both modes.
- Year appears on line 1 only when the capture is not in the current year (`08 Aug 25`).

> **Why a toggle rather than a decision.** You changed your mind mid-sentence, which is the
> strongest possible signal that both readings are right in different moments. "2h ago" wins
> for something that just happened; "08 Aug / 4:12 PM" wins for reconciling against a
> statement. Cost to build: about 20 lines. Cost of guessing wrong: a daily irritation.

### S-04.4 Interlinking `D-08`

Every row is a hub. From a single ledger row, one tap reaches:

```
                 ┌──────────────┐
                 │  Ledger row  │
                 └──────┬───────┘
        ┌───────────────┼────────────────┐
        ▼               ▼                ▼
   S-05 Capture    S-06 MCC        S-07 Merchant
   detail          detail          detail
        │               │                │
        │               ├─ every capture with this MCC
        │               ├─ which of YOUR cards reward it
        │               └─ national / intl / RuPay definitions
        │
        ├─ raw payload (TLV / APDU / URL)
        ├─ the card used
        └─ same merchant, other captures
```

- **Tap the row** → `S-05` Capture detail
- **Tap the MCC number** → `S-06` MCC detail
- **Tap the merchant name** → `S-07` Merchant detail
- **Long-press** → sheet: Copy MCC · Share · Confirm/correct · Delete

### S-04.5 Progressive depth `D-09`

> *"Minimal on the surface. Deep dive once you go inside."*

| Level | Screen | Shows |
|---|---|---|
| 0 | Row | MCC · category · publication · merchant · time |
| 1 | `S-05` | + amount, currency, terminal/acquirer, vector, card, confidence provenance |
| 2 | `S-05` → Raw | + the actual TLV tags or APDU trace, monospaced, copyable |
| 3 | `S-06` / `S-07` | + cross-capture aggregate, reward maths, definition conflicts |

Level 2 exists because this audience will not trust a number they cannot verify, and being
the app that *shows its working* is a durable trust advantage.

---

## S-02 Scan QR `C-03` `C-14`

Full-bleed camera. Ink scrim at 60 %. Gold reticle, 260 dp, `foilSweep` on lock.

```
┌──────────────────────────────────────────────────┐
│  ←                                     ⚡ ⓘ      │  torch, help
│                                                  │
│            ╭──────────────────────╮              │
│            │                      │              │
│            │   ┌──┐        ┌──┐   │              │  gold corners
│            │                      │              │
│            │        [ QR ]        │              │
│            │                      │              │
│            │   └──┘        └──┘   │              │
│            ╰──────────────────────╯              │
│                                                  │
│      Point at any payment QR                     │
│      UPI · BharatQR · PIX · QRIS · 30+ more      │
│                                                  │
│                  [ 🖼 From photo ]                │
└──────────────────────────────────────────────────┘
```

On decode → `S-02b` result sheet rises (`emphasized`), camera stays live behind it.

**S-02b — Result sheet**

```
   ╭────────── ▬▬ ──────────╮
   │                        │
   │   5812      ● Verified │   mcc 56/700, foil sweep
   │   Eating Places,       │
   │   Restaurants          │
   │                        │
   │   [NATIONAL] [INTL]    │
   │                        │
   │   Blue Tokai Coffee    │
   │   Powai, Mumbai · IN   │
   │   ₹ amount not set     │
   │                        │
   │   ⌄ Raw payload        │
   │                        │
   │   [  Save to ledger  ] │   gold fill, ink text
   │   [  Scan another    ] │   ghost
   ╰────────────────────────╯
```

**Failure states — all four are distinct and none of them says "Error"**

| Case | Message |
|---|---|
| Valid QR, `mc=0000` or tag 52 absent | *"This QR carries no category. It's likely a personal UPI handle."* + `S-07` lookup by VPA |
| CRC fails | *"This QR didn't verify. Try scanning again."* — **never** show a possibly-corrupt MCC |
| Alipay / WeChat / EPC | *"Chinese and European QRs don't carry a category. Here's what we know about this merchant."* → Vector 6 |
| Not a payment QR | *"That's a web link, not a payment code."* + Open / Check as payment link |

---

## S-03 Tap POS `C-04` `C-05` `C-13`

The screen that carries the product's novelty. It must set expectations **before** the tap,
because the merchant is watching and the terminal is going to show an error.

```
┌──────────────────────────────────────────────────┐
│  ←   Tap to read                          ⓘ      │
│                                                  │
│          ╭────────────────────╮                  │
│          │                    │                  │
│          │        ⌁           │   pulsing gold   │
│          │                    │   ring, 1.6s     │
│          ╰────────────────────╯                  │
│                                                  │
│         Hold your phone to the terminal          │  titleM
│                                                  │
│   Ask the cashier to start the payment, then     │  bodyM ink/500
│   tap your phone instead of your card.           │
│                                                  │
│   ┌────────────────────────────────────────────┐ │
│   │ ⓘ  The terminal will show an error and no  │ │  infoBg
│   │    payment will happen. That's expected —   │ │
│   │    SWIP reads the category and stops.       │ │
│   └────────────────────────────────────────────┘ │
│                                                  │
│                  [  Cancel  ]                    │
└──────────────────────────────────────────────────┘
```

**States**

| State | Treatment |
|---|---|
| `idle` | Above |
| `listening` | Ring pulses. Copy: *"Ready — tap now."* |
| `handshake` | Ring solid gold, 200 ms |
| `captured, 9F15 present` | → `S-03b` full result, foil sweep, success haptic |
| `captured, 9F15 == 0000` | → `S-03b` **partial** — see below |
| `no NFC hardware` | Pre-empted: tile disabled on `S-01` with a tooltip |
| `NFC off` | Sheet: *"NFC is off"* + Open settings |
| `timeout, 20 s` | *"Nothing yet. Some terminals need the amount entered first."* + Retry |
| **iOS** | Never reachable → `S-22` |

**S-03b partial result** — this is the honest case and, per [03-RESEARCH §3.4](03-RESEARCH-MCC-CAPTURE.md#34-what-is-verified-and-what-must-be-field-tested),
possibly the common one:

```
   ╭────────── ▬▬ ──────────╮
   │  Terminal read ✓       │
   │                        │
   │  This terminal didn't  │
   │  send a category.      │
   │                        │
   │  But we know it:       │
   │  5812  ● Likely        │
   │  Eating Places         │
   │  from 47 SWIP captures │
   │  at this merchant      │
   │                        │
   │  Merchant  4451•••9021 │   9F16
   │  Terminal  0A44C1      │   9F1C
   │  Country   356 · India │   9F1A
   │                        │
   │  [ Save to ledger ]    │
   ╰────────────────────────╯
```

**The feature has a floor.** Even with no `9F15`, the merchant identifier, terminal id and
country almost always return — enough to key the merchant graph and answer from it.

---

## S-08 Check a link `C-07` `C-08`

Reachable from `S-20`, from the Android share sheet, and from the iOS share extension.

```
┌──────────────────────────────────────────────────┐
│  ←   Check a link                                │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │ pages.razorpay.com/luxeflorist          ⨯ │  │
│  └────────────────────────────────────────────┘  │
│                       [ Check ]                  │
│  ─────────────────────────────────────────────   │
│                                                  │
│   5992              ● Likely · 78 %              │
│   Florists                                       │
│   [NATIONAL] [INTL]                              │
│                                                  │
│   Luxe Florist                                   │
│   via Razorpay · rzp_live_Lq7••••                │
│                                                  │
│   ┌────────────────────────────────────────────┐ │
│   │ ⓘ  Payment links never carry the category.  │ │
│   │    It lives with the merchant's acquirer.   │ │
│   │    This is our best inference.              │ │
│   └────────────────────────────────────────────┘ │
│                                                  │
│   Based on                                       │
│   • 3 SWIP users confirmed this merchant         │
│   • Razorpay merchant key                        │
│   • Page category signals                        │
│                                                  │
│   [ Save to ledger ]                             │
│   [ I paid — tell us what posted ]   ← the loop  │
└──────────────────────────────────────────────────┘
```

The disclosure box is **mandatory and non-dismissible** on every inferred result. Presenting
a heuristic with the same confidence as a live capture would be the fastest way to lose this
audience permanently.

---

## S-05 Capture detail

```
┌──────────────────────────────────────────────────┐
│  ←   Capture                          ⇪    ⋮     │
│                                                  │
│   5812                            ● Verified     │  mcc 56/700
│   Eating Places, Restaurants                     │
│   [NATIONAL] [INTL]                              │
│                                                  │
│   ─── WHERE ──────────────────────────────────   │
│   Merchant     Blue Tokai Coffee Roasters   →    │  → S-07
│   Location     Powai, Mumbai · India             │
│   Acquirer     HDFC Bank                         │
│                                                  │
│   ─── WHEN ───────────────────────────────────   │
│   Captured     08 Aug 2026, 4:12 PM              │
│                2 hours ago                       │  BOTH, always
│                                                  │
│   ─── HOW ────────────────────────────────────   │
│   Vector       ⌁ Tap · EMV tag 9F15              │
│   Amount       ₹ 480.00                          │
│   Terminal     0A44C1                            │
│                                                  │
│   ─── YOUR CARDS ─────────────────────────────   │
│   HDFC Infinia        5× on 5812        →        │
│   Axis Magnus         1× — not a bonus  →        │
│                                                  │
│   ⌄ Raw payload                                  │  level 2
│                                                  │
│   [ Confirm ]  [ Correct this ]  [ Delete ]      │
└──────────────────────────────────────────────────┘
```

Note **WHEN shows both formats simultaneously** — at level 1 there is room, so the toggle
question from `S-04.3` doesn't arise.

**YOUR CARDS is the bridge to the business model** — it is [04-BUSINESS-MODEL §4](04-BUSINESS-MODEL.md#4-the-join-between-v1-and-v2--the-strategic-core)
rendered as a component, and it is what makes v1 sticky enough to matter.

---

## S-06 MCC detail · S-07 Merchant detail

**S-06** — the code's own page: the four digits large; official name per **each** publication
(national / international / RuPay, stacked, differences highlighted); ISO range and what that
range means; which of the user's cards treat it as a bonus, a normal, or an excluded
category; every capture the user has with this code; and how commonly it appears near them.

**S-07** — the merchant's page: name, location, acquirer; **all** MCCs ever observed for this
merchant with counts and dates (merchants do change codes, and that is exactly the kind of
thing this audience wants to know); every capture; and a *Report a change* action.

---

## S-09 MCC directory · S-16 Search

`S-09` — offline, searchable, browsable by ISO range, the full bundled MCC table. Works with
no network and no account. This alone is a better product than most existing MCC lookup
sites.

`S-16` — one search field over captures, merchants, and codes. Numeric input jumps straight
to the code.

---

## S-10 Cards · S-11 Card detail

Cards are stored **locally**, entered manually: issuer, network, product, last 4 optional,
nickname. **No PAN, no CVV, no expiry, ever, in v1** — there is no reason to hold them and
every reason not to.

`S-11` holds the reward rules that power the *YOUR CARDS* block: bonus categories by MCC,
excluded MCCs (`6540`, `6051`, `4829`, rent, wallet…), caps, and milestone thresholds.
Seeded from a bundled ruleset for the top ~40 Indian cards, user-editable, with an
`Updated · 12 Jul 2026` stamp so nobody trusts a stale rule.

---

## S-12 Settings

```
   DISPLAY
     Time format          Absolute ▸    ← S-04.3 toggle
     Theme                Light ▸       ← dark ships v1.2
     Currency             ₹ INR ▸
   CAPTURE
     Save automatically   ●━━
     Haptics              ●━━
     Sound                ━━○
   PRIVACY
     Contribute captures  ●━━           ← the Vector 6 opt-in
     Coarse location      ━━○
     Sync                 ━━○
     Export my data       ▸
     Delete everything    ▸
   ABOUT
     How SWIP reads MCCs  ▸
     Data sources         ▸
     Version 1.0.0 (1)
```

**Every privacy toggle defaults OFF**, and the app is fully functional with all of them off.
For a finance app that is not a nicety — it is the difference between an install and an
uninstall, and it is what makes the contribution loop trustworthy when users *do* turn it on.

---

## S-13 Confirm a capture

The growth loop, reachable from `S-08`, from a post-capture prompt, and from any row.
*"What did this post as on your statement?"* → MCC field + optional statement-line paste →
thanks + how many people it helped. No permissions, no SMS reading
([03-RESEARCH §8](03-RESEARCH-MCC-CAPTURE.md#8-vector-5--statements-sms-and-email-and-why-swip-does-not-lead-with-it)).

---

## S-14 Onboarding · S-15 Permission primers

Three panels, skippable, no account (`Q-2`):

1. **Know before you pay.** *"Every purchase has a hidden four-digit category. It decides your rewards. SWIP shows it first."*
2. **Any QR on earth.** *"UPI, BharatQR, PIX, QRIS, PayNow and 30 more."*
3. **Or tap the terminal.** *(Android only)* *"No QR? Tap the POS. SWIP reads the category and stops — no payment happens."*

`S-15` primers appear **in context, at first use**, never up front: camera before the first
scan, NFC before the first tap. Each explains the *why* in one sentence before the OS dialog.

---

## S-22 Tap unavailable (iOS) `B-02`

```
   ⌁  Tap isn't available on iPhone

   Apple only allows apps to emulate a card in the
   European Economic Area, and India isn't included.

   Scanning QR codes and checking links work fully.

   [ Notify me if this changes ]
   [ How SWIP reads terminals ]  → 03-RESEARCH
```

Plain, factual, no blame. ([Apple](https://developer.apple.com/support/hce-transactions-in-apps))

---

## S-18 Probe · S-19 Travel Credit · S-21 Coins — v2

Specified in [04-BUSINESS-MODEL](04-BUSINESS-MODEL.md) and
[05-LOYALTY](05-LOYALTY-ALLIANCES.md). In v1 these appear in Settings → *Coming soon* only
if the user opts into updates. **No locked tabs, no teaser badges, no dark patterns.**
`S-21`'s layout is drawn in [05-LOYALTY §8](05-LOYALTY-ALLIANCES.md#8-what-the-rewards-screen-must-show).

---

## Global states

| State | Rule |
|---|---|
| Loading | Skeletons matching final layout. Never a centred spinner on a populated screen |
| Empty | Illustration + one sentence + one action. Never "No data" |
| Offline | Silent. Everything core works offline |
| Error | What happened · why · what to do. Never a code alone |
| Destructive | Confirm sheet, danger fill, name the object: *"Delete this capture?"* |
| Text at 200 % | Ledger row reflows to stacked at ≥ 130 % |
