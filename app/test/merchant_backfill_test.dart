import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swip/core/location/capture_location.dart';
import 'package:swip/data/models/capture_event.dart';
import 'package:swip/data/repositories/capture_repository.dart';
import 'package:swip/data/repositories/mcc_repository.dart';
import 'package:swip/data/sources/swip_database.dart';

/// `F-150` — the merchant-name discrepancy, against a real database.
///
/// ## Why this file exists at all
///
/// Until now nothing in this project could open a database in a test, because
/// `sqflite` speaks over a platform channel that `flutter test` does not
/// implement. The consequence shows up in the changelog: the two worst
/// near-misses in this codebase were both in the database layer and both were
/// caught by **reading the code**, not by running it —
///
/// * `F-136`, where `importRows` would have thrown on the first import of a
///   new-format export, because sqflite refuses an insert with a key that is
///   not a column;
/// * `F-139`, where `SVCMERC00306934` was being stored and displayed as a
///   shop's name.
///
/// Both are one careless commit away from coming back. `sqflite_common_ffi`
/// runs the real SQLite against the real schema, so from here they are
/// testable.
void main() {
  // The real SQLite, against the real schema, on the host.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late SwipDatabase db;
  late CaptureRepository repo;

  setUp(() async {
    // Location off. `LocationService` reads this on every capture and a
    // capture that tries to reach the geolocator plugin in a test hangs.
    SharedPreferences.setMockInitialValues({'location_enabled': false});
    final prefs = await SharedPreferences.getInstance();

    db = await SwipDatabase.openInMemory();
    repo = CaptureRepository(db, await MccTable.load(), LocationService(prefs));
  });

  // `F-150`. **Not optional.** sqflite caches open databases by path, and
  // every `openInMemory()` uses the same `:memory:` path — so without this the
  // second test in the file gets the first test's rows and fails on a count it
  // never created. Found exactly that way.
  tearDown(() async => db.close());

  group('`F-150` a shop stays named across captures', () {
    // The exact pair from the owner's own ledger. Wellness Forever's till
    // prints a dynamic QR carrying the name and the category; the sticker on
    // the same counter carries neither.
    const key = 'upi:WFMLMH2@ybl';

    test('the sticker inherits the name the dynamic QR taught', () async {
      final first = await repo.record(
        vector: CaptureVector.qr,
        mcc: '5912',
        merchantName: 'WELLNESS FOREVER MH 2',
        merchantCity: 'Thane',
        countryCode: 'IN',
        merchantKey: key,
        rawPayload: 'upi://pay?pa=WFMLMH2@ybl'
            '&pn=WELLNESS%20FOREVER%20MH%202&mc=5912&mode=15',
      );
      expect(first.merchantName, 'WELLNESS FOREVER MH 2');

      // …and now the static sticker: same merchant, no name, no category.
      final second = await repo.record(
        vector: CaptureVector.qr,
        mcc: null,
        merchantName: null,
        merchantKey: key,
        rawPayload: 'upi://pay?pa=WFMLMH2@ybl',
      );

      // Before `F-150` this row showed the bare handle, and the ledger listed
      // one shop under two different-looking identities.
      expect(second.merchantName, 'WELLNESS FOREVER MH 2');
      expect(second.merchantCity, 'Thane');
      expect(second.countryCode, 'IN');
      // The category was already inherited before this change; it still is.
      expect(second.mcc, '5912');
    });

    test('the payload\'s own name always wins over the remembered one',
        () async {
      await repo.record(
        vector: CaptureVector.qr,
        mcc: '5912',
        merchantName: 'WELLNESS FOREVER MH 2',
        merchantKey: key,
      );

      // The shop renamed itself, and the new QR says so. Memory must not
      // overwrite evidence.
      final renamed = await repo.record(
        vector: CaptureVector.qr,
        mcc: '5912',
        merchantName: 'WELLNESS FOREVER MH 12',
        merchantKey: key,
      );
      expect(renamed.merchantName, 'WELLNESS FOREVER MH 12');
    });

    test('a merchant never seen before gets no name invented for it', () async {
      final fresh = await repo.record(
        vector: CaptureVector.qr,
        mcc: null,
        merchantName: null,
        merchantKey: 'upi:paytmqr70ivq3@ptys',
      );
      // The whole point of `F-150` is that it is memory, not inference. A key
      // with no history produces no name.
      expect(fresh.merchantName, isNull);
    });

    test('two different shops do not share a name', () async {
      await repo.record(
        vector: CaptureVector.qr,
        mcc: '5912',
        merchantName: 'WELLNESS FOREVER MH 2',
        merchantKey: key,
      );
      final other = await repo.record(
        vector: CaptureVector.qr,
        mcc: null,
        merchantName: null,
        merchantKey: 'upi:someoneelse@ybl',
      );
      expect(other.merchantName, isNull);
    });
  });

  group('`F-136` import survives a new-format export', () {
    test('a row carrying fields that are not columns still imports', () async {
      // This is the exact shape that would have thrown before `F-136`: the
      // `provenance` block added by `export_narrative.dart` is not a column,
      // and sqflite refuses an insert with an unknown key.
      final added = await db.importRows([
        {
          'id': 'imported-1',
          'mcc': '5411',
          'vector': 'qr',
          'confidence': 'verified',
          'captured_at': DateTime.utc(2026, 9, 5).millisecondsSinceEpoch,
          'merchant_name': 'A SHOP',
          'merchant_key': 'upi:shop@ybl',
          // Not columns. Every one of these has to be dropped silently.
          'provenance': {'what': 'a category', 'how': 'a QR'},
          'somethingFromTheFuture': 42,
          'sealPrev': 'abc123',
        },
      ]);

      expect(added, 1);
      final rows = await db.exportRows();
      expect(rows.single['merchant_name'], 'A SHOP');
      expect(rows.single['mcc'], '5411');
    });

    test('importing the same file twice adds nothing the second time',
        () async {
      final row = {
        'id': 'imported-2',
        'mcc': '5912',
        'vector': 'qr',
        'confidence': 'verified',
        'captured_at': DateTime.utc(2026, 9, 5).millisecondsSinceEpoch,
        'merchant_key': 'upi:x@ybl',
      };
      expect(await db.importRows([row]), 1);
      // "Merges by capture id, so importing twice is safe" is a promise made
      // on the Settings screen.
      expect(await db.importRows([row]), 0);
      expect((await db.exportRows()).length, 1);
    });

    test('a row with no id at all does not take the import down', () async {
      // A hand-edited backup, or one truncated mid-row. The import should
      // skip what it cannot use and keep what it can.
      //
      // NOTE on how this is written: `expect(() => db.importRows(...),
      // returnsNormally)` looks right and is useless. `importRows` is async,
      // so `returnsNormally` only checks that calling it did not throw
      // *synchronously* — it returns a Future nobody awaits, tearDown closes
      // the database underneath it, and the failure arrives as
      // `DatabaseException(database_closed)` from a test that had already
      // passed. Await it and assert on the result.
      final added = await db.importRows([
        {'mcc': '5912'}, // no id — unaddressable, must be skipped
        {
          'id': 'good',
          'mcc': '5411',
          'vector': 'qr',
          'confidence': 'verified',
          'captured_at': DateTime.utc(2026, 9, 5).millisecondsSinceEpoch,
        },
      ]);

      expect(added, 1, reason: 'the good row goes in, the headless one does not');
      final rows = await db.exportRows();
      expect(rows.single['id'], 'good');
    });
  });
}
