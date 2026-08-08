# SWIP — Build and Run

> Written for `B-05`: you are a product designer and this is your first mobile app.
> Nothing is assumed. Follow it top to bottom once, and after that `flutter run` is all
> you need.
>
> **Time to first run: about 40 minutes**, most of it downloads.

---

## 1. Install the toolchain

### macOS (needed for iOS; recommended overall)

```bash
# Homebrew, if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install --cask flutter android-studio
xcode-select --install
```

### Windows / Linux (Android only)

Download Flutter from <https://docs.flutter.dev/get-started/install> and Android Studio
from <https://developer.android.com/studio>.

### Then, on any platform

```bash
flutter doctor
```

Fix every ✗ before continuing. The two that always need attention:

```bash
flutter doctor --android-licenses     # accept all
sudo gem install cocoapods            # macOS only, for iOS
```

---

## 2. Get the code

```bash
git clone <your-repo-url> SWIP
cd SWIP/app
```

---

## 3. Fetch the typeface — required

Inter is not committed (licence-clean, keeps the repo small). The build **will fail without
it**, on purpose: silently falling back to a different typeface would change every screen
you designed.

```bash
bash tool/fetch_fonts.sh
```

---

## 4. Run it

Plug in an Android phone with USB debugging on (Settings → About phone → tap *Build number*
seven times → Developer options → USB debugging), then:

```bash
flutter pub get
flutter run
```

You should see the S-01 dashboard with five sample captures. **That is the app running on
your phone.** The samples are debug-only and are stripped from release builds.

---

## 5. Test the real features

### QR (Vector 1) — works immediately

Point it at any UPI or merchant QR. Works offline, in any country.

### NFC tap (Vector 2) — Android only, needs a real terminal

1. NFC on in system settings.
2. Open Tap POS.
3. At a shop, ask the cashier to start a card payment, then hold the phone to the terminal.
4. **The terminal will show an error. That is correct** — SWIP reads the category and
   refuses to transact.

> **This is the week-1 job that matters most.** The `9F15` hit rate across real terminals
> decides how good this feature is and it cannot be looked up.
> Run the [50-terminal protocol](03-RESEARCH-MCC-CAPTURE.md#34-what-is-verified-and-what-must-be-field-tested)
> before you polish a single screen.

Watch the APDU conversation live:

```bash
adb logcat -s SwipListen
```

---

## 6. Useful commands

```bash
flutter run                       # debug, hot reload — press r to reload, R to restart
flutter test                      # unit tests
flutter analyze                   # linter; must be clean before every commit
dart format lib test              # formatter

node tool/build_mcc_table.mjs     # regenerate the bundled MCC table
node ../brand/generate.mjs        # regenerate every logo variant

flutter build apk --release       # Android, for sideloading
flutter build appbundle           # Android, for the Play Store
flutter build ipa                 # iOS, macOS only
```

**Hot reload is the thing to learn first.** Save a file and the running app updates in
under a second, keeping its state. As a designer you will spend most of your time in that
loop, and it is genuinely faster than moving a rectangle in Figma.

---

## 7. Where things live

| I want to change… | Go to |
|---|---|
| A colour, a font size, a corner radius | `lib/core/theme/swip_tokens.dart` |
| The dashboard | `lib/features/dashboard/dashboard_page.dart` |
| A ledger row | `lib/widgets/ledger_row.dart` |
| The MCC number component | `lib/widgets/mcc_badge.dart` |
| How QRs are read | `lib/data/sources/emv_qr_parser.dart` |
| How UPI links are read | `lib/data/sources/upi_uri_parser.dart` |
| What the NFC service asks the terminal | `android/.../SwipListenService.kt` → `PDOL` |
| The MCC list | `tool/build_mcc_table.mjs`, then regenerate |
| The logo | `../brand/generate.mjs`, then regenerate |

**Never hand-edit** `assets/mcc/mcc_table.json` or `brand/*.svg` — both are generated and
your edit will be overwritten.

---

## 8. Publishing

### Play Store

1. `flutter build appbundle`
2. Create the app at <https://play.google.com/console> (₹2,000 one-time).
3. **Declare the HCE service in the data-safety and permissions sections.** Say plainly
   that the app emulates a card to *read* a terminal's category code, holds no card
   number, and cannot make a payment. An unexplained payment-AID HCE service is the single
   most likely reason for rejection — see [12-COMPLIANCE-RISK](12-COMPLIANCE-RISK.md).
4. Closed testing with 12+ testers for 14 days is required for new personal developer
   accounts before production.

### App Store

1. `flutter build ipa` (macOS only), Apple Developer Program is $99/year.
2. Upload via Xcode or Transporter.
3. Expect a reviewer question about why an MCC app exists. Answer: it is a lookup and
   ledger tool; on iOS it does not touch NFC at all.

---

## 9. When it breaks

| Symptom | Fix |
|---|---|
| `Unable to load asset: assets/fonts/Inter-Regular.ttf` | Step 3 |
| `No devices found` | USB debugging on; `adb devices`; approve the prompt on the phone |
| Gradle fails on first build | Normal — it is downloading. Let it finish once |
| Nothing happens on NFC tap | NFC on? Tap screen open? Try the top third of the phone's back — the antenna is usually there |
| Tap works once, then never | Another wallet grabbed routing. Kill and reopen SWIP; foreground preference re-registers on resume |
| Something is deeply wrong | `flutter clean && flutter pub get && flutter run` |
