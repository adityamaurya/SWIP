import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/sources/capture_resolver.dart';
import 'package:swip/data/sources/merchant_identity.dart';
import 'package:swip/data/sources/rupay_outlook.dart';

/// `F-154` — **the ten QR codes from the owner's 63-page PDF.**
///
/// > *"shared you a list of QRs, make sure you find the MCC no matter what,
/// > and find and confirm if the rupay is accepted or not."*
///
/// Every payload below was decoded out of the PDF's page images — nine by
/// OpenCV, one more by ZXing on a second pass. They are the exact bytes the
/// phone was pointed at, not transcriptions.
///
/// The PDF is unusually valuable because it **pairs each code with what a
/// payment app said about it** on the next page. That makes it the first
/// corpus in this project that can check SWIP's RuPay verdict against a real
/// second opinion rather than against my reasoning.
void main() {
  // ── the corpus, verbatim ────────────────────────────────────────────────
  const paytmFullMerchant1 =
      'upi://pay?pa=paytm.s1jii6k@pty&pn=Paytm&tn=Verified Paytm Account';
  const paytmFullMerchant2 = 'upi://pay?pa=paytm.s2070wm@pty&pn=Paytm';
  const paytmFullMerchant3 = 'upi://pay?pa=paytm.s233ffl@pty&pn=Paytm';
  const paytmFullMerchant4 = 'upi://pay?pa=paytm.s28uaa5@pty&pn=Paytm';
  const paytmSticker1 = 'upi://pay?pa=paytmqr68ud8l@ptys&pn=Paytm';
  const paytmSticker2 = 'upi://pay?pa=paytmqr6twbbd@ptys&pn=Paytm';
  const gpayMerchant =
      'upi://pay?pa=gpay-11257000245@okbizaxis&mc=5411&pn=Google%20Pay%20'
      'Merchant&oobe=fos123&qrst=snp&tr=1257000245&cu=INR&ver=01&mode=01';
  const personWithZeroMcc =
      'upi://pay?pa=9892033544-2@ybl&pn=VANDANA%20HANUMANT%20GAIKWAD'
      '&mc=0000&mode=02&purpose=00';
  const bharatPe = 'upi://pay?pa=BHARATPE.9U0T0Q0D4Q030860@unitype'
      '&pn=Verified Merchant&cu=INR&tn=Pay to BharatPe Merchant';
  const phonePeMerchant =
      'upi://pay?mode=02&pa=Q848969421@ybl&purpose=00&mc=0000'
      '&pn=PhonePeMerchant&orgid=180001'
      '&sign=MEUCIBxZpDghg2G9O3wqt8IInBiaKLj7FO3mBSv9gXV5KGoFAiEA2cWUi6Wdl'
      'L8S8N6Hi3bT/Xo6xqhsarm3zmWq4gBjuco=';

  group('the one code that actually carries a category', () {
    test('the Google Pay merchant QR publishes mc=5411', () {
      // One of ten. This is the whole distribution problem in a single
      // number, and it matches the 85-capture export exactly: the category is
      // in the code when the acquirer put it there, and nine times out of ten
      // they did not.
      final r = CaptureResolver.resolve(gpayMerchant);
      expect(r.mcc, '5411');
      expect(r.payeeKind, PayeeKind.registeredMerchant);
      expect(r.rupay?.outlook, RupayCcOutlook.likely);
    });
  });

  group('mc=0000 is a merchant who was classified as nothing', () {
    test('the PhonePe merchant QR is a merchant, with no usable category', () {
      // `mode=02` and a `sign=` block: this is a signed merchant QR, so the
      // payee is definitely a business. `mc=0000` is the acquirer saying "not
      // categorised" rather than "not a merchant", and SWIP must not turn
      // 0000 into a category.
      final r = CaptureResolver.resolve(phonePeMerchant);

      // `mcc` deliberately still carries the literal '0000' — that is how
      // `isUnclassified` can say "the acquirer filled the field in with
      // zeros", which is a different sentence from "no field was published".
      // The predicate that decides whether a number is shown is `hasMcc`, and
      // `F-154` is that `CaptureEvent.hasMcc` disagreed with this one.
      expect(r.mcc, '0000');
      expect(r.hasMcc, isFalse, reason: '0000 is an absence, not a category');
      expect(r.payeeKind, PayeeKind.registeredMerchant);
      // "PhonePeMerchant" is the PSP's placeholder, not the shop.
      expect(r.merchantName, isNull);
    });

    test('a person on a P2PM handle with mc=0000 is not promoted to a shop',
        () {
      // `VANDANA HANUMANT GAIKWAD` on a phone-number handle. `mode=02` is
      // present and `mc=0000`, but there is no signature — and a personal
      // name on a phone handle is the shape `F-19` exists for. Calling this a
      // merchant would put a RuPay claim on somebody's personal QR.
      final r = CaptureResolver.resolve(personWithZeroMcc);
      expect(r.hasMcc, isFalse);
      // No signature, a phone-number handle, and a personal name. `mode=02`
      // alone is not enough — `merchant_identity` requires mode AND a
      // signature, precisely so a code like this one is not promoted.
      expect(r.payeeKind, isNot(PayeeKind.registeredMerchant));
      expect(r.rupay?.outlook ?? RupayCcOutlook.unknown,
          RupayCcOutlook.unknown,
          reason: 'no card claim about a person');
    });
  });

  group('the Paytm tiers, which decide the RuPay answer', () {
    test('paytm.sXXXXXX@pty is the full-merchant tier', () {
      for (final p in const [
        paytmFullMerchant1,
        paytmFullMerchant2,
        paytmFullMerchant3,
        paytmFullMerchant4,
      ]) {
        final r = CaptureResolver.resolve(p);
        expect(r.tier, MerchantTier.fullMerchant, reason: p);
        // `F-42`. "Paytm" is the payment company and must never become the
        // shop — CRED shows the real name here, and §5 of docs/35 explains
        // how it gets it.
        expect(r.merchantName, isNull, reason: p);
        expect(r.rupay?.outlook.isNegative ?? false, isFalse, reason: p);
      }
    });

    test('paytmqrXXXXXX@ptys is the small-merchant tier, and RuPay is blocked',
        () {
      for (final p in const [paytmSticker1, paytmSticker2]) {
        final r = CaptureResolver.resolve(p);
        expect(r.tier, MerchantTier.smallMerchant, reason: p);
        // NPCI policy, not a merchant setting: credit card on UPI is not
        // permitted at P2PM.
        expect(r.rupay?.outlook, RupayCcOutlook.blocked, reason: p);
      }
    });
  });

  group('BharatPe', () {
    test('a BharatPe merchant is a merchant, and BharatPe is not the shop',
        () {
      final r = CaptureResolver.resolve(bharatPe);
      expect(r.payeeKind, PayeeKind.registeredMerchant);
      expect(r.merchantName, isNull,
          reason: '"Verified Merchant" is a placeholder, not a name');
    });
  });

  group('nothing in the corpus throws, and nothing is over-claimed', () {
    const all = [
      paytmFullMerchant1,
      paytmFullMerchant2,
      paytmFullMerchant3,
      paytmFullMerchant4,
      paytmSticker1,
      paytmSticker2,
      gpayMerchant,
      personWithZeroMcc,
      bharatPe,
      phonePeMerchant,
    ];

    test('every payload resolves without throwing', () {
      for (final p in all) {
        expect(() => CaptureResolver.resolve(p), returnsNormally, reason: p);
      }
    });

    test('a category is only ever claimed when the code carried one', () {
      // Exactly one of the ten publishes a usable `mc`. If this count ever
      // goes up without the corpus changing, something has started inventing
      // categories.
      final withMcc =
          all.where((p) => CaptureResolver.resolve(p).hasMcc).length;
      expect(withMcc, 1, reason: 'only the Google Pay merchant QR has one');
    });

    test('the only unhedged RuPay claim is the one NPCI policy settles', () {
      // `blocked` is absolute because P2PM cannot take a credit card on UPI
      // at all. Everything else is an inference and must read as one.
      for (final p in all) {
        final o = CaptureResolver.resolve(p).rupay?.outlook;
        if (o == RupayCcOutlook.blocked) {
          expect(CaptureResolver.resolve(p).tier, MerchantTier.smallMerchant,
              reason: p);
        }
      }
    });
  });
}
