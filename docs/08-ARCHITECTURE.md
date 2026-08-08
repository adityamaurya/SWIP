# SWIP — Architecture

> Answers ideation `B-01` … `B-04`. Written for someone who has not shipped a mobile app
> before, so it explains *why* as much as *what*.

---

## Why Flutter

You want one product on Android and iOS (`B-01`), a highly custom brand surface, and you
are one designer (`B-05`).

| Option | Verdict |
|---|---|
| **Flutter** | ✅ **Chosen.** One codebase, one design system, pixel-identical on both platforms — which matters enormously when the designer *is* the developer. Platform channels reach the Android NFC APIs cleanly |
| React Native | Viable, but the custom-rendering story is weaker and you'd fight native styling on two platforms |
| Native ×2 | Correct at 20 engineers. Suicide at one |
| KMP + Compose/SwiftUI | Best long-term ceiling, worst learning curve for a first mobile project |

**The one thing Flutter costs you** is that Vector 2 must be written twice conceptually —
Kotlin does the EMV work, Dart does the UI. That is unavoidable: HCE has no cross-platform
abstraction, and it would not help if it did, because iOS cannot do it at all
([03-RESEARCH §3.5](03-RESEARCH-MCC-CAPTURE.md#35-ios-reality)).

---

## Layers

```
┌──────────────────────────────────────────────────────────┐
│  features/          screens, one folder per S-nn         │
│                     no business logic, no SQL, no parsing│
├──────────────────────────────────────────────────────────┤
│  widgets/           shared components (MccBadge, …)      │
├──────────────────────────────────────────────────────────┤
│  data/repositories  the only layer features may call     │
├──────────────────────────────────────────────────────────┤
│  data/sources       parsers, sqflite DAOs, channels      │
│  data/models        immutable value types                │
├──────────────────────────────────────────────────────────┤
│  core/              tokens, theme, router, utils         │
└──────────────────────────────────────────────────────────┘
                    ▲
        platform ───┘  Kotlin: SwipListenService (HCE)
```

**Three rules that keep this honest:**

1. **A `features/` file never imports `sqflite`, never parses a payload, never touches a
   platform channel.** If a screen needs data, it asks a repository.
2. **Models are immutable.** `CaptureEvent` has no setters. A correction is a *new* row
   pointing at the old one via `correctsId`, never an edit. This is ordinary practice for
   financial records, it costs nothing now, and retrofitting it later is painful.
3. **`core/theme` is the only place a colour, size or duration literal may appear.**

---

## Why hand-written sqflite rather than drift

Drift is the better answer at ten tables. At four, it costs a `build_runner` step that a
first-time Flutter developer will hit on day one, before anything works, with an error
message that means nothing to them.

**v1 uses `sqflite` with hand-written DAOs and explicit SQL.** No codegen, `flutter run`
works immediately, and the SQL is visible and reviewable — which matters for a ledger.

> **Migrate to drift when** the schema passes ~8 tables or the first multi-table join
> appears. That is a real threshold, not a someday: write it in the backlog now.

Migrations are numbered and forward-only, in `data/sources/local_db.dart`. **Never mutate a
shipped migration** — add a new one. A user upgrading from v1.0 to v1.4 runs 1→2→3→4 in
order, and rewriting step 2 corrupts exactly the users who skipped a release.

---

## The capture pipeline

Every vector converges on one write path, which is what makes ideation `D-02` true rather
than aspirational — the ledger cannot disagree with itself about what happened.

```
  Vector 1  QR       ─┐
  Vector 2  NFC/HCE  ─┤
  Vector 3  Link     ─┼─►  CaptureResolver  ─►  CaptureRepository.record()
  Vector 5  Manual   ─┤         │                        │
  Vector 6  Graph    ─┘         │                        ├─► ledger (sqflite)
                                │                        └─► merchant graph
                                ▼
                     resolve MCC ─ assign confidence ─ build merchantKey
```

`CaptureResolver` is where confidence is decided, and it is the most safety-critical class
in the app:

| Source | Confidence |
|---|---|
| QR tag 52 / UPI `mc`, CRC valid | `verified` |
| NFC `9F15` non-zero | `verified` |
| Graph, ≥ 5 agreeing captures | `verified` |
| Graph, 1–4 captures | `likely` |
| Link inference | `likely`, never higher |
| Sources disagree | `conflict` — show all, pick none |
| Nothing | `unknown` — say so |

---

## The NFC bridge

```
 SwipListenService (Kotlin)          MainActivity              Dart
  ├ SELECT PPSE  → AID list
  ├ SELECT AID   → FCI with PDOL(9F15,…)
  ├ GPO          → slice values ──► broadcast ──► EventChannel ──► TapPage
  └ return 6985  (decline, always)                MethodChannel ──► start/stop
```

Two details that are easy to get wrong and expensive to debug:

- **Foreground preference.** SWIP registers real payment AIDs, so on a device with Google
  Wallet as default the APDUs go to Wallet. `CardEmulation.setPreferredService()` routes to
  SWIP **only while the Tap screen is resumed**, and it is released on pause. Correct, and
  honest — SWIP never competes for the NFC field in the background.
- **Zeros are not data.** EMV obliges a terminal to return *something* of the right length
  for every PDOL tag. An unprovisioned `9F15` arrives as `0000`. The service drops all-zero
  and all-`FF` slices, because recording `0000` with the authority of a live capture is
  worse than recording nothing.

---

## Privacy architecture

Not a policy document — these are structural properties:

- **No account, no login, no server, in v1.** The app is fully functional offline.
- **The merchant graph is merchant-keyed, never user-keyed.** A contribution carries
  `(merchantKey, mcc, vector, coarse geohash, timestamp)`. No user id, no device id, no
  amount.
- **Geohash is 5 characters (~4.9 km).** Precise location is never collected, so it can
  never leak.
- **Every privacy toggle defaults off** and the app works with all of them off.
- **No PAN, no CVV, no expiry.** Cards are a nickname, issuer, network and optional last-4.
  There is no reason to hold more and every reason not to.
- **No SMS permission, ever** ([03-RESEARCH §8](03-RESEARCH-MCC-CAPTURE.md#8-vector-5--statements-sms-and-email-and-why-swip-does-not-lead-with-it)).

---

## Testing

| Layer | What | Priority |
|---|---|---|
| **Parsers** | EMVCo TLV, CRC, UPI URI — including non-ASCII and adversarial payloads | **P0. Already written** |
| Resolver | Confidence assignment for every source combination | P0 |
| DAO | Migrations, forward from every shipped version | P0 |
| Widget | `LedgerRow` at 100 % / 130 % / 200 % text scale | P1 |
| Golden | `MccBadge`, `PublicationChips`, `LedgerRow` | P1 |
| Integration | Scan → ledger → detail | P1 |
| Manual | The 50-terminal NFC field test | **P0, week 1** |

`app/test/emv_qr_parser_test.dart` ships with 17 cases including CRC check-vector
verification, corrupt payloads, duplicate-tag shadowing, length overruns, and Japanese
merchant names. **The parser is where a bug silently produces a wrong number**, which is
the one failure mode this product cannot have.
