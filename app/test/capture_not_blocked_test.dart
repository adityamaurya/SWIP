import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swip/core/location/capture_location.dart';
import 'package:swip/data/models/capture_event.dart';
import 'package:swip/data/repositories/capture_repository.dart';
import 'package:swip/data/repositories/mcc_repository.dart';
import 'package:swip/data/sources/swip_database.dart';

/// `F-192` — **a capture must not wait for a GPS fix, and must survive the
/// user walking away.**
///
/// > *"I scan the QR code, and what happens is it goes to a blank screen…
/// > it is still processing this QR code, but it takes a lot of time…
/// > Otherwise, if the user is in a hurry and he leaves the window, there
/// > would be no record in the ledger"* — prompt 51
///
/// Two complaints, one mechanism. `record()` opened with
/// `await _location.current()`, which waits on `getCurrentPosition` for up to
/// ten seconds and then on `placemarkFromCoordinates` — a **network** call
/// into Android's `Geocoder` with no timeout at all. Nothing reached the
/// ledger until both returned, so a capture's survival depended on the user
/// standing still in a shop watching a viewfinder.
///
/// ## Why this test is about *time*, which tests are usually bad at
///
/// The defect is not a wrong value anywhere — every field was correct, and a
/// test asserting on the row would have passed throughout. What was wrong was
/// **when**. So the fake below never resolves at all: if `record()` still
/// awaited it, these tests would not fail on an assertion, they would hang and
/// die on the suite timeout.
///
/// That is the strongest available statement of the fix. A capture that
/// completes against a location service which *never answers* cannot be
/// waiting on one.
class _NeverAnswers extends LocationService {
  _NeverAnswers(SharedPreferences prefs) : super(prefs);

  /// Completed by `tearDown`, so the pending future is not left dangling past
  /// the test — "a Timer is still pending" is the same class of noise
  /// `CLAUDE.md` records from the bubble settings suite.
  final stuck = Completer<CaptureLocation?>();

  var asked = 0;

  @override
  bool get isEnabled => true;

  @override
  Future<CaptureLocation?> current() {
    asked++;
    return stuck.future;
  }
}

/// A fix that arrives, but only after the capture is long since saved.
class _AnswersLate extends LocationService {
  _AnswersLate(SharedPreferences prefs) : super(prefs);

  final arrived = Completer<void>();

  @override
  bool get isEnabled => true;

  @override
  Future<CaptureLocation?> current() async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!arrived.isCompleted) arrived.complete();
    return const CaptureLocation(
      geohash: 'te7ud2',
      label: 'Kasarvadavali, Thane',
      countryCode: 'IN',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late SwipDatabase db;
  late MccTable mcc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'location_enabled': true});
    db = await SwipDatabase.openInMemory();
    mcc = await MccTable.load();
  });

  // `F-150`. Not optional — sqflite caches open databases by path and every
  // `openInMemory()` uses `:memory:`, so without this the second test in the
  // file inherits the first one's rows.
  tearDown(() async => db.close());

  Future<CaptureEvent> scan(CaptureRepository repo) => repo.record(
        vector: CaptureVector.qr,
        mcc: '5411',
        merchantKey: 'paytm.s27l8o9@pty',
        rawPayload: 'upi://pay?pa=paytm.s27l8o9@pty&pn=Paytm',
      );

  test('a capture completes against a location that never answers', () async {
    final prefs = await SharedPreferences.getInstance();
    final location = _NeverAnswers(prefs);
    addTearDown(() => location.stuck.complete(null));

    final repo = CaptureRepository(db, mcc, location);

    // If `record()` still awaited the fix this would never return and the test
    // would die on a timeout rather than on the expectation below — which is
    // the point. There is no assertion that can be written about a hang.
    final event = await scan(repo);

    expect(event.mcc, '5411');
    // Asked for, and not waited on. Both halves matter: a version that simply
    // stopped collecting location would also pass the line above.
    expect(location.asked, 1,
        reason: 'the fix should still be requested, just not awaited');
  });

  test('and the row is in the ledger before the fix arrives', () async {
    // The owner's second complaint, which is the one that costs a trip back to
    // the counter: *"if the user is in a hurry and he leaves the window, there
    // would be no record in the ledger"*.
    final prefs = await SharedPreferences.getInstance();
    final location = _NeverAnswers(prefs);
    addTearDown(() => location.stuck.complete(null));

    final repo = CaptureRepository(db, mcc, location);
    final event = await scan(repo);

    final rows = await db.captures(limit: 10);
    expect(rows.map((r) => r.id), contains(event.id));
    // Blank, not absent. The row exists and says nothing about where it
    // happened, which is the correct state a moment after a capture.
    expect(rows.first.geohash, isNull);
    expect(rows.first.placeLabel, isNull);
  });

  test('a fix that arrives late is written onto the saved row', () async {
    final prefs = await SharedPreferences.getInstance();
    final location = _AnswersLate(prefs);
    final repo = CaptureRepository(db, mcc, location);

    final event = await scan(repo);

    // Saved with nothing, as above.
    var rows = await db.captures(limit: 10);
    expect(rows.first.geohash, isNull);

    // Then the fix lands. Awaiting the fake's own completer rather than
    // sleeping a fixed amount: a duration picked by eye is a test that fails
    // on a slow CI runner and passes on a fast one.
    await location.arrived.future;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    rows = await db.captures(limit: 10);
    final saved = rows.firstWhere((r) => r.id == event.id);
    expect(saved.geohash, 'te7ud2');
    expect(saved.placeLabel, 'Kasarvadavali, Thane');
    expect(saved.placeCountry, 'IN');
  });

  test('a late fix never overwrites a place the row already has', () async {
    // The guard on `fillCaptureLocation`'s `WHERE`. A fix can be in flight for
    // twelve seconds, which is long enough for an import or a later edit to
    // have put a real place on the row — and a stale answer arriving on top of
    // a fresh one is the "genuine disagreement" case `backfillMcc` also
    // refuses to touch.
    final prefs = await SharedPreferences.getInstance();
    final repo = CaptureRepository(db, mcc, _AnswersLate(prefs));
    final event = await scan(repo);

    await db.fillCaptureLocation(
      event.id,
      geohash: 'ttnfuc',
      placeLabel: 'Somewhere Else',
      placeCountry: 'IN',
    );

    // A second fill, as the late fix would do.
    final changed = await db.fillCaptureLocation(
      event.id,
      geohash: 'te7ud2',
      placeLabel: 'Kasarvadavali, Thane',
      placeCountry: 'IN',
    );

    expect(changed, 0, reason: 'the row already had a place');
    final rows = await db.captures(limit: 10);
    expect(rows.firstWhere((r) => r.id == event.id).placeLabel,
        'Somewhere Else');
  });
}
