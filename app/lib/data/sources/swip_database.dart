import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/capture_event.dart';
import '../models/mcc.dart';

/// The local store.
///
/// Everything SWIP knows lives here, on the device. There is no server in v1:
/// the parsing and the merchant graph are offline-first, so the app works on a
/// plane, and there is no personal data in transit to protect in the first
/// place. Google sign-in and Drive backup (see [SwipBackup]) are the only
/// network paths, both user-initiated and both optional.
///
/// Schema notes:
///  * `captures` is **append-only**. A correction is a new row pointing at the
///    old one via `corrects_id`, never an edit. That is ordinary practice for
///    financial records and costs nothing to adopt now.
///  * `merchant_graph` is the aggregate that answers the hard case — no QR,
///    no tap, the user simply hands over a card. Every capture feeds it.
class SwipDatabase {
  SwipDatabase._(this._db);

  final Database _db;
  static SwipDatabase? _instance;

  static const _fileName = 'swip.db';
  /// v2 adds the F-40 location columns. Never edit [_create] for a change
  /// like this — bump the version and add a numbered block to [_upgrade], or
  /// fresh installs and existing ones diverge.
  static const _version = 2;

  static Future<SwipDatabase> open() async {
    if (_instance != null) return _instance!;
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, _fileName),
      version: _version,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _instance = SwipDatabase._(db);
  }

  /// Test seam — lets the parser/graph tests run against an in-memory db.
  static Future<SwipDatabase> openInMemory() async {
    final db = await openDatabase(inMemoryDatabasePath,
        version: _version, onCreate: _create);
    return SwipDatabase._(db);
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE captures (
        id            TEXT PRIMARY KEY,
        mcc           TEXT,
        vector        TEXT NOT NULL,
        confidence    TEXT NOT NULL,
        captured_at   INTEGER NOT NULL,   -- epoch ms, UTC
        merchant_name TEXT,
        merchant_city TEXT,
        country_code  TEXT,
        merchant_key  TEXT,
        amount        REAL,
        currency      TEXT,
        card_id       TEXT,
        terminal_id   TEXT,
        acquirer      TEXT,
        raw_payload   TEXT,
        corrects_id   TEXT,
        synced_at     INTEGER,
        geohash       TEXT,               -- F-40, 6 chars, ~1.2km. Never raw
        place_label   TEXT,               -- "Bandra, IN", best-effort
        place_country TEXT                -- where YOU were, not the merchant
      )
    ''');

    // The ledger is always read newest-first and often filtered by vector.
    await db.execute(
        'CREATE INDEX idx_captures_time ON captures (captured_at DESC)');
    await db.execute(
        'CREATE INDEX idx_captures_merchant ON captures (merchant_key)');
    await db.execute('CREATE INDEX idx_captures_mcc ON captures (mcc)');

    // The merchant graph: what SWIP has learned, aggregated per merchant.
    // `agreeing` is what promotes a code from "likely" to "verified" — five
    // independent captures agreeing is the threshold (docs/06 § confidence).
    await db.execute('''
      CREATE TABLE merchant_graph (
        merchant_key  TEXT PRIMARY KEY,
        display_name  TEXT,
        city          TEXT,
        country_code  TEXT,
        best_mcc      TEXT,
        agreeing      INTEGER NOT NULL DEFAULT 0,
        disagreeing   INTEGER NOT NULL DEFAULT 0,
        last_seen_at  INTEGER NOT NULL
      )
    ''');

    // Key/value for preferences that must survive a reinstall via backup.
    await db.execute('''
      CREATE TABLE prefs (
        k TEXT PRIMARY KEY,
        v TEXT NOT NULL
      )
    ''');
  }

  /// Numbered, additive, and never destructive: an existing ledger on
  /// someone's phone is the only copy of it that exists.
  static Future<void> _upgrade(Database db, int from, int to) async {
    // v1 → v2: F-40. Nullable columns, so every row already stored stays
    // valid and simply has no location — which is the truth about it.
    if (from < 2) {
      for (final column in const [
        'geohash TEXT',
        'place_label TEXT',
        'place_country TEXT',
      ]) {
        await db.execute('ALTER TABLE captures ADD COLUMN $column');
      }
    }
  }

  // ── captures ────────────────────────────────────────────────────────

  Future<void> insertCapture(CaptureEvent e) async {
    await _db.insert('captures', _toRow(e),
        conflictAlgorithm: ConflictAlgorithm.replace);
    if (e.merchantKey != null) await _touchGraph(e);
  }

  /// Newest first. [vector] filters the ledger chips; [limit] powers the
  /// dashboard's five-row preview.
  Future<List<CaptureEvent>> captures({
    CaptureVector? vector,
    int? limit,
    int offset = 0,
  }) async {
    final rows = await _db.query(
      'captures',
      where: vector == null ? null : 'vector = ?',
      whereArgs: vector == null ? null : [vector.name],
      orderBy: 'captured_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> count() async =>
      Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM captures')) ??
      0;

  Future<List<CaptureEvent>> byMerchant(String merchantKey) async {
    final rows = await _db.query('captures',
        where: 'merchant_key = ?',
        whereArgs: [merchantKey],
        orderBy: 'captured_at DESC');
    return rows.map(_fromRow).toList();
  }

  Future<List<CaptureEvent>> byMcc(String mcc) async {
    final rows = await _db.query('captures',
        where: 'mcc = ?', whereArgs: [mcc], orderBy: 'captured_at DESC');
    return rows.map(_fromRow).toList();
  }

  Future<void> deleteCapture(String id) async =>
      _db.delete('captures', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteAll() async {
    await _db.delete('captures');
    await _db.delete('merchant_graph');
  }

  // ── merchant graph ──────────────────────────────────────────────────

  /// Fold one capture into the aggregate.
  ///
  /// This is what lets SWIP answer when there is no QR and no terminal to tap:
  /// you have been to this merchant before, or 47 other people have.
  Future<void> _touchGraph(CaptureEvent e) async {
    final key = e.merchantKey!;
    final existing = await _db.query('merchant_graph',
        where: 'merchant_key = ?', whereArgs: [key], limit: 1);

    final seen = e.capturedAt.toUtc().millisecondsSinceEpoch;

    if (existing.isEmpty) {
      await _db.insert('merchant_graph', {
        'merchant_key': key,
        'display_name': e.merchantName,
        'city': e.merchantCity,
        'country_code': e.countryCode,
        'best_mcc': e.mcc,
        'agreeing': e.hasMcc ? 1 : 0,
        'disagreeing': 0,
        'last_seen_at': seen,
      });
      return;
    }

    final row = existing.first;
    final best = row['best_mcc'] as String?;
    final agrees = e.mcc != null && e.mcc == best;

    await _db.update(
      'merchant_graph',
      {
        'display_name': e.merchantName ?? row['display_name'],
        'city': e.merchantCity ?? row['city'],
        'country_code': e.countryCode ?? row['country_code'],
        // A merchant's category genuinely can change (a café becomes a bar).
        // Take the newer code when they disagree, but keep the disagreement
        // count so the UI can show `conflict` rather than pretending.
        'best_mcc': e.mcc ?? best,
        'agreeing': (row['agreeing'] as int) + (agrees ? 1 : 0),
        'disagreeing':
            (row['disagreeing'] as int) + (e.hasMcc && !agrees && best != null ? 1 : 0),
        'last_seen_at': seen,
      },
      where: 'merchant_key = ?',
      whereArgs: [key],
    );
  }

  /// What SWIP knows about a merchant, or null.
  Future<MerchantKnowledge?> knownMerchant(String merchantKey) async {
    final rows = await _db.query('merchant_graph',
        where: 'merchant_key = ?', whereArgs: [merchantKey], limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return MerchantKnowledge(
      merchantKey: merchantKey,
      displayName: r['display_name'] as String?,
      city: r['city'] as String?,
      countryCode: r['country_code'] as String?,
      mcc: r['best_mcc'] as String?,
      agreeing: r['agreeing'] as int,
      disagreeing: r['disagreeing'] as int,
    );
  }

  // ── prefs ───────────────────────────────────────────────────────────

  Future<String?> pref(String k) async {
    final r = await _db.query('prefs', where: 'k = ?', whereArgs: [k], limit: 1);
    return r.isEmpty ? null : r.first['v'] as String;
  }

  Future<void> setPref(String k, String v) async => _db.insert(
      'prefs', {'k': k, 'v': v},
      conflictAlgorithm: ConflictAlgorithm.replace);

  // ── mapping ─────────────────────────────────────────────────────────

  static Map<String, Object?> _toRow(CaptureEvent e) => {
        'id': e.id,
        'mcc': e.mcc,
        'vector': e.vector.name,
        'confidence': e.confidence.name,
        'captured_at': e.capturedAt.toUtc().millisecondsSinceEpoch,
        'merchant_name': e.merchantName,
        'merchant_city': e.merchantCity,
        'country_code': e.countryCode,
        'merchant_key': e.merchantKey,
        'amount': e.amount,
        'currency': e.currency,
        'card_id': e.cardId,
        'terminal_id': e.terminalId,
        'acquirer': e.acquirer,
        'raw_payload': e.rawPayload,
        'corrects_id': e.correctsId,
        'synced_at': e.syncedAt?.toUtc().millisecondsSinceEpoch,
        'geohash': e.geohash,
        'place_label': e.placeLabel,
        'place_country': e.placeCountry,
      };

  static CaptureEvent _fromRow(Map<String, Object?> r) => CaptureEvent(
        id: r['id'] as String,
        mcc: r['mcc'] as String?,
        vector: CaptureVector.values.byName(r['vector'] as String),
        confidence: MccConfidence.values.byName(r['confidence'] as String),
        capturedAt: DateTime.fromMillisecondsSinceEpoch(
            r['captured_at'] as int,
            isUtc: true),
        merchantName: r['merchant_name'] as String?,
        merchantCity: r['merchant_city'] as String?,
        countryCode: r['country_code'] as String?,
        merchantKey: r['merchant_key'] as String?,
        amount: r['amount'] as double?,
        currency: r['currency'] as String?,
        cardId: r['card_id'] as String?,
        terminalId: r['terminal_id'] as String?,
        acquirer: r['acquirer'] as String?,
        rawPayload: r['raw_payload'] as String?,
        correctsId: r['corrects_id'] as String?,
        geohash: r['geohash'] as String?,
        placeLabel: r['place_label'] as String?,
        placeCountry: r['place_country'] as String?,
        syncedAt: r['synced_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['synced_at'] as int,
                isUtc: true),
      );

  /// Every capture, oldest first — the backup export path.
  Future<List<Map<String, Object?>>> exportRows() =>
      _db.query('captures', orderBy: 'captured_at ASC');

  /// Merge rows from a backup file. Existing ids win, so importing the same
  /// file twice is a no-op rather than a duplication.
  Future<int> importRows(List<Map<String, Object?>> rows) async {
    var added = 0;
    final batch = _db.batch();
    for (final r in rows) {
      final existing = await _db.query('captures',
          where: 'id = ?', whereArgs: [r['id']], limit: 1);
      if (existing.isNotEmpty) continue;
      batch.insert('captures', r,
          conflictAlgorithm: ConflictAlgorithm.ignore);
      added++;
    }
    await batch.commit(noResult: true);
    return added;
  }
}

/// What the merchant graph knows about one merchant.
class MerchantKnowledge {
  const MerchantKnowledge({
    required this.merchantKey,
    required this.agreeing,
    required this.disagreeing,
    this.displayName,
    this.city,
    this.countryCode,
    this.mcc,
  });

  final String merchantKey;
  final String? displayName;
  final String? city;
  final String? countryCode;
  final String? mcc;
  final int agreeing;
  final int disagreeing;

  /// Five independent agreeing captures promotes a graph answer to `verified`.
  /// Below that it is `likely`; any disagreement at all surfaces as `conflict`,
  /// because silently picking one would be the single most damaging thing this
  /// app could do.
  MccConfidence get confidence {
    if (disagreeing > 0) return MccConfidence.conflict;
    if (mcc == null) return MccConfidence.unknown;
    return agreeing >= 5 ? MccConfidence.verified : MccConfidence.likely;
  }
}
