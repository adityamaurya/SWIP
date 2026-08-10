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

## Prompt 19 — the counter test, part two

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
| 19.3 | `F-48` | **Get the MCC out of these QRs** — *"we need to crack this man"* | ✅ **cracked, by another route.** The digits are not in those payloads and never will be — but `F-50` reads them off your statement, keyed to the same handle, so the sticker answers for ever after |
| 19.4 | `F-49` | Snowberry POS tap worked; the same shop's Paytm QR did not. Make one shop's knowledge reach the other | 📋 **the ₹1 statement loop + merchant reconciliation** |
| 19.5 | `F-50` | The Federal Bank statement shows the MCC after a ₹1 test payment. Build a workaround around this | ✅ **built** — `S-25`, and it turned out to be the strongest vector in the app |
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

## Prompt 20 — the Federal Bank statement

**Original prompt, verbatim:**

> check the screenshot above the mcc is shown in bank statement like this

*(with a screenshot of a Federal Bank statement row:*
`UPIOUT/658724829452/paytm.s233ffl@pty/Demo/5451`*)*

| # | ID | To-do | Status |
|---|---|---|---|
| 20.1 | `F-50` | Read the MCC out of a bank statement line and key it to the VPA beside it | ✅ [`statement_parser.dart`](../app/lib/data/sources/statement_parser.dart), `S-25` |
| 20.2 | `F-50` | Backfill past captures of that merchant once learned | ✅ `backfillMcc()` in [`swip_database.dart`](../app/lib/data/sources/swip_database.dart) |

---

## Prompt 21 — trusted apps, card stacking, wallet top-up

**Original prompt, verbatim:**

> this is the trusted app if there is a redirection happening (ss1) to choose a UPI
> app then it shows up, thats good but imside the the apps as a listing its still
> not visible (ss2) shared above, go ahead and build the card staking thing also the
> card atackign will be not just below the xamera area / but at the bottom of screen
> like a toast of condensed music player in apple also there will be somgle tap to
> morp to squarish and double tap on camera area to open full camer app screen /
> research and hold on to the waller top up, research and let me know how would you
> capture the mcc on this direction once you get the ss1 modal with swip as listed /
> f49 do some more indepth research from finance app and world and their infra and
> then make it with all the context and ss you have now

| # | ID | To-do | Status |
|---|---|---|---|
| 21.1 | `F-43` | Correct the Vector 7 record — the system chooser **does** list SWIP | ✅ correction at the **top** of [20-FEEDBACK-ROUND-2](20-FEEDBACK-ROUND-2.md) |
| 21.2 | `F-62` | Card stacking **at the bottom of the screen**, Apple condensed-music-player style | ✅ [`scan_stack.dart`](../app/lib/widgets/scan_stack.dart) |
| 21.3 | `F-63` | Pull-string — *"vieeeeewww older scans"* | ✅ same file |
| 21.4 | `F-66` | Single tap morphs the camera band to a square | ✅ [`live_viewfinder.dart`](../app/lib/widgets/live_viewfinder.dart) |
| 21.5 | `F-67` | Double tap opens the standalone camera screen | ✅ same file |
| 21.6 | `F-68` | Tap / double-tap ripple + hand indicator | ✅ `_TapRipple` |
| 21.7 | `F-58` | Wallet top-up — research, then **hold** | ✅ researched, held: it posts as MCC 6540 and most Indian issuers exclude it |
| 21.8 | `F-49` | Deeper research, then build merchant reconciliation | ✅ [`merchant_reconciler.dart`](../app/lib/data/sources/merchant_reconciler.dart) |

---

## Prompt 22 — the camera does not work

**Original prompt, verbatim:**

> one major bug is happening, the camera is not working despite asking and getting
> the permission on dash and inside the full camera screen , do a sanity check of the
> code surrounding the camera region, also there could be two scenarios furthermore,
> one where in
> * the use give the permission and the above bugs happen
> * second the
> user of fear denies the permission, then enters the country and the currency gets
> mapped as per the country selection, later on when he enters the app the always on
> camera region willl have and inside trigger where the user can tap and get
> redirected to give the camera permission

| # | ID | To-do | Status |
|---|---|---|---|
| 22.1 | `F-69` | Sanity-check the whole camera surface | ✅ done twice — the second pass (prompt 24) is the one that found the real cause |
| 22.2 | `F-69` | Scenario 1: permission granted, camera still dead | ✅ fixed — two controllers were fighting for one platform texture |
| 22.3 | `F-69` | Scenario 2: permission refused, then a tap on the band to grant it later | ✅ fixed — and in prompt 24 made to actually work, because a refused controller in 5.2.3 can never be restarted |

---

## Prompt 23 — "Camera access is off" after the full screen

**Original prompt, verbatim:**

> there is another bug where in once you go inside the full camera screen by double
> tapping it says on the dashboard camera this - as sahred in screenshot above

*(screenshot: the dashboard band reading "Camera access is off / Tap here to allow it")*

| # | ID | To-do | Status |
|---|---|---|---|
| 23.1 | `F-70` | The dashboard band must not claim permission was denied when it was only handed over | ✅ fixed in prompt 24 |

---

## Prompt 24 — one NFC card, and the camera told the truth

**Original prompt, verbatim:**

> streamline the copy above and below make it in one and turne to red and green
> status as the permissions enable / Also, one thing I'm observing is that whenever I
> give the permission of NFC from the native Android system and once I redirect back
> to the application, I have to do a back and again have to check if the status has
> to be updated on the screen. Once I do back from the system's app of an Android app
> and go back to the swipe app, it doesn't auto-detect if I've given the permissions
> or not. I have to do back again and I have to again sort of check if the permission
> has been captured. / Can you please fix this and get it captured on the back? Fix
> all the problems and just make sure that there is no bug around it. Sanity check
> once.

| # | ID | To-do | Status |
|---|---|---|---|
| 24.1 | `F-71` | Merge the NFC screen's two copy blocks into **one** card | ✅ `_StatusCard` in [`tap_page.dart`](../app/lib/features/capture_nfc/tap_page.dart) |
| 24.2 | `F-71` | That one card turns **red / green** with the permission state | ✅ red when the tap would go elsewhere, green when it comes to SWIP |
| 24.3 | `F-72` | Auto-detect the default-payment status **on return from Android settings** — no more going back and re-entering | ✅ `WidgetsBindingObserver` + `didChangeAppLifecycleState` → `_recheck()` |
| 24.4 | `F-70` | Fix "Camera access is off" after the full-screen scanner | ✅ **root cause found by reading the 5.2.3 source** — see below |
| 24.5 | `F-69` | Sanity check the whole camera surface | ✅ three further defects found and fixed |

**What the sanity check actually found.** `mobile_scanner` 5.2.3's `MobileScannerController.start()`
**does not throw** — it catches its own exception and parks it in `value.error`. Every
`catch (permissionDenied)` block in this app was therefore dead code, and `_running`
was being set true on starts that had failed. On top of that,
`MobileScannerPlatform.instance` is a **process-wide singleton holding a single
texture id**, so the dashboard band and the full-screen scanner were always
competing for one slot, and the loser got `controllerAlreadyInitialized` — which
the old `errorBuilder` reported as "Camera access is off".

Three more, from the same reading:

* A controller whose error is `permissionDenied` can **never** be restarted —
  `start()` returns early for ever, and `stop()`, the only thing that clears the
  error, bails out because nothing is running. Granting permission afterwards did
  nothing. Fixed by fitting a fresh controller.
* Sharing a screenshot to SWIP built a controller and disposed it, and disposing
  *any* controller disposes the shared platform — **silently stopping the
  dashboard camera** and leaving it convinced it was still running.
* `_stop()` skipped `controller.stop()` whenever its own flag said "not running",
  which is exactly when that flag was wrong.

---

## Prompt 25 — the deck, the ledger's way in, and one language per row

**Original prompt, verbatim:**

> As per the screens that you can see as of now, the card that is showing up
> below, in the foreground or just behind the scanner icon, is overlapping. Also,
> there is missing data in this.
>
> One important thing to notice is that the card that is being shown is in error.
> What should happen is that these cards should be overlaid, as in the present. It
> should be on the way to a hierarchy, with the scan button first. I think we
> should remove the scan button as of now. You should only keep the floating tab,
> like in Apple Music when the player is collapsed. In that case, that should be
> the view, and in the very same case, it should look that way, very neat, below
> also.
>
> Also, just fix that. One major change that we have to make is that whenever we
> click each of the items in the ledger, we get to view the whole model that is
> shown with the data that is supposed to be seen again when it is captured, also
> in the screenshots that I'm seeing. Also, in the ledger, I can see:
> 1. The MCC code
> 2. The merchant name
> 3. The category, not written into this code
>
> For the category, which is not in the MCC, you can simply say "no category" or
> "unknown". Next is "domestic" and something "pay" or something. Also, there is
> some flash icon and some other attachment icon. What is that? Can you please
> define it if possible? You can remove it because it is not making sense. You can
> maybe add a tag just below the date if it was POS or it was via NFC, so POS or
> NFC. One could be "scan", that could be done.
>
> Also, in the domestic, I don't show "domestic" there. Instead, you can show
> something like "location" and the real location where it was captured as the geo
> location. What is that? I'm not sure what that is. Just let me check.
> Okay, I'm just checking the screenshot as of now. As I can see, the merchant
> category code number is properly visible in the ledger section. You have the
> culinary brands India name, which is okay and captured. I guess I don't know
> what method was used for that. Next is category, which is not written into this
> code. You can simply say "no category defined" or "no category", and there would
> be no unknown. In this thing, it will be only the domestic, but instead of
> domestic, that will be a real location, as I had mentioned to you earlier.
> Nothing is called domestic, nothing is called international. It will be a real
> location where it was taken.
>
> Firstly, it would be the regional location, wherein hard copper and then Mumbai.
> If it is in, let's say, some other countries, accordingly, we know where it was
> taken. If interlaken, then Switzerland, in that side field, if that makes sense.
> Accordingly, I am not sure about the international part, but on this, it doesn't
> make sense. The verified aspect doesn't make sense. Maybe you can put that just
> below the MCC code. You can make the MCC code bigger a bit, and just below it,
> you can put verified, making the verified text the same or maybe smaller. Next
> is domestic and Paytm. I am not sure what Paytm is, but you can maybe show it
> inside the pop-up that shows up when you click on this item. Also, disable the
> link thing for now and grey it out, but it will still be accessible on tapping
> it. Just for now, prioritize and keep the similar "tap and scan" thing as a
> priority. Also, can you just disable it and make it something like "Scan QR" in
> both, and tap P and POS, or maybe something good copy for these two scenarios so
> that people can understand? Also, make the text a bit bigger for tap and scan,
> but yeah, makes sense. Also, remove the capture button, which I have mentioned
> to you. Another thing is that capture is clashing with the hovercards, which
> will pop up, so I'm not able to see that. Also, there will be no dash when MCC
> is not there. You can simply say "NA". Yeah, that's it.

| # | ID | To-do | Status |
|---|---|---|---|
| 25.1 | `F-78` | The condensed card overlaps the Capture button and overflows by 4 px | ✅ fixed — fixed-height two-line card, stack height derived from it |
| 25.2 | `F-79` | Cards should be **overlaid in a hierarchy**, Apple-Music-collapsed-player style, not a carousel | ✅ rebuilt as a real deck in [`scan_stack.dart`](../app/lib/widgets/scan_stack.dart) |
| 25.3 | `F-82` | **Remove the Capture button** — it clashes with the cards | ✅ removed from [`main.dart`](../app/lib/main.dart) |
| 25.4 | `F-83` | **Tapping a ledger item opens the full model** shown at capture time | ✅ [`capture_detail.dart`](../app/lib/widgets/capture_detail.dart), one path for all three entry points |
| 25.5 | `F-77` | "Category not written into this code" → **"No category"** | ✅ `categoryFallback` rewritten |
| 25.6 | `F-75` | The flash and glyph icons — define or remove; add a **POS / NFC / SCAN tag under the date** | ✅ removed; `VectorTag` renders `SCAN` · `POS` · `LINK` |
| 25.7 | `F-74` | **No "domestic", no "international"** — show the real captured location | ✅ removed from the row **and** the Last Capture hero; place label takes the slot |
| 25.8 | `F-73` | **Verified** moves under a **bigger MCC**, at the same size or smaller | ✅ `MccBadgeSize.lg` + `ConfidenceCaption` |
| 25.9 | — | **"Paytm"** moves into the pop-up | ✅ row drops the acquirer; the sheet lists it as *Payment company* |
| 25.10 | — | Remove the `NATIONAL` / `INTL` chips from the row | ✅ they describe the code, not the visit — they stay on the sheet |
| 25.11 | `F-81` | **Grey out Link**, still tappable; prioritise Tap and Scan | ✅ dimmed, narrower, still routes |
| 25.12 | `F-81` | Better copy — **"Scan QR"**, **"Tap POS"** — and bigger text | ✅ `titleS`, with *The shop's code* / *The card machine* |
| 25.13 | `F-76` | **No dash when there is no MCC — say "NA"** | ✅ `MccBadge`, the hero, and the condensed card |

**Not done, and why:** the location line shows only what was actually captured.
Where the geolocation permission was off at capture time there is no place to
show, so the row shows nothing rather than inventing one. Rows captured before
location was switched on will stay blank for ever — that history cannot be
recovered, only added to from here.

---

## Prompt 26 — the dashboard went black *(current)*

**Original prompt, verbatim:**

> Now, what is happening? The dashboard is broken fully! Please do a deep dive
> and sanity check throughout the code and fix why this is happening. Also, when
> the model pops up showing the MCC code, I want you to keep on animating, as in
> keep it shimmering, after the most logical time. Second, as per user experience
> on the MCC

*(The prompt ends there. The second point is truncated mid-sentence and has NOT
been guessed at — it stays open until you send the rest.)*

| # | ID | To-do | Status |
|---|---|---|---|
| 26.1 | `F-84` | **The dashboard renders nothing.** Find it and fix it | ✅ `CrossAxisAlignment.stretch` on a Row inside a `SliverToBoxAdapter` |
| 26.2 | `F-84` | Deep dive + sanity check throughout | ✅ found three more defects, below |
| 26.3 | `F-85` | The MCC in the sheet must **keep shimmering** after the logical moment | ✅ repeating timeline, 1800 ms rest + 900 ms sweep |
| 26.4 | — | *"Second, as per user experience on the MCC…"* | 🔍 **truncated — held open, not invented** |

### What the deep dive found

| # | Defect | Where | Pre-existing? |
|---|---|---|---|
| 1 | `stretch` inside a sliver throws on layout and kills the whole `CustomScrollView` | `dashboard_page.dart` | No — I introduced it in prompt 25 |
| 2 | Ledger row overflows horizontally above 1.3× text scale | `ledger_row.dart` | **Yes — every build so far** |
| 3 | Last Capture row overflows at large text: a 40 px number becomes 64 px | `dashboard_page.dart` | Yes |
| 4 | First-run card: three lines of prose in a fixed-height box | `dashboard_page.dart` | Yes |
| 5 | `ConfidencePill` could not shrink — "Conflicting" is twice the width of "Likely" | `mcc_badge.dart` | Yes |

### The process failure behind it

`flutter analyze` and a suite of pure parser tests cannot see a layout error.
A green CI meant *"the code compiles"*, and it was reported as *"the app
works"*. [`dashboard_layout_test.dart`](../app/test/dashboard_layout_test.dart)
now lays the real screen out at three widths, empty and populated, at 1.0× and
1.6× text scale. It fails on the commit that shipped the black dashboard, and
it caught defect 2 — which nothing had ever been able to catch — on its first
run.

A bracket-balance pass over all 44 Dart files is also run before pushing now,
after a dangling `Text(` from one of these very fixes broke the parse and cost
a whole red run.

---

<!--
Template for the next entry:

## Prompt N — <short theme>

**Original prompt, verbatim:**

> …

| # | ID | To-do | Status |
|---|---|---|---|
-->
