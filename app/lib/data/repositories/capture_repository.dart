import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/capture_event.dart';
import '../models/mcc.dart';
import '../sources/swip_database.dart';
import 'mcc_repository.dart';

/// The one write path into the ledger.
///
/// Ideation `D-02`: *"whenever a swipe, scan, or link URL happens, it gets
/// added to the ledger."* Every vector — QR, NFC, link, probe, manual, graph —
/// funnels through [record] so the ledger can never disagree with itself about
/// what happened, and so the merchant graph is fed exactly once per capture.
class CaptureRepository {
  CaptureRepository(this._db, this._mcc);

  final SwipDatabase _db;
  final MccTable _mcc;

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
    );

    await _db.insertCapture(event);
    return event;
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
  return CaptureRepository(db, mcc);
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

final captureCountProvider = FutureProvider<int>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final repo = await ref.watch(captureRepositoryProvider.future);
  return repo.count();
});
