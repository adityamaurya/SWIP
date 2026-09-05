# 30 — Pre-launch parameters

> **Run this file before every debug APK, and in full before every store
> submission.** That instruction is the point of the document: a checklist run
> once before launch is a ritual, and a checklist run on every build is a gate.

The baseline below is adapted from the pre-launch security playbook you sent,
with the items that do not apply to SWIP **removed rather than ticked**. A
checklist with inapplicable lines on it trains you to skip lines.

---

## 0. What SWIP actually exposes — the map that comes first

You cannot check that a surface is protected until you have written the surface
down. Here is SWIP's, in full. It is unusually short, and that shortness is the
security posture.

| Surface | Present in SWIP? | Consequence |
|---|---|---|
| Public domain / web app | **No** | No web attack surface |
| API endpoints, webhooks | **No** | Nothing to rate-limit, nothing to authenticate |
| Server, database, storage bucket | **No** | No RLS to get wrong, no bucket to leave open |
| User accounts, login, password reset | **No** | The entire authentication section of the playbook is inapplicable |
| Third-party paid APIs | **No** | No spend to cap, no key to leak |
| Analytics / crash SDKs | **No** | Nothing phones home |
| Ad SDKs | **No** | No third-party data flows |
| **Local SQLite ledger** | Yes | The only store of user data |
| **Camera** | Yes | Reads a code; frames are never retained |
| **NFC / HCE** | Yes | Reads a category; SWIP never completes a payment |
| **Approximate location** | Opt-in | Reduced to a ~1.2 km geohash **on device** |
| **Export file** | Yes, user-triggered | The only way data leaves the phone, and the user is the one moving it |
| **`upi://pay` intent filter** | Yes | Accepts an intent from other apps — the one untrusted input |

**Six of the seven categories in that playbook do not apply to SWIP, and the
reason is architectural rather than lucky: there is no server.** The playbook's
own framing supports saying so — it says to run the baseline before exposing an
app that processes personal data on a backend, handles money, or calls paid
APIs. SWIP does none of those.

What is left is worth taking seriously, and it is the rest of this file.

---

## 1. Every build — the gate (about 4 minutes)

Run before **every** debug APK. If any line fails, the build does not go out.

```bash
#  1  Structure: no unbalanced brackets anywhere in lib/ or test/
python3 tool/check_balance.py

#  2  No secrets in the tree, ever
grep -rIn --exclude-dir=.git \
  -E 'rzp_(live|test)_|sk_live_|sk_test_|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY' . \
  && echo "SECRET FOUND - STOP" && exit 1

#  3  No network client has appeared by accident
grep -rn "package:http/\|package:dio/\|HttpClient(" app/lib/ \
  && echo "NETWORK CLIENT IN A NO-SERVER APP - JUSTIFY OR REMOVE"

#  4  Permissions in the manifest are still the four we can defend
grep -o 'android.permission.[A-Z_]*' app/android/app/src/main/AndroidManifest.xml | sort -u

#  5  Static analysis and the whole suite
cd app && flutter analyze --no-fatal-infos && flutter test
```

Then, and this is the line that has caught the most real defects in this
project: **read the APK job's log, not just the analyze step.** Two builds were
reported as green here while the APK job had failed, because reading stopped at
the first tick.

### The permission set, and why each one is defensible

| Permission | Why | If it cannot be defended in one sentence, it goes |
|---|---|---|
| `CAMERA` | Read a QR. No frame is stored, `returnImage` is never set | ✔ |
| `NFC` | Read a terminal's category. SWIP never completes a payment | ✔ |
| `ACCESS_COARSE_LOCATION` | Opt-in; reduced to a geohash on device before storage | ✔ |
| `INTERNET` | **Currently declared. Justify it or drop it** — SWIP has no server. See §4 | ⚠ |

---

## 2. Every release — the fuller pass (one focused sitting)

### 2.1 Privacy notice that matches reality

The playbook's first item, and the one most apps fail. SWIP's is unusually easy
to write **honestly**, and the honest version is also the marketing:

- No account. No email. No phone number. No advertising ID.
- Nothing is uploaded. There is no server to upload to.
- Camera frames are analysed and discarded, never written to disk.
- Location, if enabled, is reduced to a ~1.2 km cell **before** it is stored, and
  the precise coordinates never leave the sensor.
- The only export is one the user starts, to a destination the user picks.

**Check:** every sentence in the notice must be traceable to code. If a sentence
cannot be pointed at a file, it comes out.

### 2.2 Data Safety form (Play) and Privacy Nutrition Label (App Store)

Both must say **collected: none / shared: none**, because both are true. Declare
camera, NFC and approximate location as *used*, not *collected*.

### 2.3 The one untrusted input

SWIP registers a `upi://pay` intent filter, so any app on the phone can hand it
an arbitrary string. Everything downstream of that is parsing, and every parser
must be total.

**Check:**
- `qr_corpus_test.dart` includes the malformed, hostile and truncated payloads
- The resolver's invariant test — *"never throws, whatever it is handed"* — passes
- No payload is ever passed to a shell, a WebView, an eval, or a file path

### 2.4 What is written to logs

**Check:** no raw payload, VPA, amount or location is written with `print` or
`debugPrint` in a release build. A payment handle in a crash log is a data leak
with extra steps.

### 2.5 Ledger integrity

`F-127`. Exports carry a SHA-256 hash chain and a `sealHash`; import verifies it
and names the first record that does not match. See
[`ledger_seal.dart`](../app/lib/data/sources/ledger_seal.dart) — including its
statement of what it does **not** prove.

### 2.6 Dependencies

```bash
cd app && flutter pub outdated && flutter pub deps
```

Check each direct dependency against current advisories. The list is short
enough to read: `mobile_scanner`, `sqflite`, `riverpod`, `share_plus`,
`file_picker`, `geolocator`, `geocoding`, `flutter_svg`, `flutter_animate`,
`crypto`, `shared_preferences`, `path_provider`.

### 2.7 Two accounts reading each other's data

The playbook's central test. **Inapplicable, and provably so**: there is one
device, one local database, no accounts and no shared storage. There is no
second user whose data could be read. Written here so the next reader can see it
was considered rather than skipped.

---

## 3. The agent-safety items — these DO apply

The playbook's most transferable warning is not about servers. It is that a
capable agent with broad permissions is itself an attack surface, and this
project is built by one.

- **Treat an unfamiliar repository as hostile before an agent opens it.** Check
  its agent instructions, hooks, MCP configuration, `.env`, package scripts and
  editor tasks first. The GitLab/Serena `project.yml` disclosure is the live
  example: opening a repo executed attacker-controlled code.
- **This repository has no CI secrets today.** If a Razorpay or keystore secret
  is ever added, it goes in GitHub Actions **Secrets**, never in a file, and
  `.github/workflows/*` is reviewed on every change.
- **A secret that reaches a public repo is compromised.** Rotate first, then
  clean history. This repo was public for its whole build — treat every value
  ever committed as seen.
- **Keep a human approval gate** on anything irreversible: force-pushes,
  publishing to a store, and payment configuration.

---

## 4. Open items, stated rather than hidden

| # | Item | Status |
|---|---|---|
| 4.1 | `INTERNET` permission is declared but SWIP has no server. Establish which dependency needs it and drop it if none does. **A permission you cannot explain is a review question you cannot answer.** | 🔍 open |
| 4.2 | A signed release keystore does not exist yet. Everything so far is a debug APK | 📋 blocking release |
| 4.3 | Privacy policy is not yet published at a URL | 📋 blocking release |
| 4.4 | `upi://pay` intent filter: keep it and always forward, or drop it. Still your decision | 🔍 open |
| 4.5 | Release-mode log audit not yet run | 📋 |

---

## 5. What this file does not claim

Following it does not make SWIP secure, and no checklist does. Scanners miss
things, AI-suggested fixes introduce regressions, and a clean run proves only
that the things on the list were checked.

It does something narrower and more useful: **it stops a build going out
without anybody having looked.**

Re-run §1 on every build. Re-run §2 whenever the camera, the parsers, the
export format, the permissions, the intent filter or the dependency set change.

---

## Sources

- The pre-launch playbook you sent (Prajwal Tomar, 30 Aug) — the structure of §1 and §2
- [OpenAI's incident report](https://openai.com) on agents in a reduced-safeguard
  cyber evaluation — the reasoning behind §3
- [Play Console — Data safety](https://support.google.com/googleplay/android-developer/answer/10787469)
- [App Store — App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
