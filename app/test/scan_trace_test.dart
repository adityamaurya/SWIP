import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swip/core/diagnostics/scan_trace.dart';

/// `F-197` — **the scan black box.**
///
/// > *"create an export log for the scans that we are doing… an exportable
/// > file"* — prompt 51, E5
///
/// The last group is the one that matters. `CLAUDE.md`, on `TapTrace`: *a
/// privacy rule enforced by a function signature survives a hurried edit; one
/// written in a comment does not.*
///
/// `ScanTrace.decoded` cannot be handed a payload — it takes a [ScanShape],
/// and that type carries only counts and members of closed sets. These tests
/// feed the real Paytm QR from `docs/46` through the whole path and assert
/// that not one identifying byte of it reaches the file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ScanTrace.testStore = await SharedPreferences.getInstance();
    await ScanTrace.clear();
  });

  tearDown(() => ScanTrace.testStore = null);

  Future<List<Map<String, Object?>>> lines() async {
    final text = await ScanTrace.dump();
    if (text.isEmpty) return const [];
    return text
        .split('\n')
        .map((l) => jsonDecode(l) as Map<String, Object?>)
        .toList();
  }

  group('the line format', () {
    test('every line is one JSON object with a stamp and an event', () async {
      await ScanTrace.opened('full');
      await ScanTrace.stuck(msSinceOpen: 6000, torchOn: false);
      await ScanTrace.closed(outcome: ScanOutcome.abandoned, msOpen: 9100);

      final ls = await lines();
      expect(ls.map((l) => l['e']),
          ['scan.open', 'scan.stuck', 'scan.close']);
      for (final l in ls) {
        expect(l['t'], isA<String>());
        // Parses as a real instant, rather than merely being a string.
        expect(DateTime.tryParse(l['t']! as String), isNotNull);
        expect(l['v'], isA<Map<String, Object?>>());
      }
    });

    test('an abandoned scanner is recorded as abandoned', () async {
      // **The most interesting line in the file.** It is the one that says
      // whether the camera is good enough, and no other instrument in SWIP
      // can see it — the ledger only ever hears about successes.
      await ScanTrace.closed(outcome: ScanOutcome.abandoned, msOpen: 12400);
      final v = (await lines()).single['v']! as Map<String, Object?>;
      expect(v['outcome'], 'abandoned');
      expect(v['ms'], 12400);
    });

    test('nothing recorded dumps empty, not a blank line', () async {
      // "Nothing recorded" and "this failed to read" must not look alike —
      // they are different findings. An empty string lets the caller say so.
      expect(await ScanTrace.dump(), isEmpty);
    });

    test('the file is bounded, and it is the END that survives', () async {
      // `CLAUDE.md`, from `F-189`: a file nobody can bear to read is not a
      // flight recorder. And the end of a log is the part that explains what
      // just went wrong, which is why the trim is from the front.
      for (var i = 0; i < ScanTrace.maxLines + 25; i++) {
        await ScanTrace.closed(outcome: ScanOutcome.decoded, msOpen: i);
      }
      final ls = await lines();
      expect(ls.length, ScanTrace.maxLines);
      expect((ls.last['v']! as Map)['ms'], ScanTrace.maxLines + 24);
    });
  });

  group('the shape', () {
    test('a Google Pay code is filed under googlepay, category published', () {
      final shape = ScanShape.of(
          'upi://pay?pa=merchant@okbizaxis&pn=Shop&mc=5411&cu=INR');
      expect(shape.kind, 'upi');
      expect(shape.pspFamily, 'googlepay');
      expect(shape.mccPublication, 'published');
    });

    test('a Paytm code is filed under paytm, category absent', () {
      // `docs/46` — the real 39-byte code, and the whole `docs/42` finding in
      // one line: the acquirer decides.
      final shape =
          ScanShape.of('upi://pay?pa=paytm.s27l8o9@pty&pn=Paytm');
      expect(shape.pspFamily, 'paytm');
      expect(shape.mccPublication, 'absent');
      expect(shape.bytes, 39);
    });

    test('blank and absent are told apart', () {
      // A bank that built a merchant QR and left the category empty is a
      // different finding from one that never carried the field. `docs/42`.
      expect(ScanShape.of('upi://pay?pa=a@okaxis&mc=').mccPublication, 'blank');
      expect(ScanShape.of('upi://pay?pa=a@okaxis').mccPublication, 'absent');
      expect(ScanShape.of('upi://pay?pa=a@okaxis&mc=0000').mccPublication,
          'unclassified');
    });

    test('a non-payment code is other, with no psp and no category', () {
      final shape = ScanShape.of('https://example.com/a/very/long/path');
      expect(shape.kind, 'other');
      expect(shape.pspFamily, isNull);
      expect(shape.mccPublication, isNull);
      expect(shape.bytes, 36);
    });

    test('an unrecognised handle becomes "other", never itself', () {
      // A privacy decision rather than a tidiness one. Returning an unknown
      // handle would put a real, possibly shop-specific string into a file
      // that is meant to be mailed to somebody.
      final shape = ScanShape.of('upi://pay?pa=shop@brandnewpsp2026');
      expect(shape.pspFamily, 'other');
    });
  });

  group('what it can never contain', () {
    test('the payload does not survive the trip', () async {
      // The real code from `docs/46`, taken all the way through the recorder.
      const payload = 'upi://pay?pa=paytm.s27l8o9@pty&pn=Paytm';

      await ScanTrace.opened('full');
      await ScanTrace.decoded(
        shape: ScanShape.of(payload),
        msSinceOpen: 1800,
        torchOn: false,
      );
      await ScanTrace.closed(outcome: ScanOutcome.decoded, msOpen: 2100);

      final text = await ScanTrace.dump();

      for (final secret in const [
        'paytm.s27l8o9@pty', // the address
        's27l8o9', // the part that identifies THIS shop
        'upi://pay', // the payload itself
        '@pty', // even the handle
      ]) {
        expect(text.contains(secret), isFalse,
            reason: 'the scan trace leaked $secret');
      }

      // And the useful part did survive — a test that passes because nothing
      // was written at all would be worthless.
      expect(text, contains('paytm')); // the FAMILY, which is not a shop
      expect(text, contains('absent'));
      expect(text, contains('1800'));
    });

    test('a shop-specific handle cannot reach the file through the family',
        () async {
      // The family is deliberately coarse: `paytm.s27l8o9@pty` identifies one
      // shop, `paytm` identifies a company with millions of them. If this ever
      // starts returning the handle, this test is what says so.
      await ScanTrace.decoded(
        shape: ScanShape.of('upi://pay?pa=vyapar.175338547694@hdfcbank'),
        msSinceOpen: 900,
        torchOn: true,
      );
      final text = await ScanTrace.dump();
      expect(text.contains('175338547694'), isFalse);
      expect(text.contains('vyapar'), isFalse);
      expect(text, contains('bank'));
    });
  });
}
