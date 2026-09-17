import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/capture_location.dart';
import '../models/capture_event.dart';
import '../models/mcc.dart';
import '../sources/merchant_reconciler.dart';
import '../sources/statement_parser.dart';
import '../sources/swip_database.dart';
import 'mcc_repository.dart';

/// The one write path into the ledger.
///
/// Ideation `D-02`: *"whenever a swipe, scan, or link URL happens, it gets
/// added to the ledger."* Every vector — QR, NFC, link, probe, manual, graph —
/// funnels through [record] so the ledger can never disagree with itself about
/// what happened, and so the merchant graph is fed exactly once per capture.
class CaptureRepository {
  CaptureRepository(this._db, this._mcc, this._location);

  final SwipDatabase _db;
  final MccTable _mcc;

  /// `F-40`. Held here rather than called from each capture screen so that
  /// "captured with every capture" is structurally true — a new vector added
  /// later gets location without anyone remembering to wire it.
  final LocationService _location;

  static final _rand = Random.secure();

  /// Record a capture and return the stored row.
  ///
  /// When the payload carried no category but SWIP has seen this merchant
  /// before, the graph answers instead — that is the whole point of keeping
  /// one, and it is what covers the hard case where there is no QR at all.
  Future<CaptureEvent> record({
    required CaptureVector vector,
    String? mcc,
    String? merchantName,
    String? merchantCity,
    String? countryCode,
    String? merchantKey,
    double? amount,
    String? currency,
    String? terminalId,
    String? acquirer,
    String? rawPayload,
  }) async {
    // `F-192`. **The location is NOT fetched here any more.**
    //
    // It used to be the first line of this method, and it is the reason the
    // owner reported *"it goes to a blank screen… it is still processing…
    // takes a lot of time"* and, worse, *"if the user is in a hurry and he
    // leaves the window, there would be no record in the ledger"*.
    //
    // Both were one mechanism. `current()` awaits a GPS fix with a **10 second**
    // limit — which indoors, at a counter, is the normal case rather than the
    // bad one — and then a reverse geocode, which is a **network call** to
    // Android's `Geocoder` with no timeout at all. Nothing was written to the
    // ledger until all of that returned, so a capture's survival depended on
    // the user standing still in a shop watching a viewfinder.
    //
    // The row is written first now and the place arrives afterwards, through
    // [_fillLocationLater]. That inverts the priority to match the product:
    // **the capture is the thing, and where you were standing is a label on
    // it.** A capture that is lost because a geocoder was slow is a capture
    // the user has to go back to the counter for.

    var code = mcc;
    final noCode = code == null || code.length != 4 || code == '0000';

    // `F-87`. **The vector is how the capture happened, and nothing changes
    // it.**
    //
    // This used to rewrite the vector to `graph` whenever the code came from
    // memory rather than from the payload — so a QR you scanned at a counter
    // was filed in the ledger as "KNOWN", and the row no longer said how you
    // had actually captured it. Two different facts had been folded into one
    // field: *how it was captured* and *where the digits came from*. The first
    // is the vector and is now immutable; the second is what [confidence]
    // carries.
    //
    // `F-88`. There is also no `likely` any more. It was assigned to every
    // non-live vector by default and appeared under the MCC as a hedge nobody
    // asked for. A category is either read from the transaction — the QR, the
    // terminal, the merchant's own intent, or the bank's own statement — in
    // which case it is **verified**, or it is not known, in which case saying
    // "likely" is dressing up a guess.
    var confidence =
        vector.isLiveCapture && !noCode ? MccConfidence.verified : MccConfidence.unknown;

    // ── `F-150`. **The same shop, named on one capture and a bare handle on
    // the next.**
    //
    // > *"I have noticed some discrepancies while capturing the merchant
    // > name."*
    //
    // Here is the discrepancy, and it is entirely SWIP's doing. Scan Wellness
    // Forever's dynamic QR at the till and the payload carries
    // `pn=WELLNESS FOREVER MH 2`, so the capture is named. Scan the static
    // sticker taped to the same counter a minute later and there is no `pn` at
    // all — so the row showed `WFMLMH2@ybl`, and the ledger listed one shop
    // under two different-looking identities.
    //
    // The merchant graph already knew the name. It had been written on the
    // first capture and was sitting in `display_name`, and the only reason it
    // was not used is that this block looked up the category and stopped.
    // Backfilling the code but not the name is an odd place to draw a line:
    // both come from the same row, keyed on the same merchant, learned the
    // same way.
    //
    // **This is not inference and it is deliberately not CRED's method.**
    // `docs/34` §5 sets out what they can do that SWIP cannot — they hold a
    // licensed PSP's merchant directory and can look a VPA up in it. SWIP has
    // no directory and is not guessing at one: a name appears here only
    // because *this phone* has already read it off a payload at *this
    // merchant key*. The worst case is a shop that renamed itself showing its
    // old name until it is next captured with a new one, which the next
    // dynamic QR corrects.
    if (merchantKey != null && (noCode || merchantName == null)) {
      final known = await _db.knownMerchant(merchantKey);

      if (noCode && known?.mcc != null) {
        code = known!.mcc;
        // Inherited honestly: a code learned from a bank statement is stored
        // verified, because the acquirer posted it after the money moved.
        confidence = known.confidence;
      }

      // The payload's own name always wins. This only ever fills a blank.
      merchantName ??= known?.displayName;
      merchantCity ??= known?.city;
      countryCode ??= known?.countryCode;
    }

    final event = CaptureEvent(
      id: _newId(),
      mcc: code,
      vector: vector,
      confidence: confidence,
      capturedAt: DateTime.now().toUtc(),
      merchantName: merchantName,
      merchantCity: merchantCity,
      countryCode: countryCode,
      merchantKey: merchantKey,
      amount: amount,
      currency: currency,
      terminalId: terminalId,
      acquirer: acquirer,
      rawPayload: rawPayload,
      // `F-192`. Blank on the way in, filled by [_fillLocationLater] if a fix
      // ever arrives. Null here is not "no location" — it is "not yet".
      geohash: null,
      placeLabel: null,
      placeCountry: null,
    );

    await _db.insertCapture(event);

    // Deliberately **not** awaited: this is the whole fix. The caller gets its
    // event on the next microtask and opens a sheet; the fix lands in the row
    // whenever the platform gets round to it, and the ledger shows it on its
    // next read. `unawaited` rather than a bare call so the intent is legible
    // and `unawaited_futures` stays satisfied.
    unawaited(_fillLocationLater(event.id));

    return event;
  }

  /// `F-192` — put the place on a capture that is already saved.
  ///
  /// Runs after [record] has returned, so nothing on screen is waiting for it.
  /// Every failure mode ends the same way: the row keeps its blank columns,
  /// which is exactly what it had a moment ago.
  ///
  /// There is no retry. A fix that did not arrive inside `current()`'s own
  /// deadline is a fix the phone could not get from where it was standing, and
  /// asking again from the same place costs battery to learn the same thing.
  Future<void> _fillLocationLater(String id) async {
    try {
      final where = await _location.current();
      if (where == null) return;
      await _db.fillCaptureLocation(
        id,
        geohash: where.geohash,
        placeLabel: where.label,
        placeCountry: where.countryCode,
      );
    } catch (_) {
      // A capture must never be harmed by where it happened — the rule this
      // method exists to enforce, now that it runs where it cannot harm one.
    }
  }

  /// `F-50` — teach SWIP from a bank statement.
  ///
  /// This is the highest-value path in the app, and it exists because of one
  /// line on a Federal Bank statement:
  ///
  ///     UPIOUT/658724829452/paytm.s233ffl@pty/Demo/5451
  ///
  /// The category and the payee handle sit **in the same line**, and the handle
  /// is in exactly the form a QR scan produces. So a statement does not teach
  /// SWIP about a *payment* — it teaches SWIP about a **merchant**, permanently
  /// and without asking the user which shop it was.
  ///
  /// Everything already captured for that merchant is back-filled, so the five
  /// "Unknown category" rows from a shop you scanned last week acquire their
  /// real code the moment the statement lands.
  ///
  /// Returns (merchants learned, past captures back-filled).
  Future<({int learned, int backfilled})> learnFromStatement(
      String text) async {
    final entries = StatementParser.parseAll(
      text,
      isKnownMcc: (code) => _mcc.lookup(code) != null,
    );

    var backfilled = 0;

    for (final entry in entries) {
      final key = entry.merchantKey!;

      // A statement row of its own, so the ledger shows where the knowledge
      // came from and the graph counts it as an agreeing capture.
      final event = CaptureEvent(
        id: _newId(),
        mcc: entry.mcc,
        vector: CaptureVector.statement,
        // The acquirer posted this after the money moved. Nothing SWIP can
        // read is more authoritative.
        confidence: MccConfidence.verified,
        capturedAt: DateTime.now().toUtc(),
        merchantKey: key,
        merchantName: entry.note,
        countryCode: 'IN',
        rawPayload: entry.raw,
      );
      await _db.insertCapture(event);

      backfilled += await _db.backfillMcc(key, entry.mcc!);
    }

    return (learned: entries.length, backfilled: backfilled);
  }

  /// `F-49`. Links a shop's two identities and hands the category across.
  ///
  /// Returns how many past captures gained a category as a result.
  Future<int> confirmLink(MerchantLinkProposal p) async {
    await _db.linkMerchants(p.aliasKey, p.canonicalKey);
    return _db.backfillMcc(p.aliasKey, p.mcc!);
  }

  /// Candidate links among recent captures. Empty is the normal case — this
  /// only fires when a tap and a scan land in the same place, in one visit,
  /// and exactly one of them knows the category.
  Future<List<MerchantLinkProposal>> proposedLinks() async {
    final recent = await _db.captures(limit: 60);
    final linked = <String>{};
    for (final e in recent) {
      final key = e.merchantKey;
      if (key == null) continue;
      if (await _db.resolveMerchantKey(key) != key) linked.add(key);
    }
    return MerchantReconciler.propose(recent, alreadyLinked: linked);
  }

  Future<List<CaptureEvent>> recent({int limit = 5}) =>
      _db.captures(limit: limit);

  Future<List<CaptureEvent>> all({CaptureVector? vector}) =>
      _db.captures(vector: vector);

  Future<int> count() => _db.count();

  Future<void> delete(String id) => _db.deleteCapture(id);

  Future<void> clear() => _db.deleteAll();

  Mcc? lookup(String? code) => code == null ? null : _mcc.lookup(code);

  // `F-89`. The manual `correct()` path was removed with the manual vector.
  // Nothing in the app called it, and a hand-typed number is exactly the kind
  // of "category" SWIP exists to make unnecessary. If a correction path returns
  // it should be evidence-based — a statement line — not a text field.

  static String _newId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt =
        List.generate(6, (_) => chars[_rand.nextInt(chars.length)]).join();
    return '$now-$salt';
  }
}

// ── providers ─────────────────────────────────────────────────────────

final databaseProvider = FutureProvider<SwipDatabase>((ref) async {
  return SwipDatabase.open();
});

final mccTableProvider = FutureProvider<MccTable>((ref) async {
  return MccTable.load();
});

final captureRepositoryProvider = FutureProvider<CaptureRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final mcc = await ref.watch(mccTableProvider.future);
  final location = await ref.watch(locationServiceProvider.future);
  return CaptureRepository(db, mcc, location);
});

/// Bumped after every write so the dashboard and ledger refetch.
final ledgerRevisionProvider = StateProvider<int>((ref) => 0);

final recentCapturesProvider = FutureProvider<List<CaptureEvent>>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final repo = await ref.watch(captureRepositoryProvider.future);
  return repo.recent(limit: 5);
});

final allCapturesProvider =
    FutureProvider.family<List<CaptureEvent>, CaptureVector?>((ref, v) async {
  ref.watch(ledgerRevisionProvider);
  final repo = await ref.watch(captureRepositoryProvider.future);
  return repo.all(vector: v);
});

/// `F-49`. Surfaced on the dashboard when SWIP thinks two captures are one
/// shop. Deliberately re-read on every ledger change, so confirming one makes
/// it disappear immediately.
final merchantLinkProposalsProvider =
    FutureProvider<List<MerchantLinkProposal>>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final repo = await ref.watch(captureRepositoryProvider.future);
  return repo.proposedLinks();
});

final captureCountProvider = FutureProvider<int>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final repo = await ref.watch(captureRepositoryProvider.future);
  return repo.count();
});
