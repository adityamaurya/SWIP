import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/sources/statement_parser.dart';

/// `F-50`. The anchor case is a real line from a real Federal Bank statement,
/// for a real ₹1 payment made at a real ice-cream counter:
///
///     UPIOUT/658724829452/paytm.s233ffl@pty/Demo/5451
///
/// 5451 is Dairy Products Stores. Snowberry sells ice cream. The pairing of
/// **that VPA with that code** is what lets a Paytm sticker carrying no `mc`
/// answer correctly for ever after.
void main() {
  // Stand-in for the offline table. Deliberately does NOT contain 1234, so the
  // "a four-digit note is not a category" test means something.
  bool known(String code) => const {
        '5451', '5814', '5411', '5812', '4722', '5541', '7011',
      }.contains(code);

  group('Federal Bank — the anchor case', () {
    test('extracts the merchant and the category from the real line', () {
      final e = StatementParser.parse(
        'UPIOUT/658724829452/paytm.s233ffl@pty/Demo/5451',
        isKnownMcc: known,
      );

      expect(e.vpa, 'paytm.s233ffl@pty');
      expect(e.mcc, '5451');
      expect(e.rrn, '658724829452');
      expect(e.note, 'Demo');
      expect(e.isUsable, isTrue);
    });

    test('the key matches what a QR scan of the same sticker produces', () {
      final e = StatementParser.parse(
        'UPIOUT/658724829452/paytm.s233ffl@pty/Demo/5451',
        isKnownMcc: known,
      );
      // This equality is the entire mechanism. If these two ever drift apart,
      // a statement import silently teaches nothing.
      expect(e.merchantKey, 'upi:paytm.s233ffl@pty');
    });

    test('case in the statement does not fork the merchant graph', () {
      final e = StatementParser.parse(
        'UPIOUT/658724829452/Paytm.S233FFL@PTY/Demo/5451',
        isKnownMcc: known,
      );
      expect(e.merchantKey, 'upi:paytm.s233ffl@pty');
    });
  });

  group('real statement rows — columns, not just narrations', () {
    // The case that failed in CI. A pasted statement is columnar: date,
    // narration, type, amount, balance. Splitting on slashes alone left
    // "5451 TFR 1.00" as one token and found no category at all — so the
    // feature worked on a hand-typed narration and did nothing on anything a
    // person would actually paste.
    test('a full row with date and amount columns still parses', () {
      final e = StatementParser.parse(
        '09/08/2026 09/08/2026 '
        'UPIOUT/658724829452/paytm.s233ffl@pty/Demo/5451 '
        'TFR 1.00 51411.79 Dr',
        isKnownMcc: known,
      );

      expect(e.vpa, 'paytm.s233ffl@pty');
      expect(e.mcc, '5451');
      expect(e.rrn, '658724829452');
    });

    test('an amount that looks like a category is not adopted as one', () {
      // ₹5451 in the amount column, 5814 as the real category. Getting this
      // backwards would teach the merchant graph a wrong code permanently,
      // which is worse than learning nothing.
      final e = StatementParser.parse(
        '09/08/2026 UPIOUT/111111111111/shop@ybl/Note/5814 TFR 5451 900.00',
        isKnownMcc: known,
      );

      expect(e.mcc, '5814');
      expect(e.vpa, 'shop@ybl');
    });

    test('the date column is never read as a category', () {
      final e = StatementParser.parse(
        '10/07/2026 UPIOUT/658724829452/shop@ybl/Note/5411',
        isKnownMcc: known,
      );
      expect(e.mcc, '5411');
    });
  });

  group('robustness across banks', () {
    test('a line with no category is not usable', () {
      final e = StatementParser.parse(
        'UPI/P2M/512345678901/somebody@okaxis/Coffee',
        isKnownMcc: known,
      );
      expect(e.vpa, 'somebody@okaxis');
      expect(e.mcc, isNull);
      expect(e.isUsable, isFalse, reason: 'half a fact teaches nothing');
    });

    test('a four-digit note is NOT mistaken for a category', () {
      final e = StatementParser.parse(
        'UPIOUT/658724829452/shop@ybl/1234/',
        isKnownMcc: known,
      );
      expect(e.mcc, isNull,
          reason: '1234 is not a real category, so it must not be adopted');
    });

    test('the RRN is never mistaken for a category', () {
      final e = StatementParser.parse(
        'UPIOUT/545145451454/shop@ybl/Note/5814',
        isKnownMcc: known,
      );
      expect(e.rrn, '545145451454');
      expect(e.mcc, '5814');
    });

    test('comma and tab separated exports parse too', () {
      final e = StatementParser.parse(
        'UPIOUT,658724829452,paytm.s233ffl@pty,Demo,5451',
        isKnownMcc: known,
      );
      expect(e.vpa, 'paytm.s233ffl@pty');
      expect(e.mcc, '5451');
    });

    test('a non-UPI line yields nothing usable', () {
      final e = StatementParser.parse(
        'ATM WDL/CASH/HDFC BANK ANDHERI',
        isKnownMcc: known,
      );
      expect(e.isUsable, isFalse);
    });
  });

  group('parseAll', () {
    test('learns every merchant in a pasted statement', () {
      final entries = StatementParser.parseAll('''
09/08/2026 UPIOUT/658724829452/paytm.s233ffl@pty/Demo/5451 TFR 1.00
08/08/2026 UPIOUT/512345678901/paytmqr6twbbd@ptys/Shop/5411 TFR 250.00
07/08/2026 ATM WDL/CASH/FEDERAL BANK
06/08/2026 UPIOUT/512345678902/cafe@okhdfcbank/Latte/5814 TFR 180.00
''', isKnownMcc: known);

      expect(entries.length, 3);
      expect(
        entries.map((e) => e.merchantKey).toSet(),
        {
          'upi:paytm.s233ffl@pty',
          'upi:paytmqr6twbbd@ptys',
          'upi:cafe@okhdfcbank',
        },
      );
    });

    test('one shop paid twice is one lesson, and the later line wins', () {
      final entries = StatementParser.parseAll('''
UPIOUT/111111111111/shop@ybl/One/5411
UPIOUT/222222222222/shop@ybl/Two/5814
''', isKnownMcc: known);

      expect(entries.length, 1,
          reason: 'a repeat visit must not inflate the graph agreement count');
      expect(entries.single.mcc, '5814');
    });
  });
}
