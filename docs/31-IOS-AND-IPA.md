# 31 — iOS: getting to an `.ipa`, and to the App Store

> *"let's plan for something as real as getting debug apk like stage for ios,
> now we have for Android what about ios? how can we get .ipa done for with
> exact thing and progress done but in ios simultaneously"*

The short answer, stated first because it changes the plan: **you can have an
iOS build artifact this week, and you cannot have a running iOS app on your own
phone without either a Mac or ~₹8,300/year, and there is no way around that.**

Everything below is arranged around that fact rather than pretending otherwise.

---

## 1. Why `.ipa` is not the same shape of problem as `.apk`

This is the thing to understand before spending money.

| | Android | iOS |
|---|---|---|
| Build machine | Any Linux CI runner | **macOS only.** Xcode does not exist for Linux, and this is licensing, not effort |
| Install an unsigned build | Yes — `adb install`, or tap the file | **No.** iOS refuses to launch an unsigned binary |
| Cost to run your own build on your own phone | ₹0 | **$99/year**, or a Mac you already own |
| CI minutes | 1× | **10× on GitHub-hosted macOS runners** |

That last row matters for the private-repo budget from
[26-PRIVATE-AND-PUBLISHING](26-PRIVATE-AND-PUBLISHING.md): the Free plan's 2,000
minutes are Linux minutes, and **a macOS minute is billed as ten**. A 15-minute
iOS build therefore costs 150 minutes. That is roughly **13 iOS builds a month**
before the allowance is gone — so iOS CI must be deliberate, not on every push.

### The three artifacts, and which is which

People say "IPA" for three different things and only one of them installs on
your phone:

1. **Simulator build** (`Runner.app`) — runs in the Mac simulator only.
   Unsigned. **This is the true equivalent of the debug APK for CI purposes**:
   it proves the code compiles, links and lays out on iOS.
2. **Unsigned `.ipa`** — builds on CI without any Apple account. Cannot be
   installed on a device. Useful as a build-integrity artifact and nothing else.
3. **Signed `.ipa`** — installs on registered devices, or goes to TestFlight.
   **Requires the $99/year Apple Developer Program.** No exceptions, no
   workaround.

**The honest recommendation: build #1 in CI now, at ₹0, and buy the $99 only
when you have a reason to hold the app in your hand on an iPhone.** It proves
the whole codebase is iOS-clean continuously, which is the thing that actually
rots if left unchecked.

---

## 2. What has to change in the code, and it is more than a build target

`flutter build ios` will not simply work. SWIP leans on four platform features,
and **two of them do not exist on iOS in the form SWIP uses them.**

| Feature | Android | iOS | Plan |
|---|---|---|---|
| QR camera | `mobile_scanner` | ✅ same plugin, AVFoundation | Works |
| Local SQLite | `sqflite` | ✅ | Works |
| Share / files / location | ✅ | ✅ | Works |
| **NFC "Tap POS"** | HCE reads EMV `9F15` | ❌ **Impossible** | See §2.1 |
| **Quick Settings tile** | `TileService` | ❌ no equivalent | Control Centre widget or Action Button, §2.2 |
| **`upi://pay` intent capture** | intent filter | ⚠️ partial | Custom URL scheme, §2.3 |
| **Floating scan bubble** | overlay window | ❌ **Impossible** | Widget + Shortcut, §2.4 |

### 2.1 NFC — the one real capability loss

`DashboardPage` already has `tapAvailable` and already dims the Tap tile with an
explanation rather than hiding it, so the UI is prepared. But be clear about the
reason, because it is not a limitation SWIP can engineer around:

**Apple's `CoreNFC` gives third-party apps reader mode for NDEF and ISO7816
tags. It does not give an app the ability to act as a payment terminal, and it
does not expose the EMV contactless kernel.** The `com.apple.developer.nfc.*`
entitlements that come close are restricted, and card emulation is reserved for
Apple Pay. So the `9F15` route — SWIP's most reliable MCC on Android — cannot
exist on iOS at all.

**Consequence for the product:** on iOS, SWIP is a QR-and-statement app. Route
coverage drops from four vectors to three. That must be said in the App Store
description, not discovered by a reviewer.

### 2.2 Quick Settings tile → Control Centre

iOS 18 added Control Centre controls (`ControlWidget`) and Action Button
support, which is the closest analogue to `SwipTile.kt`. Different API, same
one-swipe-to-scan idea. Written fresh in Swift; nothing ports.

### 2.3 Intent capture → URL scheme

iOS has no intent filter. SWIP would register a custom scheme and a Share
Extension. **A UPI checkout on iOS will not hand off to SWIP** the way Android's
chooser does, so the `APP DIRECT` vector is effectively Android-only too.

### 2.4 The floating bubble is impossible on iOS

Worth being blunt, because it is being designed right now (see §6 of the
implementation plan): **iOS has no `SYSTEM_ALERT_WINDOW` and no equivalent.** An
app cannot draw over other apps. The nearest approximations are a Home Screen
widget, a Control Centre control, the Action Button, or a Shortcut — all of
which are "leave the app you are in", not "float above it".

---

## 3. The CI pipeline, in the order to build it

### Stage 1 — iOS compiles (this week, ₹0)

A separate workflow, on `workflow_dispatch` plus a weekly schedule, **not on
every push** — because of the 10× minute multiplier.

```yaml
# .github/workflows/ios.yml
name: iOS
on:
  workflow_dispatch:
  schedule: [{ cron: '0 3 * * 1' }]   # Mondays, one build a week

jobs:
  simulator:
    runs-on: macos-15          # billed at 10x — see §1
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v5
      - uses: subosito/flutter-action@v2
        with: { channel: stable }
      - run: bash tool/bootstrap.sh
        working-directory: app
      - run: flutter build ios --simulator --debug
        working-directory: app
      - uses: actions/upload-artifact@v4
        with:
          name: swip-ios-simulator
          path: app/build/ios/iphonesimulator/Runner.app
          retention-days: 5     # the 500 MB trap, again
```

This is the real equivalent of today's debug APK job: it fails the moment
something in `lib/` stops being iOS-clean.

### Stage 2 — unsigned `.ipa` (same day, ₹0)

Add `flutter build ipa --no-codesign`, then zip `Runner.app` into
`Payload/Runner.app` and rename to `.ipa`. **It will not install on a phone.**
Its only job is to prove the archive step works before money is spent.

### Stage 3 — signed `.ipa` and TestFlight (after the $99)

Needs, in order: Apple Developer Program enrolment (24–48 h, sometimes longer
for a company), a Distribution certificate, an App ID with the entitlements SWIP
actually uses, a provisioning profile, then all of it as GitHub Actions
**Secrets** — never files in the repo, per
[30-PRE-LAUNCH-PARAMETERS §3](30-PRE-LAUNCH-PARAMETERS.md).

---

## 4. App Store review — where SWIP is genuinely exposed

Apple's review is stricter than Play's, and SWIP touches three of the sensitive
areas. Being ready for these is most of the work.

| Guideline | Risk | How SWIP answers |
|---|---|---|
| **2.1 App Completeness** | An app whose main feature is dimmed on iOS reads as unfinished | The Tap tile must explain *why*, and the listing must say iOS reads QR codes. Do not ship a dead button |
| **4.2 Minimum Functionality** | "It reads a number" could be judged too thin | It is not a wrapper: an offline MCC table, a merchant graph, a statement parser and a local ledger. Lead the listing with the ledger |
| **5.1.1 Data Collection** | Asking for anything unjustified | SWIP collects nothing. Location is opt-in, coarse, and reduced on device. This is a strength — say it |
| **5.1.1(v) Account Sign-In** | Requiring an account for no reason | No account exists. ✔ |
| **3.1.1 In-App Purchase** | **The donation flow.** Apple is stricter than Google | Apple permits donations to go outside IAP **only for approved non-profits**. A personal donation to a developer is *not* covered, and the usual outcome is rejection or forced IAP at 30%. **Recommendation: ship the iOS build with the support section hidden.** It is one flag, and it removes the single most likely rejection |
| **2.5.1 Private APIs** | NFC entitlements | Do not request `com.apple.developer.nfc.hce`. It will not be granted |
| **5.1.2 Data Use** | Privacy Nutrition Label must match | "Data Not Collected" throughout |

**The donation point is the one to internalise.** It is the highest-probability
rejection in the list, and the fix costs nothing on a platform where the
section would earn very little anyway.

---

## 5. The bill, and the honest recommendation

| Item | Cost | When |
|---|---|---|
| iOS-compiles CI | **₹0** | Now |
| Unsigned `.ipa` | **₹0** | Now |
| Apple Developer Program | **$99/yr (~₹8,300)** | Only when you need it on a phone |
| A Mac | ₹0 if borrowed; a Mac mini is the cheapest new option | Optional — CI replaces it for building, not for debugging |
| macOS CI minutes | Free tier at 10× — about 13 builds/month | Watch it |

Against Android's **$25 once**, iOS is **$99 every year, forever**, on a product
that loses its best capture route on that platform.

**So: do Stage 1 and 2 now, at zero cost, and keep the codebase provably
iOS-clean. Do not buy the $99 until Android is live on Play and you have a
reason.** Shipping Android first is not a compromise; it is the platform where
SWIP is a complete product rather than a reduced one.

---

## 6. Feature parity table — what an iOS user would actually get

| Feature | Android | iOS | Notes |
|---|---|---|---|
| QR scan → MCC | ✅ | ✅ | Identical |
| EMVCo / BharatQR | ✅ | ✅ | Pure Dart |
| Merchant graph, tiers, RuPay outlook | ✅ | ✅ | Pure Dart |
| Statement import | ✅ | ✅ | Pure Dart |
| Local ledger + sealed export | ✅ | ✅ | Pure Dart |
| **NFC Tap POS** | ✅ | ❌ | Apple does not expose the EMV kernel |
| **App-handover capture** | ✅ | ❌ | No intent chooser |
| Quick access from anywhere | Quick Settings tile | Control Centre / Action Button | Rewrite in Swift |
| Floating scan bubble | ✅ planned | ❌ | No overlay API on iOS |
| Support / donations | ✅ | **Hidden** | Guideline 3.1.1 |

Roughly **70 % of SWIP is pure Dart and ports for free.** The 30 % that does not
is the Android-only half of the capture strategy, and no amount of work changes
that.
