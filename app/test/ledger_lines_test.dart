import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/models/capture_event.dart';
import 'package:swip/data/models/mcc.dart';
import 'package:swip/data/sources/ledger_lines.dart';

/// `F-149` — the plain, one-line-per-capture export.
///
/// Every payload below is real: they are taken from the owner's own
/// 85-capture export and from the QRs photographed at the counter, which is
/// the only corpus that has ever found a defect in this project.
void main() {
  CaptureEvent capture({
    required String id,
    String? mcc,
    String? merchantName,
    String? rawPayload,
    String? merchantKey,
    double? amount,
    String? currency,
    required DateTime at,
    CaptureVector vector = CaptureVector.qr,
  }) =>
      CaptureEvent(
        id: id,
        mcc: mcc,
        vector: vector,
        confidence:
            mcc == null ? MccConfidence.unknown : MccConfidence.verified,
        capturedAt: at,
        merchantName: merchantName,
        merchantKey: merchantKey,
        rawPayload: rawPayload,
        amount: amount,
        currency: currency,
      );

  group('order', () {
    test('newest first, whatever order they arrive in', () {
      final lines = LedgerLines.of([
        capture(id: 'a', at: DateTime.utc(2026, 9, 1, 10)),
        capture(id: 'c', at: DateTime.utc(2026, 9, 5, 10)),
        capture(id: 'b', at: DateTime.utc(2026, 9, 3, 10)),
      ]);

      expect(
        lines.map((l) => l.date.day).toList(),
        [5, 3, 1],
        reason: 'the owner asked for latest on top',
      );
    });

    test('an empty ledger renders rather than throwing', () {
      final text = LedgerLines.render([], now: DateTime.utc(2026, 9, 14, 6));
      expect(text, contains('Nothing captured yet'));
    });
  });

  group('"exactly captured"', () {
    test('the verbatim pn is used, not SWIP\'s cleaned name', () {
      // The Wellness Forever QR, from the Pine Labs terminal. The payload
      // carries the name percent-encoded.
      final e = capture(
        id: 'wf',
        mcc: '5912',
        merchantName: 'Wellness Forever',
        rawPayload: 'upi://pay?pa=WFMLMH2@ybl&pn=WELLNESS%20FOREVER%20MH%202'
            '&am=76.66&mc=5912&mode=15',
        at: DateTime.utc(2026, 9, 5, 14, 32),
      );

      final l = LedgerLines.of([e]).single;
      expect(l.merchant, 'WELLNESS FOREVER MH 2');
      // …and where SWIP reads it differently, that is shown too rather than
      // silently winning or silently losing.
      expect(l.swipReading, 'Wellness Forever');
    });

    test('a name SWIP rejected is still exported, and labelled', () {
      // `F-42`. Every Paytm sticker in the country carries pn=Paytm, and SWIP
      // refuses to call the payment company the shop. The export still shows
      // what the code said, because that is what "exactly captured" means.
      final e = capture(
        id: 'ptys',
        rawPayload: 'upi://pay?pa=paytmqr70ivq3@ptys&pn=Paytm',
        at: DateTime.utc(2026, 9, 4, 19, 44),
      );

      final l = LedgerLines.of([e]).single;
      expect(l.merchant, 'Paytm');
      expect(l.swipReading, contains('does not treat this as a shop name'));
    });

    test('a reference number dressed as a name, likewise', () {
      // `F-139`. The SVC Co-operative Bank QR, whose pn is its own merchant
      // reference.
      final e = capture(
        id: 'svc',
        rawPayload: 'upi://pay?pa=SVCMERC00306934@svcbank'
            '&pn=SVCMERC00306934&mc=&tr=00306934',
        at: DateTime.utc(2026, 9, 3, 11),
      );

      final l = LedgerLines.of([e]).single;
      expect(l.merchant, 'SVCMERC00306934');
      expect(l.swipReading, isNotNull);
    });

    test('when the two agree, nothing is added in brackets', () {
      final e = capture(
        id: 'tata',
        rawPayload: 'upi://pay?pa=tatastarbucks.payu@mairtel'
            '&pn=TATA%20STARBUCKS%20PRIVATE%20LIMITED',
        merchantName: 'TATA STARBUCKS PRIVATE LIMITED',
        at: DateTime.utc(2026, 9, 2, 9),
      );

      expect(LedgerLines.of([e]).single.swipReading, isNull);
    });

    test('a POS tap has no pn to go back to, and falls back cleanly', () {
      // The raw payload of an NFC capture is an APDU trace, not a code.
      final e = capture(
        id: 'pos',
        mcc: '5411',
        merchantName: 'A SHOP',
        vector: CaptureVector.nfc,
        rawPayload: '<< 00A404000E325041592E5359532E4444463031\n'
            '>> 6F2F840E325041592E5359532E44444630319000',
        at: DateTime.utc(2026, 9, 1, 8),
      );

      final l = LedgerLines.of([e]).single;
      expect(l.merchant, 'A SHOP');
      expect(l.swipReading, isNull);
    });

    test('with no name anywhere, the handle is used', () {
      final e = capture(
        id: 'bare',
        merchantKey: 'upi:paytmqr6dld0y@ptys',
        at: DateTime.utc(2026, 9, 1, 8),
      );
      expect(LedgerLines.of([e]).single.merchant, isNotNull);
    });
  });

  group('the payload parser never throws', () {
    test('on any of the shapes actually in the ledger', () {
      // Five rows in the owner's export were not payment codes at all. An
      // export that throws on row 61 of 85 is worse than one that leaves a
      // cell empty.
      const payloads = [
        'your payment qr code be here',
        'Nastco stock photos :)',
        'https://pvcprint.shop/product/gpay-pvc-qr-code-print/',
        '904560654601200 350464523 03541261 035416546879 0984684',
        '<< 00A4040007A000000003101000',
        // A percent sign that is not an escape sequence — decodeComponent
        // throws on this, and it is exactly the sort of thing a hand-printed
        // sticker carries.
        'upi://pay?pa=x@y&pn=100%25%20COTTON',
        'upi://pay?pa=x@y&pn=%',
        'upi://pay?pa=x@y&pn=',
        'upi://pay?pn=onlyname',
        '',
      ];

      for (final p in payloads) {
        final e = capture(id: p, rawPayload: p, at: DateTime.utc(2026, 9, 1));
        expect(() => LedgerLines.of([e]), returnsNormally, reason: p);
        expect(() => LedgerLines.render([e]), returnsNormally, reason: p);
      }
    });

    test('a valid percent escape is still decoded', () {
      final e = capture(
        id: 'pct',
        rawPayload: 'upi://pay?pa=x@y&pn=100%25%20COTTON',
        at: DateTime.utc(2026, 9, 1),
      );
      expect(LedgerLines.of([e]).single.merchant, '100% COTTON');
    });
  });

  group('the rendered file', () {
    final events = [
      capture(
        id: '1',
        mcc: '5912',
        merchantName: 'WELLNESS FOREVER MH 2',
        rawPayload: 'upi://pay?pa=WFMLMH2@ybl&pn=WELLNESS%20FOREVER%20MH%202'
            '&am=76.66&mc=5912',
        amount: 76.66,
        currency: 'INR',
        at: DateTime.utc(2026, 9, 5, 14, 32),
      ),
      capture(
        id: '2',
        rawPayload: 'upi://pay?pa=paytmqr70ivq3@ptys&pn=Paytm',
        at: DateTime.utc(2026, 9, 4, 19, 44),
      ),
      capture(
        id: '3',
        mcc: '5411',
        merchantName: 'A SHOP',
        amount: 5,
        currency: 'INR',
        at: DateTime.utc(2026, 9, 3, 9, 5),
      ),
    ];

    test('has the four columns asked for, date first', () {
      // The prompt enumerates MCC, merchant, amount, date — and then says
      // "so you can maybe keep the date on the first column". The later
      // sentence wins, and it is also right: the list is sorted by date, and a
      // sort key at the far right means the eye crosses three columns to check
      // the order is what it claims.
      final text = LedgerLines.render(events, now: DateTime.utc(2026, 9, 14));
      final header =
          text.split('\n').firstWhere((l) => l.startsWith('DATE'));

      expect(header.indexOf('DATE'), lessThan(header.indexOf('MCC')));
      expect(header.indexOf('MCC'), lessThan(header.indexOf('MERCHANT')));
      expect(header.indexOf('MERCHANT'), lessThan(header.indexOf('AMOUNT')));
    });

    test('amounts align on the decimal point', () {
      // 76.66 and 5 in the same column. Without toStringAsFixed(2) the second
      // renders as "₹5" and the column stops being readable beside a card
      // statement, which is the one job it has.
      final text = LedgerLines.render(events, now: DateTime.utc(2026, 9, 14));
      expect(text, contains('₹76.66'));
      expect(text, contains('₹5.00'));
    });

    test('a missing category is an em dash, never a hyphen', () {
      // A hyphen in a column next to money reads as a negative number.
      final text = LedgerLines.render(events, now: DateTime.utc(2026, 9, 14));
      final row = text.split('\n').firstWhere((l) => l.contains('Paytm'));
      // Date is now column one, so the em dash is the MCC cell after it.
      expect(row, contains('—'));
      expect(row, isNot(contains(' - ')));
    });

    test('the rows are newest first in the text, not just in the model', () {
      final text = LedgerLines.render(events, now: DateTime.utc(2026, 9, 14));
      final body = text.split('\n');
      final wellness = body.indexWhere((l) => l.contains('WELLNESS'));
      final paytm = body.indexWhere((l) => l.contains('Paytm'));
      final shop = body.indexWhere((l) => l.contains('A SHOP'));

      expect(wellness, lessThan(paytm));
      expect(paytm, lessThan(shop));
    });

    test('it explains what the merchant column is before showing it', () {
      // A reader comparing this file against the app will find the difference
      // between the verbatim name and SWIP's reading on their own, and
      // mistrust both, unless it is said first.
      final text = LedgerLines.render(events, now: DateTime.utc(2026, 9, 14));
      expect(text, contains('verbatim'));
      expect(text.indexOf('verbatim'), lessThan(text.indexOf('DATE ')));
    });

    test('the count and the with-category count are both stated', () {
      final text = LedgerLines.render(events, now: DateTime.utc(2026, 9, 14));
      expect(text, contains('3 captures'));
      expect(text, contains('2 with a category'));
    });
  });
}
