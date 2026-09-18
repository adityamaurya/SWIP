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
    String? acquirer,
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
        acquirer: acquirer,
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

  // ── `F-198`. One counter, two stickers ────────────────────────────────
  //
  // > *"can we translate these QR codes in such a way that they convert into
  // > pay-by-app intent? … it is getting the merchant category codes inside it
  // > properly detected"* — prompt 55
  //
  // The transport cannot add a category. What CAN is the other sticker on the
  // same counter: `docs/42` counted 48 codes and every Google Pay for Business
  // one published `mc`, while not one Paytm, PhonePe or BharatPe one did.
  //
  // This group is mostly negative cases, for the reason the file opens with —
  // a wrong link is inherited by every future scan of that sticker, and
  // opening up QR-to-QR is the riskiest change this file has had.
  group('one counter, two stickers', () {
    final gpay = event(
      id: 'gpay',
      key: 'upi:shopname@okbizaxis',
      mcc: '5411',
      vector: CaptureVector.qr,
      acquirer: 'Google Pay',
    );
    final paytm = event(
      id: 'paytm',
      key: 'upi:paytm.s233ffl@pty',
      vector: CaptureVector.qr,
      offset: const Duration(minutes: 1),
      acquirer: 'Paytm',
    );

    test('a Google Pay code teaches the Paytm one beside it', () {
      final proposals = MerchantReconciler.propose([paytm, gpay]);
      expect(proposals, hasLength(1));
      expect(proposals.single.canonicalKey, 'upi:shopname@okbizaxis');
      expect(proposals.single.aliasKey, 'upi:paytm.s233ffl@pty');
      expect(proposals.single.mcc, '5411');
    });

    test('and it names the payment company, not the VPA', () {
      // The question is *are these the same shop*, and "the Google Pay code"
      // is something a person at a counter can look up and check.
      // `paytm.s233ffl@pty` answers a question nobody asked.
      final p = MerchantReconciler.propose([paytm, gpay]).single;
      expect(p.teacherLabel, contains('Google Pay'));
      expect(p.teacherLabel.contains('@'), isFalse);
    });

    test('two codes from the SAME company are never linked', () {
      // A row of Paytm stickers down a street is the case the original rule
      // was written for, and it is still right. A shop does not print two
      // stickers from one PSP; two neighbours very much do.
      final other = event(
        id: 'paytm2',
        key: 'upi:paytm.zzz999@pty',
        mcc: '5812',
        vector: CaptureVector.qr,
        offset: const Duration(minutes: 1),
        acquirer: 'Paytm',
      );
      expect(MerchantReconciler.propose([paytm, other]), isEmpty);
    });

    test('an unknown acquirer on either side refuses the link', () {
      // "I do not know who issued this" is the one state in which *they are
      // different* must not be assumed. A null is a refusal, not a maybe.
      final unknown = event(
        id: 'unknown',
        key: 'upi:something@newpsp',
        mcc: '5411',
        vector: CaptureVector.qr,
        offset: const Duration(minutes: 1),
      );
      expect(MerchantReconciler.propose([paytm, unknown]), isEmpty);

      final learnerUnknown = event(
        id: 'learner',
        key: 'upi:mystery@handle',
        vector: CaptureVector.qr,
        offset: const Duration(minutes: 1),
      );
      expect(MerchantReconciler.propose([learnerUnknown, gpay]), isEmpty);
    });

    test('stickers get three minutes, not twenty', () {
      // The long window exists for a sequence with a human in it — a tap that
      // failed, a word with the cashier, then the QR. Reading the second code
      // on a board is not that sequence.
      final late = event(
        id: 'late',
        key: 'upi:paytm.s233ffl@pty',
        vector: CaptureVector.qr,
        offset: const Duration(minutes: 8),
        acquirer: 'Paytm',
      );
      expect(MerchantReconciler.propose([late, gpay]), isEmpty);

      // And a tap still gets the full twenty, unchanged.
      final lateScan = event(
        id: 'lateScan',
        key: 'upi:paytm.s233ffl@pty',
        vector: CaptureVector.qr,
        offset: const Duration(minutes: 8),
        acquirer: 'Paytm',
      );
      expect(MerchantReconciler.propose([lateScan, tap]), hasLength(1));
    });

    test('a different place is still a different shop', () {
      // The geohash guard is untouched by `F-198` and this proves it, because
      // opening up QR-to-QR is exactly the change that would make losing it
      // expensive.
      final elsewhere = event(
        id: 'elsewhere',
        key: 'upi:paytm.s233ffl@pty',
        vector: CaptureVector.qr,
        offset: const Duration(minutes: 1),
        geohash: 'ttnfuc',
        acquirer: 'Paytm',
      );
      expect(MerchantReconciler.propose([elsewhere, gpay]), isEmpty);
    });

    test('a code that already has a category learns nothing', () {
      final known = event(
        id: 'known',
        key: 'upi:paytm.s233ffl@pty',
        mcc: '5812',
        vector: CaptureVector.qr,
        offset: const Duration(minutes: 1),
        acquirer: 'Paytm',
      );
      // Two different categories is a conflict to surface, not a link to make.
      expect(MerchantReconciler.propose([known, gpay]), isEmpty);
    });
  });

}
