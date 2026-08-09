#!/usr/bin/env bash
#
# SWIP — one-time project bootstrap.
#
# WHY THIS EXISTS
# ---------------
# The repository carries SWIP's own Android sources (the HCE listen service,
# the APDU service descriptor, and a hand-written manifest) but not the
# generated Flutter platform scaffold: no Gradle files, no Gradle wrapper, no
# ios/ directory. Without those, `flutter run` cannot build anything.
#
# `flutter create` generates exactly that scaffold — but it also overwrites
# AndroidManifest.xml, which would silently delete the NFC/HCE registration
# that makes Vector 2 work. This script generates the scaffold and puts SWIP's
# own files back.
#
# RUN IT ONCE:
#     cd app
#     bash tool/bootstrap.sh
#     flutter run
#
# Safe to re-run. It only ever restores SWIP's files over generated ones.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
BACKUP="$(mktemp -d)"

echo "▸ SWIP bootstrap"
echo "  project: $ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "✗ flutter is not on your PATH."
  echo "  Install it first: https://docs.flutter.dev/get-started/install"
  exit 1
fi

# ── 1. Preserve SWIP's own Android sources ──────────────────────────────
echo "▸ Preserving SWIP's Android sources…"
if [ -d android/app/src/main ]; then
  mkdir -p "$BACKUP/main"
  cp -R android/app/src/main/. "$BACKUP/main/"
  echo "  saved to $BACKUP"
fi

# ── 2. Generate the missing platform scaffold ───────────────────────────
# --org must match the package in the Kotlin sources (in.swip.app), or the
# generated MainActivity lands in a different package and the build fails.
echo "▸ Generating Flutter platform scaffold (android + ios)…"
flutter create \
  --platforms=android,ios \
  --org in.swip \
  --project-name swip \
  . >/dev/null

# ── 3. Restore SWIP's files over the generated ones ─────────────────────
echo "▸ Restoring SWIP's manifest, HCE service and APDU descriptor…"

# The generated MainActivity is a plain FlutterActivity; ours is the same but
# is the one referenced by the manifest, so keep ours.
if [ -f "$BACKUP/main/AndroidManifest.xml" ]; then
  cp "$BACKUP/main/AndroidManifest.xml" android/app/src/main/AndroidManifest.xml
fi
if [ -d "$BACKUP/main/kotlin" ]; then
  # Remove the generated package dir so a stale duplicate MainActivity in a
  # different package cannot shadow ours.
  rm -rf android/app/src/main/kotlin
  cp -R "$BACKUP/main/kotlin" android/app/src/main/kotlin
fi
# Restore the whole res/ tree, not just res/xml. SWIP owns values/strings.xml
# (the Tap & pay description) and drawable/swip_hce_banner.xml as well as
# xml/apduservice.xml, and apduservice.xml references the other two — so
# restoring only xml/ leaves the manifest pointing at resources that do not
# exist and AAPT fails. The copy is additive, so the styles and mipmaps that
# `flutter create` generates survive alongside.
if [ -d "$BACKUP/main/res" ]; then
  mkdir -p android/app/src/main/res
  cp -R "$BACKUP/main/res/." android/app/src/main/res/
fi

# ── 4. iOS: the tap vector is Android-only, but the camera is not ───────
# Apple permits host card emulation for contactless payments in the EEA only,
# so Vector 2 never ships on iOS — but Vector 1 (QR) needs a camera usage
# string or iOS kills the app on first scan with no explanation.
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! grep -q NSCameraUsageDescription "$PLIST"; then
  echo "▸ Adding the iOS camera usage description…"
  /usr/libexec/PlistBuddy -c \
    "Add :NSCameraUsageDescription string 'SWIP uses the camera to read payment QR codes so it can show you the merchant category before you pay. Nothing is recorded or uploaded.'" \
    "$PLIST" 2>/dev/null || \
  python3 - "$PLIST" <<'PY'
import sys, re, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
entry = ("\t<key>NSCameraUsageDescription</key>\n"
         "\t<string>SWIP uses the camera to read payment QR codes so it can "
         "show you the merchant category before you pay. Nothing is recorded "
         "or uploaded.</string>\n")
s = s.replace("</dict>\n</plist>", entry + "</dict>\n</plist>", 1)
p.write_text(s)
PY
fi

# ── 4b. Align the Android package with the Kotlin sources ───────────────
#
# `flutter create --org in.swip --project-name swip` produces an applicationId
# of `in.swip.swip`, but SWIP's Kotlin sources declare `package in.swip.app`.
# The manifest refers to `.MainActivity` and `.SwipListenService` relatively,
# so a mismatch resolves to classes that do not exist — the APK builds and then
# dies with ClassNotFoundException the moment it launches. Pin both to the
# package the sources actually use.
echo "▸ Aligning the Android package to in.swip.app…"
for f in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$f" ] || continue
  sed -i \
    -e 's/in\.swip\.swip/in.swip.app/g' \
    -e 's/"com\.example\.swip"/"in.swip.app"/g' \
    "$f"
done

# ── 4b2. Force a modern compileSdk across every plugin ──────────────────
#
# Flutter plugins pin their own compileSdk, and they drift. file_picker 8.x
# compiles against android-34 while its own transitive dependency
# (flutter_plugin_android_lifecycle) now demands 36, so the build dies in
# checkDebugAarMetadata with no way to fix it from our own module.
#
# Chasing plugin versions is the wrong lever: share_plus and mobile_scanner
# have both had breaking API changes in their newer majors, and upgrading them
# to satisfy Gradle would mean rewriting working Dart. Overriding compileSdk
# for every android subproject fixes all of them at once and touches no code.
#
# compileSdk only controls which APIs are available at compile time — it does
# not change targetSdk (runtime behaviour) or minSdk (device support).
echo "▸ Forcing compileSdk 36 across plugin subprojects…"
if [ -f android/build.gradle.kts ]; then
  cat >> android/build.gradle.kts <<'KTS'

// Added by tool/bootstrap.sh — see the script for why.
// Reflection rather than a typed cast: the AGP classes are not guaranteed to
// be on the root project's classpath, and a ClassNotFound here would be a far
// more confusing failure than the one this fixes.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        runCatching {
            androidExt.javaClass.methods.firstOrNull {
                it.name == "compileSdkVersion" &&
                    it.parameterTypes.size == 1 &&
                    it.parameterTypes[0] == Int::class.javaPrimitiveType
            }?.invoke(androidExt, 36)
        }
    }
}
KTS
elif [ -f android/build.gradle ]; then
  cat >> android/build.gradle <<'GROOVY'

// Added by tool/bootstrap.sh — see the script for why.
subprojects {
    afterEvaluate { p ->
        if (p.hasProperty('android')) {
            p.android.compileSdkVersion 36
        }
    }
}
GROOVY
fi

# ── 4c. The round launcher icon ─────────────────────────────────────────
#
# The manifest declares android:roundIcon, but `flutter create` only ships
# ic_launcher. Without ic_launcher_round the resource linker fails outright:
#   AAPT: error: resource mipmap/ic_launcher_round not found
# Derive it from the square icon so the build is self-sufficient.
#
# TODO: replace both with renders of brand/swip-appicon.svg. These are the
# Flutter placeholder, not SWIP's mark.
echo "▸ Deriving the round launcher icon…"
for dir in android/app/src/main/res/mipmap-*; do
  [ -f "$dir/ic_launcher.png" ] || continue
  cp "$dir/ic_launcher.png" "$dir/ic_launcher_round.png"
done

# ── 5. Remove the scaffold's placeholder test ───────────────────────────
# `flutter create` writes test/widget_test.dart referencing a `MyApp` class
# that does not exist in this project, so it fails analysis every run. SWIP's
# real tests live alongside it and are untouched.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  echo "▸ Removing the generated placeholder test…"
  rm -f test/widget_test.dart
fi

# ── 6. Brand assets ─────────────────────────────────────────────────────
# brand/*.svg is generated by brand/generate.mjs and is the single source of
# truth. Copying rather than committing a second set keeps them from drifting;
# assets/brand/ is gitignored for the same reason.
echo "▸ Copying brand assets…"
mkdir -p assets/brand
cp ../brand/*.svg assets/brand/

# ── 7. Dependencies ─────────────────────────────────────────────────────
echo "▸ Fetching packages…"
flutter pub get

echo
echo "✓ Bootstrap complete."
echo
echo "  Next:"
echo "    flutter run              # plug in an Android phone, or start an emulator"
echo "    flutter analyze          # check for compile errors"
echo "    flutter test             # run the parser tests"
echo
echo "  Note: the NFC tap vector needs a PHYSICAL Android phone — an emulator"
echo "  has no NFC radio. QR scanning works in the emulator if you point its"
echo "  virtual camera at a QR on your screen."
