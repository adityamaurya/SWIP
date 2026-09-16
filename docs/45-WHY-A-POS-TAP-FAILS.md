# 45 — Why a POS tap fails, and the black box that will say which

> *"Firstly, can we also get some foolproof method of tapping any POS machine
> and getting the MCC code, if possible?… I'm not sure what the issue is with
> the POS tapping. Some happen to be successful, and a few fail. The major
> issue is that I don't know what the issue is."* — prompt 49

**"I don't know what the issue is" is the actual problem**, and it is the same
shape as the disappearing floating button: every way a tap can fail looks
identical from outside. Phone against terminal, nothing happens.

`F-187` builds the instrument. This page is what it is looking for.

---

## 1. The seven ways a tap fails

In the order they occur, because the order is the diagnosis.

| # | What went wrong | Whose fault | Fixable by the user? |
|---|---|---|---|
| 1 | **The phone has no NFC hardware** | The phone | No |
| 2 | **NFC is switched off** | Settings | **Yes** |
| 3 | **SWIP is not the default contactless payment app** | Settings | **Yes** |
| 4 | **The screen is off, or the phone is locked** | The moment | **Yes** |
| 5 | The terminal never sent a `SELECT` we recognise | The terminal | No |
| 6 | The terminal selected us and never asked for processing options | The terminal | Partly — hold it longer |
| 7 | It answered, and every value was padding | The acquirer | No |

**Four of seven are the phone, and three of those the user can fix in under a
minute.** That is the headline: most failures are not the terminal at all.

---

## 2. Number 3 is almost certainly what you hit

> *"Some happen to be successful, and a few fail."*

That pattern — intermittent, no obvious cause — is the signature of the
default-payment-app slot.

**Android routes the entire contactless field to exactly one app.** Not to
whichever app is open; to whichever app holds the *default contactless payment*
setting. On any phone with Google Wallet set up, that is Wallet — so the
terminal's commands go to Wallet and **SWIP never sees a single byte**.

SWIP has one lever against this, and it is a partial one:
`CardEmulation.setPreferredService`, which routes to SWIP **only while SWIP's
own screen is in the foreground**. That is why taps sometimes work: with the
Tap POS screen open and on top, SWIP wins. Lock the phone, switch apps, or let
the screen dim at the wrong moment, and the routing goes back to Wallet
mid-attempt.

`F-55` and `F-56` found this and built the explanation screen. What was missing
until now is that **nothing recorded it per tap**, so a failure and a success
looked the same afterwards.

### The foolproof method, as far as one exists

1. **Make SWIP the default contactless payment app.** Settings → Connected
   devices → NFC → Contactless payments. SWIP can open that screen for you.
2. **Screen on, phone unlocked, Tap POS screen open.**
3. **Hold still, against the reader, for a full two seconds.** Failure 6 — a
   terminal that selects and then gets nothing — is very often the phone being
   lifted before the second exchange.
4. Tap again if nothing happens. Terminals vary enormously.

That is genuinely it, and step 1 is the one that matters. **There is no
configuration that makes every terminal work**, because failures 5, 6 and 7 are
decisions made inside somebody else's hardware.

---

## 3. What the black box records

Every tap now writes a small run of lines. `Settings → Diagnostics → POS tap
black box`, in a debug build only.

| Line | Means |
|---|---|
| `nfc.state` | **The one to read first.** Whether NFC is on, whether SWIP is the default payment app, whether the phone was locked, whether the screen was on |
| `hce.field` | A terminal's field reached SWIP. **Its absence is the loudest finding in the file** — it means the routing sent the terminal elsewhere |
| `hce.apdu` | One command arrived. Class, instruction and length only |
| `hce.select.ppse` | The terminal opened with `SELECT 2PAY.SYS.DDF01` and SWIP answered. Proof `F-140`'s AID registration is working |
| `hce.select.aid` | It picked a card scheme — Visa, Mastercard, RuPay |
| `hce.gpo` | It asked for processing options. `kept` is how many values survived padding |
| `hce.tags` | Which EMV tags came back, and how long each value was |
| `hce.end` | **The verdict.** `outcome` is `read` / `no_gpo` / `no_select`, and `androidReason` says whether the phone was moved away or the terminal ended it |

### The two lines that answer the question

**No `hce.field` at all** → the tap never reached SWIP. Look at `nfc.state` in
the same file: `isDefaultPayment: false` is your answer.

**`hce.end` with `outcome: no_gpo`** → SWIP was reached and the terminal walked
away. Then `androidReason` splits it in two:

* `moved away` (link loss) — the phone was lifted too early. Hold longer.
* `terminal ended it` (deselect) — the terminal chose to stop. Nothing to fix
  on our side; that is a terminal that does not want to talk to a card it
  cannot authorise.

**`outcome: read` with `kept: 0`** → the exchange was perfect and every value
was padding. EMV requires a terminal to send *something* of the right length
for every requested tag, so an unprovisioned category arrives as `0000` or
`FFFF`. SWIP drops those rather than reporting `0000` as a category with the
authority of a live capture.

---

## 4. What it deliberately does not record

**No values. Ever.**

An APDU exchange is the one place in SWIP where a **merchant identifier**
genuinely lives — EMV tag `9F16`. So the recorder writes tag *names* and value
*lengths* and never contents.

That is enforced by the shape of the code rather than by discipline:
`TapTrace.tags()` is the only route by which an exchange's contents reach the
log, and it **cannot** emit a value because it is never handed one. A rule
enforced by a function signature survives a hurried edit; a rule written in a
comment above a call site does not.

These files leave the phone by design — they are meant to be exported and sent
— which is exactly why the rule has to hold.

---

## 5. The ritual

> *"We'll have a ritual between us where I'll give you: an export of JSONL for
> the bubble chat, a black box export for the POS failures, battery usage
> export logs."*

Three recorders, one shape, all debug-only:

| | Where | What to do before exporting |
|---|---|---|
| **Bubble trace** | Settings → Scan from anywhere → Bubble trace | Clear, then reproduce the disappearance |
| **POS tap black box** | Settings → Diagnostics | Clear, then tap **two or three** machines — a failure next to a success is worth far more than a failure alone |
| **Battery black box** | Settings → Diagnostics | Clear, then leave the phone a day |

All three are `.jsonl`, all three are readable in any text editor, and none of
them contains anything about what you captured.

---

## 6. The thing this cannot fix

**A terminal that gives nothing.** Failures 5, 6 and 7 are the acquirer's and
the terminal's, and no amount of instrumentation changes them.

What the black box changes is that they stop being indistinguishable from
failures 2, 3 and 4 — which are ours, and which are fixable. That is the whole
value: **turning "it didn't work" into one of seven sentences.**

---

## 7. Where the code is

| Thing | File |
|---|---|
| The recorder core | [`Blackbox.kt`](../app/android/app/src/main/kotlin/in/swip/app/Blackbox.kt) |
| The tap recorder and the readiness snapshot | [`TapTrace.kt`](../app/android/app/src/main/kotlin/in/swip/app/TapTrace.kt) |
| The HCE exchange itself | [`SwipListenService.kt`](../app/android/app/src/main/kotlin/in/swip/app/SwipListenService.kt) |
| The export screen | [`blackbox_page.dart`](../app/lib/features/bubble/blackbox_page.dart) |
| Why a tap produced nothing at all, historically | [`34-ROUND-34-CHECKLIST.md`](34-ROUND-34-CHECKLIST.md) |
