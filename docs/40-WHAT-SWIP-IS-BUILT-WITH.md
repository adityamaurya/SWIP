# 40 — What SWIP is built with

> *"he asked me in detail to the core as to where, how and on what technologies
> am I building my app, I was clueless… can you please make a secret and
> separate md file where you mention every little technology, library etc used
> to make this app so that I can read and be aware."* — prompt 48

**This page is for you, not for the app.** It is the whole stack in the order a
developer will ask about it, with the reason each choice was made — because
"we use Flutter" is an answer that invites the next question, and "we use
Flutter because the capture surfaces are native anyway and the UI is the part
that had to move fast" ends it.

**One honest note about "secret".** Nothing in a git repository is secret — this
file is in the same repo as everything else and anyone with the link can read
it. What it *is* is separate and written for you. The only genuinely secret
things in this project are the keys, and those have never been in the
repository at all (§10).

---

## 0. The one-paragraph answer

> *SWIP is an Android-first Flutter app — Dart 3 on Flutter stable, Riverpod for
> state, SQLite on-device via sqflite, with a native Kotlin layer for the three
> things Flutter cannot reach: an NFC host-card-emulation service that answers
> a payment terminal, a `SYSTEM_ALERT_WINDOW` overlay service for the floating
> button, and a second transparent Activity running its own Flutter engine for
> the hovering scanner. There is no backend, no account and no analytics — the
> ledger is a local SQLite database with a SHA-256 hash chain over it. CI is
> GitHub Actions: analyze, Flutter widget tests, Kotlin JVM unit tests, five
> custom static checks, and a debug APK artifact.*

If he asks one more question, it will be *"why no backend?"* The answer is in
§9.

---

## 1. Languages

| Language | Where | How much |
|---|---|---|
| **Dart 3** | The whole app UI and all business logic | ~22,800 lines across 70 files in `app/lib/` |
| **Kotlin** | The Android platform layer | ~4,600 lines across 12 files in `app/android/…/in/swip/app/` |
| **Python 3** | Build-gate scripts, the trace reader | `app/tool/*.py` |
| **JavaScript (Node ESM)** | Two code generators run in CI | `app/tool/*.mjs` |
| **Bash** | The bootstrap script and the secret scanner | `app/tool/bootstrap.sh`, `check_secrets.sh` |
| **XML** | Android manifest, themes, drawables, the HCE AID list | `app/android/app/src/main/res/`, `AndroidManifest.xml` |

Not TypeScript, not React Native, not Kotlin Multiplatform. If he asks why not
KMP: the shared layer here is *business logic that draws screens*, which is
what Flutter is good at, and the native layer is three Android-only APIs with
no iOS counterpart to share with (§8).

---

## 2. The framework and the toolchain

| | |
|---|---|
| **Flutter** | stable channel, currently **3.47.4** in CI |
| **Dart** | the SDK bundled with that Flutter |
| **Java** | **Temurin JDK 17** (`actions/setup-java@v5`, distribution `temurin`) |
| **Gradle / AGP** | whatever `flutter create` generates, with `compileSdk` forced to **36** across every plugin subproject by `bootstrap.sh` |
| **Android min / target** | set by the generated manifest; `FOREGROUND_SERVICE_SPECIAL_USE` and `overrideActivityTransition` mean the interesting behaviour is **API 34+**, with runtime fallbacks below |

**`compileSdk 36` is forced for a reason worth knowing**, because it is the kind
of thing an agency will have hit too: Flutter plugins pin their own
`compileSdk` and they drift, so one plugin on 33 and another on 34 fails the
Gradle build with an error that names neither. `bootstrap.sh` rewrites them all
after `flutter pub get`. `compileSdk` only controls which APIs are available at
compile time — it does not change `targetSdk` (runtime behaviour) or `minSdk`
(which devices can install).

---

## 3. Flutter packages, and why each one is there

Everything in `app/pubspec.yaml`. The "why" column is the part that matters —
an agency owner will recognise all of these, so the interesting answer is the
reasoning.

### State, navigation, storage

| Package | Version | Why this one |
|---|---|---|
| `flutter_riverpod` | ^2.5.1 | State. The **classic, non-codegen API** on purpose, so `flutter run` works with no `build_runner` step |
| `go_router` | ^14.2.0 | Routing |
| `sqflite` | ^2.3.3 | The ledger. Hand-written DAOs rather than an ORM — see `docs/08-ARCHITECTURE` |
| `path`, `path_provider` | ^1.9.0, ^2.1.3 | Where the database and exports live |
| `shared_preferences` | ^2.2.3 | Small settings: theme, snooze, the bubble's switch |

### Capture — the actual product

| Package | Version | Why this one |
|---|---|---|
| `mobile_scanner` | ^5.1.1 | QR scanning (wraps **Google ML Kit Barcode Scanning** on Android) |
| `sensors_plus` | ^6.0.1 | The accelerometer, so the scanner only works while the phone is *aimed* |
| `crypto` | ^3.0.3 | SHA-256 for the ledger's hash chain |
| `cryptography` | ^2.7.0 | **AES-GCM + PBKDF2** for the encrypted backup |
| `bip39` | ^1.0.6 | The 12-word recovery phrase for that backup |

### Location, money, presentation, files

| Package | Version | Why this one |
|---|---|---|
| `geolocator` | ^13.0.1 | Opt-in coarse fix — reduced to a 6-character geohash (~1.2 km) *before* anything is stored |
| `geocoding` | ^3.0.0 | Turns that coarse fix into "Bandra, IN" for the ledger |
| `in_app_purchase` | ^3.2.0 | Google Play Billing, for the one paid surface. A **one-time managed product**, never a subscription |
| `flutter_svg` | ^2.0.10+1 | The brand marks |
| `intl` | ^0.19.0 | Dates and currency |
| `flutter_animate` | ^4.5.0 | Motion. Declarative, composable off any widget via `.animate()` |
| `share_plus` | ^10.0.2 | Writing the export out |
| `file_picker` | ^8.1.2 | Reading a backup back in |

### Test-only

| Package | Why |
|---|---|
| `flutter_test` | The widget test framework |
| `flutter_lints` ^4.0.0 | The lint set `flutter analyze` enforces |
| `sqflite_common_ffi` ^2.3.3 | **The database layer is only testable because of this.** `sqflite` talks over a platform channel, which does not exist in `flutter test`; this is the official FFI backend that runs real SQLite on the host |

**There is deliberately no HTTP package.** No `http`, no `dio`. There is one
network call in the whole app (§6) and it goes through an injected transport so
that the build gate can keep failing on any HTTP client added anywhere else.

---

## 4. The native Android layer

This is the half an agency will not expect, and it is where the product
actually lives. Twelve Kotlin files in `app/android/app/src/main/kotlin/in/swip/app/`.

| File | What it is |
|---|---|
| **`MainActivity.kt`** | The Flutter host. Owns the `MethodChannel`, the NFC reader, and the launch-intent plumbing (quick-settings tile, *Tap POS*, *View all*) |
| **`SwipListenService.kt`** | **The HCE service.** A `HostApduService` that answers a payment terminal's APDUs — this is what makes "tap a card machine" work at all |
| **`SwipBubbleService.kt`** | ~1,700 lines. The floating button: a `TYPE_APPLICATION_OVERLAY` window driven by a foreground service, with spring physics, a drag-to-snooze target and shake-to-restore |
| **`SwipHoverActivity.kt`** | A transparent Activity running a **second Flutter engine**, so the scanner can appear over another app |
| **`BubblePark.kt`** | Pure arithmetic for where the bubble may rest. No Android imports, so it is unit-testable |
| **`ShakeDetector.kt`** | Pure accelerometer maths. Same reason |
| **`BubbleTrace.kt`** | A temporary JSONL flight recorder, gated on `FLAG_DEBUGGABLE` — see `docs/38` |
| **`SwipBootReceiver.kt`** | Restarts the bubble service after a reboot |
| **`SwipTile.kt`** | The quick-settings tile |

### Android APIs used directly

`HostApduService` (NFC HCE) · `WindowManager` + `TYPE_APPLICATION_OVERLAY` ·
foreground services with `specialUse` type · `SensorManager` /
`TYPE_ACCELEROMETER` · `androidx.dynamicanimation` (`SpringAnimation`,
`FlingAnimation`) · `TileService` · `BroadcastReceiver` ·
`overrideActivityTransition`.

### The one Gradle dependency SWIP adds itself

```
implementation 'androidx.dynamicanimation:dynamicanimation:1.0.0'
```

~50 KB, first-party. It is what makes the floating button feel like an object
rather than a slideshow: a spring has no duration, only a rest position and a
start velocity. The alternative was Facebook Rebound or hand-rolled easing, and
hand-rolled easing is exactly what made the old version feel sticky.

Plus **JUnit 4** for the Kotlin unit tests.

### Permissions in the manifest

`CAMERA` · `NFC` · `INTERNET` · `SYSTEM_ALERT_WINDOW` · `FOREGROUND_SERVICE` ·
`FOREGROUND_SERVICE_SPECIAL_USE` · `POST_NOTIFICATIONS` ·
`RECEIVE_BOOT_COMPLETED` · `ACCESS_COARSE_LOCATION`.

Nine, and every one is asked for by a feature you can point at. Notably
**absent**: `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, which was declined on
policy grounds.

---

## 5. How the two capture paths actually work

Worth being able to say out loud, because this is the technical core.

### QR (Vector 1)

Camera → `mobile_scanner` → **Google ML Kit Barcode Scanning** → a raw string.
That string is then parsed by **SWIP's own code**, not by a library:

* `upi://` deep links are parsed as a URI with query parameters (`pa`, `pn`,
  `mc`, `mode`, `purpose`, `sign`, `tr`, `cu`, …)
* **EMVCo Merchant-Presented Mode** payloads are parsed as TLV — 2-digit tag,
  2-digit length (**in bytes, not characters**), value — with a
  **CRC-16/CCITT-FALSE** checksum verified over the payload including the
  `6304` tag

The MCC is EMVCo **tag 52**, or the `mc=` parameter on a UPI link.

### NFC (Vector 2)

This is host card emulation. Android routes HCE **by AID**, and every terminal
opens the conversation with `SELECT 2PAY.SYS.DDF01` — so the PPSE AID
`325041592E5359532E4444463031` has to be registered in `apduservice.xml` or a
tap does *nothing at all*. SWIP answers the PPSE SELECT, then a `GPO`, reads
what the terminal volunteers, and declines with `SW=6985`. It never completes a
payment.

---

## 6. The backend (there isn't one)

**No server. No account. No analytics. No crash reporting.** The ledger is a
local SQLite database.

Exactly one network call exists in the entire app, it is **off by default**, and
it needs a key the user supplies themselves:

```
POST https://api.razorpay.com/v1/payments/validate/vpa
```

It resolves a payment address to the merchant's registered name — the thing
CRED shows. It **does not return an MCC**; no commercial API does. See
`docs/41` for what it is, what it costs, and how to set it up.

---

## 7. Data and integrity

| | |
|---|---|
| **Database** | SQLite via `sqflite`, four tables — `captures`, `merchant_graph`, `merchant_alias`, `prefs` — with three indexes on `captures` |
| **Migrations** | Hand-written, versioned `onUpgrade` |
| **Ledger seal** | A **SHA-256 hash chain**: each entry's hash covers the one before it, so a file edited anywhere fails verification from that point on |
| **Merkle tree** | Over the chain, which buys *selective disclosure* — you can prove one capture without revealing the rest |
| **Encrypted backup** | **AES-GCM**, key derived by **PBKDF2**, unlocked by a **BIP-39** 12-word phrase |
| **Plain export** | One readable line per capture, for people who just want their data |

---

## 8. Platforms

**Android-first, and Android-only for the interesting parts.** Two of the three
native features have no iOS equivalent and cannot get one:

* **NFC "Tap POS"** — Apple does not expose the EMV kernel to third-party apps.
* **The floating bubble** — iOS has no overlay API. None. It is not a
  permission you can ask for.

`docs/31` has the detail and what an `.ipa` would and would not contain.

---

## 9. Build, CI and the quality gate

**GitHub Actions**, `ubuntu-latest`, two jobs.

### Job 1 — "Analyze and test"

1. `actions/checkout@v5`, `actions/setup-java@v5` (Temurin 17),
   `subosito/flutter-action@v2` (stable, cached)
2. **Regenerate the QR corpus** and fail if the committed fixture is stale
3. `bootstrap.sh` — `flutter create` the platform folders, force `compileSdk`,
   inject Gradle deps, copy brand assets
4. The five custom checks (below)
5. `flutter analyze`
6. `flutter test` — **365 tests**
7. A **Report** step that reads each step's `outcome`

**That last step exists because of a real trap:** GitHub's jobs API reports
`conclusion: success` for every `continue-on-error` step, whatever actually
happened. The Report step is the only thing in that job worth believing.

### Job 2 — "Build debug APK"

Builds the APK, runs `./gradlew :app:testDebugUnitTest` (**31 Kotlin tests**),
then **parses the JUnit XML and fails if zero tests ran** — because a suite that
silently stops running passes forever. Uploads `app-debug.apk` as an artifact.

### The five custom checks (`app/tool/`)

| Script | Catches |
|---|---|
| `check_balance.py` | Unbalanced brackets |
| `check_const.py` | `const X(… .withValues(…))`, which is not constant |
| `check_wiring.py` | **Seven shapes of code that is finished, correct and unreachable** |
| `check_links.py` | Documentation links pointing at nothing |
| `check_secrets.sh` | A key that must never reach the repository |

`check_wiring.py` is the one to mention if he asks what is unusual about this
codebase. It exists because **four separate times** a feature was built, tested
and never connected — a switch writing a preference nothing read, a file
imported only by its own test, a callback declared and called but never
supplied. None of those is catchable by a test: every piece works, and what is
missing is the wire.

### Test totals

| | |
|---|---|
| Flutter tests | **365**, in 27 files (~6,100 lines) |
| Kotlin JVM tests | **31**, in 3 files |
| Static checks | 5 scripts, 7 wiring rules |

---

## 10. Secrets, and where they are not

**There is not one key in this repository and there never will be.** The
`check_secrets.sh` script fails the build on any.

* A **Razorpay secret compiled into an APK is public the moment that APK
  ships** — anyone can unzip it. So there is none, and the user enters their
  own if they want the feature.
* Keystore and signing material belong in **GitHub Actions Secrets**, never in
  the tree.

---

## 11. Documentation, which is itself part of the stack

41 markdown files, ~16,000 lines in `docs/`. Not decoration — three of them are
enforced:

* `docs/21` — **every prompt you have ever sent, verbatim and timestamped**
* `docs/CHANGELOG.md` — what changed each round
* `docs/28` — what was answered each round
* `docs/35` — every ask with its status
* `docs/36` — every deviation from the original idea, including the ones that
  were reversed

`check_links.py` fails the build if any link between them breaks.

---

## 12. If he asks these five, here are the answers

**"Why Flutter and not native?"**
The capture surfaces *are* native — HCE, the overlay window, the second engine.
Flutter is carrying the UI, the ledger and the parsing, which is where iteration
speed matters and where nothing platform-specific happens.

**"Why no backend?"**
Because "nothing leaves your phone" is the product's main claim, not a
cost-saving. Adding a server would mean a privacy notice, a breach surface and
a thing to keep running. The one network call is off by default and uses the
user's own key.

**"How do you get the MCC?"**
From the QR payload — EMVCo tag 52 or the `mc=` parameter — or from the POS
terminal over NFC. And the honest half: **most Indian QRs do not carry one.**
`docs/42` is 52 real market QRs with the exact numbers.

**"What's your test coverage?"**
365 Flutter tests, 31 Kotlin, five static checks, and a CI step whose only job
is to fail if the test suite stops running.

**"Who else is doing this?"**
CRED shows a merchant name and hedges with *"merchant **may** not accept RuPay
CC"* — the word *may* is the tell that they are inferring too. No public API
returns an MCC; it lives in the acquirer's switch.

---

## 13. Where to read further

| Topic | File |
|---|---|
| Architecture in depth | [`08-ARCHITECTURE`](08-ARCHITECTURE.md) |
| How an MCC can be captured at all | [`03-RESEARCH-MCC-CAPTURE.md`](03-RESEARCH-MCC-CAPTURE.md) |
| Why the QRs would not scan | [`29-QR-DETECTION-FORENSICS.md`](29-QR-DETECTION-FORENSICS.md) |
| The build gate | [`30-PRE-LAUNCH-PARAMETERS.md`](30-PRE-LAUNCH-PARAMETERS.md) |
| iOS, and the `.ipa` question | [`31-IOS-AND-IPA.md`](31-IOS-AND-IPA.md) |
| The floating bubble | [`32-FLOATING-BUBBLE.md`](32-FLOATING-BUBBLE.md) |
| **The Razorpay key, explained** | [`41-RAZORPAY-EXPLAINED.md`](41-RAZORPAY-EXPLAINED.md) |
| **52 real market QRs, decoded** | [`42-MARKET-QR-CORPUS.md`](42-MARKET-QR-CORPUS.md) |
| Other people's floating overlays | [`39-FLOATING-OVERLAY-PRIOR-ART.md`](39-FLOATING-OVERLAY-PRIOR-ART.md) |
