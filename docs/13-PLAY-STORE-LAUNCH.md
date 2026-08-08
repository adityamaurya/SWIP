# SWIP — Getting on the Play Store

> Written for someone who has never shipped an app. Every step, in order, with the real
> costs and the real waiting times. Nothing here assumes prior knowledge.
>
> **Verified August 2026.** Google changes these rules more often than you'd think — the
> Play Console help pages linked throughout are the authority if anything below disagrees
> with what you see on screen.

---

## 0. The short version

| | |
|---|---|
| **Total cash to launch** | **$25, once.** That's it. |
| **Total elapsed time** | **6–8 weeks** for a first-time personal account. Most of it is waiting, not working. |
| **The thing that will surprise you** | You cannot publish immediately. A new personal account must run a **closed test with 12 people for 14 unbroken days** before Google will even let you apply for production. |
| **The decision that changes everything** | Registering as an **organisation** instead of a person skips that 12-tester rule entirely. See §2 — read it before you pay. |

---

## 1. What it actually costs

| Item | Cost | Notes |
|---|---|---|
| **Google Play Console registration** | **US $25, one-time** | Never renews. Covers unlimited apps forever ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/6112435)) |
| Publishing an app | **₹0** | Free, always |
| App updates | **₹0** | Free, unlimited |
| Google's cut of your revenue | **0%** | SWIP v1 sells nothing. Only relevant if you add paid features — then 15% on the first $1M/year |
| Privacy policy hosting | **₹0–500/yr** | Required (§7). GitHub Pages is free and fine |
| Apple App Store, later | **$99 / year, recurring** | Not needed now. Noted so it doesn't ambush you |
| A real Android phone for testing | you probably own one | The NFC tap vector **cannot** be tested on an emulator |

**Payment gotchas, India:** prepaid cards are rejected. Use a regular credit or debit card.
International transactions must be enabled on the card, and the charge appears in USD, so
expect a small forex markup. If it declines, try a different bank's card before assuming
something is wrong with your account.

---

## 2. Decide this before you pay: Personal or Organisation

This is the single highest-leverage decision in the whole process, and it is easy to get
wrong because the signup flow makes them look equivalent.

| | **Personal account** | **Organisation account** |
|---|---|---|
| Fee | $25 | $25 |
| **12 testers for 14 days?** | **Yes — mandatory** | **No — exempt** |
| What you must provide | Government ID, address, phone | Same, **plus a D-U-N-S number** |
| Time to get started | Days | **~2–4 weeks** (D-U-N-S takes ~30 days, free) |
| Publishes as | Your legal name | Your company name |

The **12 testers / 14 days** rule applies to every personal developer account created after
**13 November 2023**. It was 20 testers; Google cut it to 12 in December 2024. The 14-day
window has never changed.
([Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465))

It is stricter than it sounds. Twelve **real people**, on twelve **different devices**, who
each opt in and stay opted in **continuously**. If one drops out on day 9, the streak can
reset. Adding twelve email addresses to a spreadsheet does nothing — each person must
actually install and open the app.

> ### My recommendation
> **If you have or can register a company, go organisation.** Apply for the free D-U-N-S
> number today, in parallel with everything else — it takes about 30 days, which is roughly
> the same as the tester grind, but it's a form instead of herding twelve friends for a
> fortnight, and it makes SWIP look like a business rather than a hobby to the first
> airline or bank you talk to.
>
> **If you want to move now, go personal**, and start recruiting your 12 testers in week 1,
> not week 5. It is the long pole and everyone underestimates it.
>
> You cannot convert a personal account to an organisation one later without starting over.

---

## 3. Create the account

1. Use a **dedicated Google account**, not your personal Gmail. Something like
   `dev@swip.app`. You may want to hand this to a colleague one day, and you cannot
   transfer it easily.
2. Go to **[play.google.com/console](https://play.google.com/console)** → *Create developer
   account*.
3. Choose Personal or Organisation per §2.
4. Fill in: legal name, address, phone, contact email.
5. **Pay the $25.**
6. **Identity verification.** Google will ask for a government photo ID and proof of
   address. **Your name and address must match the documents exactly** — a mismatch here is
   the most common cause of a multi-week delay.

⏱ **Expect 2–7 days.** Sometimes same-day, occasionally three weeks. You can do §4–§8
while you wait.

---

## 4. Get the app build-ready

Work through `docs/09-BUILD-AND-RUN.md` first so `flutter run` works on your own phone.
Then:

### 4.1 Lock the package name — permanent

In `app/android/app/build.gradle`, `applicationId` becomes SWIP's identity on Play
**forever**. It cannot be changed after your first upload. Use reverse-domain form:

```
applicationId "app.swip.mcc"      // or in.swip.app, com.swip.android …
```

Pick one you'd still be happy with in five years, and register the matching domain.

### 4.2 Create a signing key — and back it up

Every Android app is cryptographically signed. Lose the key and you lose the ability to
update your own app.

```bash
keytool -genkey -v -keystore ~/swip-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias swip
```

> ⚠️ **Back up `swip-upload-key.jks` and its password in at least two places** — a password
> manager and an encrypted cloud folder. Not in the git repo. **Never in the git repo.**
>
> Do turn on **Play App Signing** (Google offers it during your first upload; accept). It
> means Google holds the real distribution key, so if you lose *your* upload key, support
> can reset it instead of your app becoming permanently un-updatable.

### 4.3 Build an App Bundle, not an APK

Play requires `.aab` for new apps.

```bash
cd app
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

### 4.4 Version numbers

In `app/pubspec.yaml`: `version: 1.0.0+1`. The number after `+` is the **versionCode** and
must increase on **every single upload**, forever. Play rejects a repeat. `1.0.0+2`,
`1.0.1+3`, and so on.

### 4.5 Target API level

Play enforces a minimum `targetSdkVersion` that ratchets up every year, with a deadline
around **31 August**. Check the current requirement in Play Console before you build — if
you are below it, upload is blocked outright.

---

## 5. Store listing assets

Prepare these before you open the listing form; it's much faster than doing it inline.

| Asset | Spec | For SWIP |
|---|---|---|
| **App icon** | 512×512 PNG, 32-bit | `brand/swip-appicon.svg` → export at 512 |
| **Feature graphic** | **1024×500** PNG/JPG | Required. Gold wordmark on Ink. No small text — it gets cropped |
| **Phone screenshots** | 2–8, min 1080px on the short side | Use 5: hero capture, the reveal, ledger, tap screen, MCC detail |
| **App name** | ≤ 30 chars | `SWIP — Know your MCC` |
| **Short description** | ≤ 80 chars | *"See a purchase's category code before you pay."* |
| **Full description** | ≤ 4000 chars | Lead with the problem, not the feature |

**Screenshot advice that matters more than it should:** most people decide from screenshot
one. Do not use a bare screen capture — put the screen on a clean Ink background with one
line of text above it saying what it does. Your first screenshot should be the MCC reveal.

---

## 6. Content rating

Play Console → *Content rating* → fill the IARC questionnaire. SWIP is a utility with no
violence, gambling or user-generated content, so this takes five minutes and returns
*Everyone / PEGI 3*.

**Answer honestly.** A rating obtained through wrong answers is grounds for removal.

---

## 7. Privacy policy — required, no exceptions

You need a **publicly reachable URL**. Free option: a `privacy.md` in a public GitHub repo
with GitHub Pages on.

SWIP v1 is in an unusually strong position here — **no account, no server, no personal data
leaves the device** — and your policy should say exactly that, because it is a genuine
selling point. It must cover: what you collect (device-local capture history), what you
transmit (in v1, nothing), permissions used and why (camera for QR, NFC for tap), and a
contact email.

---

## 8. The Data safety form

Separate from the privacy policy, and stricter. Play Console → *App content* → *Data
safety*. You declare every data type collected or shared.

For SWIP v1 the honest answers are mostly "no data collected". **Do not tick boxes
defensively.** Google cross-checks declarations against observed app behaviour, and a
mismatch gets apps pulled. If you later add sync or accounts, you must update this form
**before** shipping that release.

---

## 9. SWIP-specific declarations — read this section twice

These are where *this* app, specifically, can get stuck.

### 9.1 Financial features declaration (mandatory for India)

Any app with financial features must complete the **Financial features declaration** to be
available on Google Play in India.
([Play Console Help](https://support.google.com/googleplay/android-developer/answer/13849271))

For **v1**, SWIP shows category codes. It does not lend, hold funds, or process payments —
so you are declaring what it *isn't*. Do complete the form; don't skip it.

**v2 is a different conversation.** The moment SWIP holds a balance, issues a card, or sells
travel credit, you are in regulated territory and need the structure in
`docs/12-COMPLIANCE-RISK.md` in place first. Do not ship v2 features under a v1
declaration.

RBI's digital-lending rules and the associated Play requirements apply to **personal loan**
apps. SWIP does not lend, so they don't apply — but this is the area Google polices hardest
in India, so keep the listing free of any language that could read as credit provision.

### 9.2 The NFC tap feature is your real review risk

I could not find a Play policy that forbids an app registering an HCE payment AID, and
Android openly documents the capability
([Android HCE overview](https://developer.android.com/develop/connectivity/nfc/hce)). But
understand how this looks to a reviewer: **an app that emulates a payment card, taps real
terminals, and deliberately causes declines.**

Protect yourself:

- **Explain it in the listing.** One line in the full description: *"SWIP reads a terminal's
  merchant category and stops. No payment is made and no card details are stored or
  transmitted."*
- **Explain it in review notes.** The submission form has a *Notes for review* box. Use it.
  State that no PAN exists, no transaction is created, and the session is terminated with
  `SW=6985`.
- **Keep the in-app copy honest** — screen `S-03` already says the terminal will error.
- **Have the field-test data ready** (`docs/03-RESEARCH-MCC-CAPTURE.md` §3.4) in case a
  reviewer asks what the feature does.

If tap is what gets you rejected, **ship v1 without it**. Scan-QR and link-check are fully
independent, carry no review risk, and let you start the 12-tester clock immediately. Add
tap in v1.1 with a track record behind you.

### 9.3 Trademark

`docs/12-COMPLIANCE-RISK.md` flags that "SWIP" is not yet cleared in classes 36 and 42.
Play will happily publish an infringing name and then remove it on a complaint. Get
clearance moving before you spend on launch creative.

---

## 10. Closed testing — the 12-tester gauntlet

*Skip entirely if you registered as an organisation.*

1. Play Console → *Testing* → **Closed testing** → create a track.
2. Upload your `.aab`.
3. Create an email list of **at least 12 testers** — I'd add **16–18**, because people drop
   out and dropping below 12 can reset your clock.
4. Send them the opt-in link. **Each person must click it and install.**
5. **Wait 14 continuous days**, keeping ≥12 opted in the whole time.
6. Ask them to actually open the app and send you feedback. Google looks at engagement, not
   just headcount.

**Where to find 12 people:** friends and family with Android phones, a college or work
group, and r/CreditCardsIndia or Technofino — the points-and-miles community *is* your
target user and will genuinely want this. Do not buy testers from a "12 testers" service;
Google detects the pattern and it can cost you the account.

Start this the day your account clears verification. It is the long pole in the entire
project.

---

## 11. Apply for production, then launch

1. After 14 days, Play Console shows **Apply for production**. Apply.
2. Google reviews — typically a few days, occasionally two weeks for a first app.
3. Once granted: *Production* → create release → upload the `.aab` → *Review release* →
   **Start rollout**.
4. Use a **staged rollout: 20% first.** If crash-free sessions look bad, you can halt it.
   Going straight to 100% on a first launch is a needless risk.
5. Live within a few hours of approval.

---

## 12. Realistic timeline

| Week | What is happening |
|---|---|
| **1** | Register + pay $25 · start D-U-N-S if organisation · **start recruiting testers** · finish the build |
| **2** | ID verification clears · assets and listing written · privacy policy live |
| **3** | Upload to closed testing · testers opt in · **14-day clock starts** |
| **4–5** | Clock runs. Fix what testers report. Field-test the NFC vector on 50 terminals |
| **6** | Apply for production · review |
| **7** | Staged rollout to 20% → 100% |

Organisation accounts can compress this to about 3 weeks, gated on D-U-N-S.

---

## 13. Do these five things this week

1. **Decide personal vs organisation** (§2). Everything else branches off it.
2. **Register the $25 account** and get ID verification started — it's pure waiting time.
3. **Lock the package name** and **create + back up the keystore** (§4.1, §4.2).
4. **Start recruiting testers** if personal. Twelve is more than it sounds.
5. **Field-test the NFC vector on 50 terminals** (`03-RESEARCH` §3.4). This is the one
   number that decides whether tap ships in v1 at all — and §9.2 says it may be smarter to
   launch without it regardless.

---

## Sources

- [Get started with Play Console](https://support.google.com/googleplay/android-developer/answer/6112435)
- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Financial features declaration](https://support.google.com/googleplay/android-developer/answer/13849271)
- [Financial Services policy](https://support.google.com/googleplay/android-developer/answer/9876821)
- [Android host-based card emulation](https://developer.android.com/develop/connectivity/nfc/hce)
