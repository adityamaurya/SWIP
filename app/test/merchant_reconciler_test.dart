import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/models/capture_event.dart';
import 'package:swip/data/models/mcc.dart';
import 'package:swip/data/sources/merchant_reconciler.dart';

/// `F-49`. Reproduces Snowberry exactly: a POS tap that read 5451, and a scan
/// of the same shop's Paytm sticker three minutes later that read nothing.
///
/// Every test here is really one question — **would SWIP ever merge two shops
/// that are not the same?** A wrong link is inherited by every future scan of
/// that sticker, so the negative cases matter more than the positive one.
void main() {
  final t0 = DateTime.utc(2026, 8, 9, 18, 0);

  CaptureEvent event({
    required String id,
    required String key,
    String? mcc,
    required CaptureVector vector,
    String? geohash = 'te7ud2',
    Duration offset = Duration.zero,
  }) =>
      CaptureEvent(
        id: id,
        mcc: mcc,
        vector: vector,
        confidence:
            mcc == null ? MccConfidence.unknown : MccConfidence.verified,
        capturedAt: t0.add(offset),
        merchantKey: key,
        geohash: geohash,
        placeLabel: 'Kasarvadavali, Thane',
      );

  final tap = event(
    id: 'tap',
    key: 'emv:356:SNOWBERRY01',
    mcc: '5451',
    vector: CaptureVector.nfc,
  );
  final scan = event(
    id: 'scan',
    key: 'upi:paytm.s233ffl@pty',
    vector: CaptureVector.qr,
    offset: const Duration(minutes: 3),
  );

  group('the Snowberry case', () {
    test('proposes linking the tap and the scan', () {
      final proposals = MerchantReconciler.propose([scan, tap]);

      expect(proposals.length, 1);
      final p = proposals.single;
      expect(p.canonicalKey, 'emv:356:SNOWBERRY01');
      expect(p.aliasKey, 'upi:paytm.s233ffl@pty');
      expect(p.mcc, '5451');
      expect(p.minutesApart, 3);
      expect(p.place, 'Kasarvadavali, Thane');
    });

    test('the teacher is always the one that knows', () {
      final p = MerchantReconciler.propose([scan, tap]).single;
      expect(p.teacher.id, 'tap');
      expect(p.learner.id, 'scan');
    });
  });

  group('what it refuses to link', () {
    test('a different place is never the same shop', () {
      final elsewhere = event(
        id: 'scan',
        key: 'upi:other@pty',
        vector: CaptureVector.qr,
        geohash: 'ttnfuc', // Delhi
        offset: const Duration(minutes: 2),
      );
      expect(MerchantReconciler.propose([elsewhere, tap]), isEmpty);
    });

    test('no location means no proposal at all', () {
      final nowhere = event(
        id: 'scan',
        key: 'upi:other@pty',
        vector: CaptureVector.qr,
        geohash: null,
        offset: const Duration(minutes: 2),
      );
      expect(MerchantReconciler.propose([nowhere, tap]), isEmpty,
          reason: 'without a place this is just "two captures near in time", '
              'which across a market street is simply false');
    });

    test('a different visit is a different shop', () {
      final later = event(
        id: 'scan',
        key: 'upi:other@pty',
        vector: CaptureVector.qr,
        offset: const Duration(hours: 5),
      );
      expect(MerchantReconciler.propose([later, tap]), isEmpty);
    });

    test('two QRs in one place are two shops in a market', () {
      final qrWithMcc = event(
        id: 'a',
        key: 'upi:shopa@pty',
        mcc: '5411',
        vector: CaptureVector.qr,
      );
      final qrWithout = event(
        id: 'b',
        key: 'upi:shopb@pty',
        vector: CaptureVector.qr,
        offset: const Duration(minutes: 1),
      );
      expect(MerchantReconciler.propose([qrWithout, qrWithMcc]), isEmpty);
    });

    test('two blanks teach each other nothing', () {
      final other = event(
        id: 'b',
        key: 'emv:356:X',
        vector: CaptureVector.nfc,
        offset: const Duration(minutes: 1),
      );
      expect(MerchantReconciler.propose([scan, other]), isEmpty);
    });

    test('an unclassified 0000 cannot teach', () {
      final zeroed = event(
        id: 'z',
        key: 'emv:356:X',
        mcc: '0000',
        vector: CaptureVector.nfc,
      );
      expect(MerchantReconciler.propose([scan, zeroed]), isEmpty);
    });

    test('a merchant already linked is not asked about again', () {
      expect(
        MerchantReconciler.propose([scan, tap],
            alreadyLinked: {'upi:paytm.s233ffl@pty'}),
        isEmpty,
      );
    });

    test('one proposal per uncategorised merchant, not one per candidate', () {
      final secondTap = event(
        id: 'tap2',
        key: 'emv:356:OTHER',
        mcc: '5814',
        vector: CaptureVector.nfc,
        offset: const Duration(minutes: 1),
      );
      final proposals = MerchantReconciler.propose([scan, tap, secondTap]);
      expect(proposals.length, 1,
          reason: 'asking twice about one sticker gets both dismissed');
    });
  });
}
