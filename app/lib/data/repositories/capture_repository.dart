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
    // Fetched before the row is built, and never allowed to fail the capture:
    // `current()` returns null for a refused permission, a disabled service, or
    // a timeout indoors, and all three mean "no location", not "no capture".
    final where = await _location.current();

    var code = mcc;
    var confidence = vector.isLiveCapture
        ? MccConfidence.verified
        : MccConfidence.likely;
    var effectiveVector = vector;

    final noCode = code == null || code.length != 4 || code == '0000';
    if (noCode && merchantKey != null) {
      final known = await _db.knownMerchant(merchantKey);
      if (known?.mcc != null) {
        code = known!.mcc;
        confidence = known.confidence;
        effectiveVector = CaptureVector.graph;
      } else {
        confidence = MccConfidence.unknown;
      }
    } else if (noCode) {
      confidence = MccConfidence.unknown;
    }

    final event = CaptureEvent(
      id: _newId(),
      mcc: code,
      vector: effectiveVector,
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
      geohash: where?.geohash,
      placeLabel: where?.label,
      placeCountry: where?.countryCode,
    );

    await _db.insertCapture(event);
    return event;
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

  /// A correction from the user (`S-13`), stored as a new row that supersedes
  /// the old one rather than an edit — the ledger is append-only.
  Future<CaptureEvent> correct(CaptureEvent original, String mcc) async {
    final corrected = CaptureEvent(
      id: _newId(),
      mcc: mcc,
      vector: CaptureVector.manual,
      confidence: MccConfidence.verified,
      capturedAt: DateTime.now().toUtc(),
      merchantName: original.merchantName,
      merchantCity: original.merchantCity,
      countryCode: original.countryCode,
      merchantKey: original.merchantKey,
      amount: original.amount,
      currency: original.currency,
      rawPayload: original.rawPayload,
      correctsId: original.id,
    );
    await _db.insertCapture(corrected);
    return corrected;
  }

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
