# SWIP — project memory

Read this first, every session. It is the short version of everything that has
already been decided, gone wrong, or been ruled out, so none of it has to be
rediscovered.

---

## What SWIP is

An Android-first Flutter app that shows a shop's **merchant category code (MCC)
before you pay**, so you know which card to use. Owner: Aditya Maurya, a product
designer who does not write code — so **explain the reasoning, not just the
result**, and never leave a claim without a link to where it is written down.

There is **no server, no account, no analytics**. The ledger is local SQLite.
That is the product's main security property and its main marketing claim; do
not add a network dependency without saying so out loud.

---

## Standing rules — these do not expire

| Rule | Detail |
|---|---|
| Branch | `claude/swip-mcc-tracking-app-unc1nl`. **Never push elsewhere without explicit permission** |
| Pull requests | **Only when explicitly asked** |
| Push | `git push -u origin <branch>`; retry 4× on network failure with 2/4/8/16 s backoff |
| CI | **Read the logs yourself after every push, including the APK job.** Two builds were once reported green while the APK job had failed |
| Links | Every claim gets a link to the file, commit or source it came from. Never leave the owner "blind with words" |
| Ledgers | A changelog entry per prompt, a prompt ledger with every prompt **verbatim and timestamped**, and a conversation log of the answers. **Never delete a row from any of them** |
| Before every build | Run [`docs/30-PRE-LAUNCH-PARAMETERS.md`](docs/30-PRE-LAUNCH-PARAMETERS.md) §1 |

### Pre-push checks that exist because something got through

```bash
cd app
python3 tool/check_balance.py   # unbalanced brackets — a stray `Text(` once broke the parse
python3 tool/check_const.py     # `const X(… .withValues(…))` is not constant
```

---

## Declined, and staying declined

* **The cashback-arbitrage donation mechanism** — a donor swipes ₹40,000, gets
  ~₹38,000 back, keeps the card cashback. The cashback is paid by an issuer who
  believes it funded a retail purchase. Recorded once in
  [`docs/27-DONATIONS.md`](docs/27-DONATIONS.md) §3 with what replaces it. The
  owner has reaffirmed the request; everything else in that feature is built.
* **A plan to avoid GST.** The accurate position was given instead: a genuine
  donation with no quid pro quo is not a supply at all under CBIC Circular
  116/35/2019.
* **Scraping the LinkedIn profile photo** — it is behind an auth wall. The
  colophon falls back to a monogram; dropping `brand/avatar.jpg` in fixes it.

---

## Hard-won technical facts

Each of these cost a broken build or a broken screen. Do not re-derive them.

| Fact | Consequence |
|---|---|
| `mobile_scanner`'s `DetectionSpeed.noDuplicates` is a **single-slot** memory cleared only by `stop()`/`dispose()` | Never use it. The same code twice emits nothing — this is why a force-quit "fixed" scanning |
| `material.dart` exports `ValueNotifier` but **not** `ValueListenable` | Import `foundation.dart` explicitly |
| `ScrollNotification.context` is **non-nullable** | Notification tests need a real element tree, so `testWidgets` not `test` |
| `NotificationListener` hears **descendants only** | A pull-to-reveal inside a scroll view can never fire |
| `CrossAxisAlignment.stretch` in a sliver → tight infinite constraint → kills the whole `CustomScrollView` | This is what turned the dashboard black |
| Riverpod's `when` shows `loading` on a **reload** by default | `skipLoadingOnReload: true`, or the camera is torn down after every capture |
| `.withValues()` is a method call | It cannot appear inside a `const` block |
| `app/assets/brand/` is **gitignored**; `bootstrap.sh` copies top-level `brand/` | New brand assets go in `/brand/` |
| Camera overlays must use `onCamera*` colours, never `bg`/`textPrimary`/`gold500` | The feed is an arbitrary image; the app ground is white |

**The recurring mistake, twice over: checking the source instead of the
artifact.** Read the built thing, not the code that should have built it.

---

## Domain facts that drive the product

* **P2M** merchants have an MCC and can take a RuPay credit card on UPI.
  **P2PM** (small-merchant) have **neither** — NPCI does not permit credit card
  on UPI there. "This shop has no category" and "my RuPay card is greyed out"
  are one fact seen twice.
* A **static Paytm sticker carries no MCC at all** — often just
  `pa` and `pn`. No app can read one out of it, CRED included.
* **`mc=` present-and-empty** is a bank that built a merchant QR and left the
  category blank. Different from absent, and worth saying.
* **Netbanking has no MCC.** Not a card transaction, so there is nothing to read.
* The MCC **is** in the 3-D Secure `AReq` during a card payment, but that is
  server-to-server and never reaches the phone.
* CRED writes **"MERCHANT MAY NOT ACCEPT RUPAY CC"** — the word *may* is the
  tell that they are inferring too. Match that hedge; never claim more.

---

## Where things are written down

| Topic | File |
|---|---|
| Every prompt, verbatim, timestamped | [`docs/21-PROMPT-LEDGER.md`](docs/21-PROMPT-LEDGER.md) |
| What was built each round | [`docs/CHANGELOG.md`](docs/CHANGELOG.md) |
| What was *answered* each round | [`docs/28-CONVERSATION-LOG.md`](docs/28-CONVERSATION-LOG.md) |
| Why the QRs would not scan | [`docs/29-QR-DETECTION-FORENSICS.md`](docs/29-QR-DETECTION-FORENSICS.md) |
| The build gate | [`docs/30-PRE-LAUNCH-PARAMETERS.md`](docs/30-PRE-LAUNCH-PARAMETERS.md) |
| iOS and `.ipa` | [`docs/31-IOS-AND-IPA.md`](docs/31-IOS-AND-IPA.md) |
| The floating bubble | [`docs/32-FLOATING-BUBBLE.md`](docs/32-FLOATING-BUBBLE.md) |
| Visual direction | [`docs/33-VISUAL-DIRECTION-PAPER.md`](docs/33-VISUAL-DIRECTION-PAPER.md) |
| Account recovery | [`docs/25-CONTINUITY.md`](docs/25-CONTINUITY.md) |

---

## Style

Long doc comments that explain **why**, especially where the reason is
non-obvious or where a previous attempt failed. The owner reads the code as
documentation. A comment that only restates the line beneath it is noise; a
comment that records why the obvious approach does not work is the most valuable
thing in the file.
