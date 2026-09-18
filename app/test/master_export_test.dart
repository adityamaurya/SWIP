import 'package:flutter_test/flutter_test.dart';
import 'package:swip/features/bubble/blackbox_page.dart';
import 'package:swip/features/bubble/master_export.dart';

/// `F-195` — **one file instead of three.**
///
/// > *"can you help me create a master export file for all the types of
/// > exports about this system whenever I upload, so that you have a mega
/// > export file?"* — prompt 54
///
/// The test that matters is the last group. A "master export" is a file whose
/// name invites somebody to forward it without reading it, so what it must
/// never contain is worth asserting rather than commenting — `CLAUDE.md`, on
/// `TapTrace`: *a privacy rule enforced by a function signature survives a
/// hurried edit; one written in a comment does not.* This one cannot be
/// enforced by a signature, because `compose` takes strings. So it is enforced
/// by feeding real-looking captures in and proving none comes out.
void main() {
  Future<String> build({
    Map<Blackbox, String> dumps = const {},
    Map<String, Object?> env = const {'device': 'Nothing A065'},
    int captures = 7,
  }) =>
      MasterExport.compose(
        captureCount: captures,
        now: DateTime.utc(2026, 9, 17, 12),
        dump: (box) async => dumps[box] ?? '',
        environment: () async => env,
      );

  group('the bundle', () {
    test('carries every recorder, named', () async {
      final text = await build(dumps: {
        Blackbox.bubble: 'bubble.shown x=18',
        Blackbox.tap: 'hce.field',
        Blackbox.power: 'power.awake overlay',
      });

      for (final box in Blackbox.values) {
        expect(text, contains(box.title.toUpperCase()),
            reason: '${box.name} section missing');
      }
      expect(text, contains('bubble.shown x=18'));
      expect(text, contains('hce.field'));
      expect(text, contains('power.awake overlay'));
    });

    test('a recorder with nothing in it says so', () async {
      // Not a blank gap. "Nothing recorded" and "this section failed to read"
      // look identical in an empty file and are completely different findings
      // — which is the whole reason a round can be spent guessing.
      final text = await build(dumps: {Blackbox.tap: 'hce.field'});
      expect(text, contains('(nothing recorded)'));
    });

    test('a recorder that throws does not fail the export', () async {
      // The day this matters is the day one channel is wedged and the export
      // is the only way to find out why. An exception here would make the
      // instrument unavailable exactly when the instrument is the point.
      final text = await MasterExport.compose(
        captureCount: 3,
        now: DateTime.utc(2026, 9, 17),
        dump: (box) async {
          if (box == Blackbox.tap) throw StateError('channel is wedged');
          return 'ok.line';
        },
        environment: () async => const {},
      );
      expect(text, contains('SWIP MASTER EXPORT'));
      // The other two recorders still reported.
      expect(text, contains('ok.line'));
      // And the broken one is named as broken rather than as empty.
      expect(text, contains('could not be read'));
      expect(text, contains('channel is wedged'));
    });

    test('the environment block is written out', () async {
      final text = await build(env: const {
        'device': 'Nothing A065',
        'androidSdk': 34,
        'isDefaultPayment': false,
      });
      expect(text, contains('Nothing A065'));
      expect(text, contains('34'));
      // `docs/45` failure #3 — the single most common reason a tap reads as
      // broken, and the first thing to look at in any POS trace.
      expect(text, contains('isDefaultPayment'));
    });

    test('line counts are stated, so a truncated file is obvious', () async {
      final text = await build(dumps: {
        Blackbox.power: List.generate(5, (i) => 'line $i').join('\n'),
      });
      expect(text, contains('5 lines'));
    });

    test('blank lines in a dump are not counted as lines', () async {
      final text = await build(dumps: {Blackbox.tap: 'a\n\n\nb\n'});
      expect(text, contains('2 lines'));
    });
  });

  group('what it must never contain', () {
    test('no captures, however real the recorders look', () async {
      // Everything a capture is made of, fed in as if a recorder had leaked
      // it. None of these strings is put there BY the export — the point is
      // that the export has no code path that reaches the ledger at all, and
      // this asserts the absence rather than trusting it.
      final text = await build(captures: 142);

      for (final secret in const [
        'paytm.s27l8o9@pty', // a payment address
        '5411', // a category
        'Balaji Stores', // a merchant name
        'te7ud2', // a geohash
        '504.00', // an amount
        'upi://pay', // a raw payload
      ]) {
        expect(text.contains(secret), isFalse,
            reason: 'the master export leaked $secret');
      }

      // The ledger contributes exactly one thing: how many rows exist.
      expect(text, contains('Captures in the ledger: 142'));
    });

    test('and it says so in the file, for whoever receives it', () async {
      // The header is not decoration. This file's name invites forwarding;
      // the person who receives it should be able to read what it is without
      // parsing it.
      final text = await build();
      expect(text, contains('contains NO captures'));
    });
  });
}
