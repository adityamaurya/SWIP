# Prompt ledger — every instruction, verbatim, with what it became

> **Why this file exists.** You asked: *"keep in list of to dos that with every prompt
> that I had given with original prompt maintained in a special MD file as well for
> logging."*
>
> This is that file. One entry per prompt, the words as you wrote them, and every
> to-do extracted from it with a live status. It is the index of intent —
> [02-IDEATION-LEDGER](02-IDEATION-LEDGER.md) holds the *ideas*, the
> [CHANGELOG](CHANGELOG.md) holds the *changes*, and this holds **the asks**.
>
> **Rules, same as everywhere else in this project:**
> - **Never edit a past prompt.** They are quoted as given, typos and all — a
>   cleaned-up quote is a quote you cannot trust.
> - **Never delete a to-do.** If something is dropped, it is marked dropped with a
>   reason, in the open.
> - Statuses: ✅ built · ◑ partly built · 📋 queued · 🔍 needs your input ·
>   ❌ established impossible · ⛔ dropped, with a reason
>
> **Prompts 1–15 are reconstructed** from the session record and the commit history —
> they were not being logged verbatim at the time, which is itself a miss. From
> prompt 16 on they are captured exactly as typed.

---

## Prompt 1 — Foundation

> *Name and brand SWIP, research how an MCC can be captured before payment, design
> the app, build it for Android and iOS, and write it all down so nothing from the
> ideation is ever lost.*

| # | To-do | Status |
|---|---|---|
| 1.1 | Brand: wordmark, app icon, monogram, generator | ✅ [CHANGELOG §1](CHANGELOG.md#prompt-1--08-aug-2026--foundation) |
| 1.2 | Research every route to an MCC before payment | ✅ [03-RESEARCH](03-RESEARCH-MCC-CAPTURE.md) |
| 1.3 | Design system + all screens | ✅ [06](06-DESIGN-SYSTEM.md) · [07](07-SCREEN-SPEC.md) |
| 1.4 | Build for Android and iOS | ◑ Android builds and installs; iOS scaffolded, never compiled on a Mac |
| 1.5 | Lose nothing from ideation | ✅ [02-IDEATION-LEDGER](02-IDEATION-LEDGER.md) |

## Prompt 2 — *"Use Team "Claude Code""*

| # | To-do | Status |
|---|---|---|
| 2.1 | Put the Figma file in a team called "Claude Code" | ⛔ **Dropped, with reason.** Figma's API cannot create teams. File was created and the reason recorded in [11-FIGMA](11-FIGMA.md) |

## Prompt 3 — *"If you dont find a team named this, create and move ahead you have my full permission / Continue from where you left off. / auto-resume all the above as the credits usage recover"*

| # | To-do | Status |
|---|---|---|
| 3.1 | Create the team, proceed without asking | ✅ Proceeded; team creation is not in Figma's API |
| 3.2 | Auto-resume as credits recover | ✅ Self-scheduled, ran five rounds |

## Prompts 4–5 — auto-resume rounds

| # | To-do | Status |
|---|---|---|
| 4.1 | Replicate all screens in Figma | ◑ **Blocked by a hard cap.** Starter plan: 3 pages, 1 variable mode, MCP tool-call ceiling. Six probes across a UTC midnight all failed — [11-FIGMA §4](11-FIGMA.md#4-where-the-build-stopped) |
| 4.2 | Correct the ideation ledger's overstated statuses | ✅ Audit found ~25% actually built; "Reality check" section added |

## Prompt 6 — *"how do I view the app? I want to view it right away"*

| # | To-do | Status |
|---|---|---|
| 6.1 | A way to actually see the app | ✅ [09-BUILD-AND-RUN](09-BUILD-AND-RUN.md) |

## Prompt 7 — Play Store, fees, and *"why are you making the design so boring? Make it something interesting! Go on Dribbble, go behind, find some inspiration, and do something like credit [CRED]."*

| # | To-do | Status |
|---|---|---|
| 7.1 | Very detailed, noob-friendly Play Store walkthrough including every fee | ✅ [13-PLAY-STORE-LAUNCH](13-PLAY-STORE-LAUNCH.md) |
| 7.2 | A design direction that is not boring — CRED-grade | ✅ **Foil** — [14-VISUAL-DIRECTION-FOIL](14-VISUAL-DIRECTION-FOIL.md) |
| 7.3 | *"golden minimal not too gaudy… to make look premium"* | ✅ Gold `#C9A227` on near-black, 8.4:1 |
| 7.4 | *"make it dark theme everywhere, add animation from some best open source library"* | ✅ Dark-only; `flutter_animate` |

## Prompts 8–9 — *"Yes"* / *"YES"*

| # | To-do | Status |
|---|---|---|
| 8.1 | Build everything fed in the ideation | ◑ Ongoing — the through-line of every round since |
| 8.2 | Onboarding for every feature, shown every time, with "don't show again" | ✅ `primers.dart` |
| 8.3 | Country-agnostic: *"IT MUST GIVE ME MCC no matter what, all countries supported"* | ◑ 30+ QR schemes parse; the MCC is only present when the payload carries it — see [23-MCC-DETECTION-MATRIX](23-MCC-DETECTION-MATRIX.md) |
| 8.4 | Google login + Drive backup | ◑ Local export/import built; Drive not wired |
| 8.5 | Trademark walkthrough with links | ✅ [15-TRADEMARK-SWIP](15-TRADEMARK-SWIP.md) |
| 8.6 | v2 PRD | ✅ [16-V2-PRD](16-V2-PRD.md) |

## Prompt 10 — *"HOW DO I FACILITATE THIS FOR YOU, STEP-BY-STEP NEEDED"*

| # | To-do | Status |
|---|---|---|
| 10.1 | Make it possible to actually compile | ✅ [Flutter CI](../.github/workflows/flutter.yml) — the code had **never been compiled** until this point |

## Prompt 11 — *"I have this for you"* + screenshot of the first red CI run

| # | To-do | Status |
|---|---|---|
| 11.1 | Fix every CI error | ✅ Rounds 1–8; byte-vs-char TLV lengths, a stale gitignore eating the font, and more |

## Prompt 12 — *"whats happening? where are we falling short to achieve success?"*

| # | To-do | Status |
|---|---|---|
| 12.1 | An honest structural answer | ✅ Given: code had been written for weeks before the project could build |
| 12.2 | Get to an installable APK | ✅ First working APK |

## Prompt 13 — reusable APK instructions, PVR pay-by-app, phone-to-phone

> *"…Please detail it down to the very basic core level so that even an illiterate
> person can understand"*

| # | To-do | Status |
|---|---|---|
| 13.1 | Reusable APK recipe for **other** projects, native not wrappers | ✅ [17-BUILD-ANY-APK](17-BUILD-ANY-APK.md) |
| 13.2 | Capture the MCC when paying via app at PVR/Swiggy | ❌ **Established impossible** by intent registration — [20 §Vector 7](20-FEEDBACK-ROUND-2.md) |
| 13.3 | Phone-to-phone card payment, explained at the most basic level | ✅ [18-INTENT-CAPTURE-AND-TAP-TO-PHONE](18-INTENT-CAPTURE-AND-TAP-TO-PHONE.md) |
| 13.4 | Ledger tabs/filters by source | ✅ `F-06`, `F-07` |
| 13.5 | Geolocation | ✅ `F-40`, refined in prompt 19 |
| 13.6 | **Standing rule:** *"HENCFORTH ALWAY GIVE ME HYPERLINKS TO WHATEVER INFORMATION YOU PRESENT TO ME… never ever leave me blind with words"* | ✅ Permanent |

## Prompts 14–15 — feedback round 1, with PVR/Amazon/Swiggy screenshots

| # | To-do | Status |
|---|---|---|
| 14.x | `F-01`–`F-25`, all of it | ✅ Logged in [19-FEEDBACK-ROUND-1](19-FEEDBACK-ROUND-1.md); build status tracked there |

## Prompt 16 — *"read docs/19-FEEDBACK-ROUND-1.md and build priorities 1 and 2 / Lets Go! / Just changed the model to Ultracode / Redo and check for what you've just done on earlier model if it was good job, else optimise"*

| # | To-do | Status |
|---|---|---|
| 16.1 | Build priority 1 — `F-08`, `F-09` NFC and links functional | ✅ [CHANGELOG §16](CHANGELOG.md#prompt-16--09-aug-2026--tap-and-link-become-real) |
| 16.2 | Build priority 2 — the bottom sheet, `F-10`–`F-13`, `F-17`–`F-23` | ✅ Same |
| 16.3 | Review the previous model's work; optimise if not good | ✅ Found the vector-routing bug in `main.dart` and 610 lines of duplicated sheet code |

## Prompt 17 — *"implement 3 & 4 & 5"* + counter photographs

| # | To-do | Status |
|---|---|---|
| 17.1 | Priority 3 — camera-first dashboard `F-01`–`F-03` | ✅ |
| 17.2 | Priority 4 — geolocation, home country, domestic/international | ✅ |
| 17.3 | Priority 5 — ledger filters | ✅ |
| 17.4 | The Swiggy list — does SWIP appear? | ❌ Settled: **no** |
| 17.5 | `F-42` — a real merchant QR gives no MCC | ◑ Root cause found in prompt 19; see below |
| 17.6 | `F-44` — ledger shows merchant first, then category | ✅ |

## Prompt 18 — *"build the share-to-SWIP target and F-40 geolocation / please go ahead"*

| # | To-do | Status |
|---|---|---|
| 18.1 | Share-to-SWIP target | ✅ `S-24`, text **and** image |
| 18.2 | `F-40` geolocation | ◑ Built, **then reported not working** — see prompt 19 |

---

## Prompt 19 — the counter test, part two *(current)*

**Original prompt, verbatim:**

> so there are few things that are need to be done, first we have a big issue with
> Paytm & Bharat QR and I'm hoping there would be more such branded QRs on which
> once you scan they have and identifier embedded which mentioned that it is a
> merchant QR code, now, the MCC part is still to be figured out in which the issue
> is that these QRs when are being scanned by Cred, then CRED is able to detect if
> it was a merchant QR or not and IF it is has enabled for payments via Rupay credt
> card, as the CRED is able to show, I want to decode that as well with my app, I
> also want to detect MCC through it, i don't know how you do it but you have to
> make it possible, the mcc is certainly visible, so yesterday waht happened is we
> went to snowberry, where the POS tap detection perfectly worked and it got to know
> the MCC category through it, now the issue is that when I did a similar case for
> their Paytm QR which was kept their, SWIP couldn't detect whether firslty
>
> it had merchant payment enabled or not as CRED does, and shows a notifier line on
> the modal screen aht pops up when the Qr is scanned
> also. the MCC that might be embedded in it ( we need to crack this man)
> so now i could see the notifier line and could select with which rupay credit card
> i want to pay the merchant
> but for time being to no call the customer care and check what mcc would come once
> done payment, i did via federal bank, as it has an advantage that once the payment
> is done, i can get the federal bank statement and it showsthe mcc in the statement
> ( I did a 1 rupee payment test on the QR)
> but once i did payment i could see the MCC in my statement
> man we need to find a workaround this thing to show
> also the geolocation thing is not working, also we need to highlight on the pop up
> modal that from which mode of payment was the MCC detected
> i have also shared you the trusted apps
> we have done it on the POS thing, one small change there in the user experience I
> would share
>
> is when we are on the homescreen we need to check if NFC permission is given
> NFC is always on
> one notifier we need to put on the NFC screen as warning in red is that, in
> androids, under the Contactless payments, for our app to be able to work it have
> our SWIP app set as the default payment app, other wise gpay (or some other nfc
> enabled payments app) will keep on getting triggered
> also when the person set the defaultpayment app for nfc mode is set to SWIP this
> notifier card turns green giving status as set as deault payment app via NFC ?
> WE HAVE 2 new way of payment scenarios where in we need to capture the MCC (ME A
> SUPER LIST WHERE IN WE HAVE SUPPORTED WAYs WE ARE IDENTIFYING THE MCC FROM THESE
> SCENARIOS)
>
> in apps there are wallets where once can top up with custome amount - in which -
> it lets to select the mode of payment where is there are n number of ways to pay,
> once is UPI / UPI APP and CC or Netbanking
> second is ..umm i frogot due to doorway effect
> ok so one user experience issue I recently figured was, the camera on the
> dashboard, its tthere is nothing wrong in it, its actually the always on camera
> scenario, it keepson scaning qrs and the pops keep on coming so it becomes a bit
> intrusive, makes the user frustrated that, the modal keeps on popping, can you
> pleaase research and let me know that if this is right experience
> major problem is the constant scanning that is being happening, can we make a
> condensed view of the MCC detection modal card, like this would be a not big of a
> card, it will show the mcc, merchant name and the mcc descriptor based on the
> universal mcc description plus a type of detection i.e (qr or pos detection) and
> then a chevron at the end with up arrow to show full modal data as per current
> view , also as the scanning will keep happening these collapsed cards will keep
> stacking in the right and the can be swipable to view the scans done in last 1 min
> and if the user wants to view more than this past 1min then there is a pulling
> string like animation (like that of a refresh in androids) that will say
> "vieeeeewww older scans " where the 'e' gets added like bubblegum stretching and
> once the no of "e"'s get more than 4 e's then the full screen ledger will open
> also for the uncategorised screens the copy is too much wordy it take a while for
> all the uncategorised cases to understand and grasp in quick glance so we can work
> there a bit more
>
> make sure nothing from the above is rejected and list them all and research deep
> thoroughly and keep in list of to dos that with every prompt that I had given with
> original prompt maintained in a special MD file as well for logging
>
> also about the geoloation, i want like where it was taken not some vaugue in
> mumbai, maharasthra or similar for the world
>
> i need like eg :
> 1; karsavadavli, Thane
> 2; Pant nagar, ghatkopar
>
> i need one more change, the camera area, can we make like if the user taps on the
> dahboard camera region it morphs and animates to in a square region? and if double
> tap to fully enter in to the camera standalone screen? also a short single tap or
> double tap animator of hind tapping and showing with ripple for the effect and and
> smae for double tap for full screen

**Every to-do in it.** Full detail, evidence and research in
[22-FEEDBACK-ROUND-3](22-FEEDBACK-ROUND-3.md).

| # | ID | To-do | Status |
|---|---|---|---|
| 19.1 | `F-46` | Detect from a branded QR (Paytm, BharatQR, others) that it **is a merchant QR** | ✅ built |
| 19.2 | `F-47` | Detect whether the merchant **accepts RuPay credit card on UPI**, as CRED does, and show a notifier line on the modal | ✅ built — and the research explains exactly how CRED knows |
| 19.3 | `F-48` | **Get the MCC out of these QRs** — *"we need to crack this man"* | ◑ **Root cause established.** The four digits are not in the payload for these merchants; three working routes to them are built or specced |
| 19.4 | `F-49` | Snowberry POS tap worked; the same shop's Paytm QR did not. Make one shop's knowledge reach the other | 📋 **the ₹1 statement loop + merchant reconciliation** |
| 19.5 | `F-50` | The Federal Bank statement shows the MCC after a ₹1 test payment. Build a workaround around this | 📋 specced |
| 19.6 | `F-51` | **Geolocation is not working** | ✅ fixed |
| 19.7 | `F-52` | Geolocation must be granular — *"karsavadavli, Thane"*, not "Mumbai, Maharashtra" | ✅ fixed |
| 19.8 | `F-53` | Show on the modal **which mode of payment the MCC was detected from** | ✅ built |
| 19.9 | `F-43` | The "trusted apps" listing | 🔍 **still need the screenshot** — the images in this prompt are checkout screens, CRED, the QR stickers and a CI page. No trusted-apps screen among them |
| 19.10 | `F-54` | On the **home screen**, check whether NFC permission is given and NFC is on | ✅ built |
| 19.11 | `F-55` | **Red warning** on the NFC screen: SWIP must be the default contactless payment app or GPay keeps intercepting | ✅ built |
| 19.12 | `F-56` | That card turns **green** once SWIP is the default NFC payment app | ✅ built |
| 19.13 | `F-57` | **A super list of every supported way SWIP identifies an MCC** | ✅ [23-MCC-DETECTION-MATRIX](23-MCC-DETECTION-MATRIX.md) |
| 19.14 | `F-58` | New scenario: in-app **wallet top-up** with a custom amount, then a choice of UPI / UPI app / CC / netbanking | 📋 specced |
| 19.15 | `F-59` | Second new scenario — *"i frogot due to doorway effect"* | 🔍 **held open for you.** Nothing invented in its place |
| 19.16 | `F-60` | **Research** whether always-on scanning with a popping modal is the right experience | ✅ researched — it is not, and the evidence says so |
| 19.17 | `F-61` | A **condensed detection card**: MCC, merchant name, universal MCC description, detection type, chevron to expand | ✅ built |
| 19.18 | `F-62` | Condensed cards **stack to the right**, swipeable, covering the last 1 minute of scans | 📋 next pass |
| 19.19 | `F-63` | **Pull-string** to see older scans — *"vieeeeewww older scans"*, the `e` stretching like bubblegum; past 4 `e`s the full ledger opens | 📋 next pass |
| 19.20 | `F-64` | Uncategorised copy is **too wordy** to grasp at a glance | ✅ rewritten |
| 19.21 | `F-65` | **This file** — every prompt verbatim, with its to-dos | ✅ you are reading it |
| 19.22 | `F-66` | Single tap on the dashboard camera **morphs it into a square** | 📋 next pass |
| 19.23 | `F-67` | Double tap enters the **standalone camera screen** | 📋 next pass |
| 19.24 | `F-68` | Tap and double-tap **ripple + hand indicator** animation | 📋 next pass |

---

<!--
Template for the next entry:

## Prompt N — <short theme>

**Original prompt, verbatim:**

> …

| # | ID | To-do | Status |
|---|---|---|---|
-->
