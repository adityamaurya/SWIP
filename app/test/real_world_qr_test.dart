import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/sources/capture_resolver.dart';
import 'package:swip/data/sources/mcc_route.dart';
import 'package:swip/data/sources/merchant_identity.dart';
import 'package:swip/data/sources/rupay_outlook.dart';
import 'package:swip/data/sources/upi_uri_parser.dart';

/// `F-123`–`F-125` — the four payloads that were actually at the counter.
///
/// Every string in this file was **decoded from a photograph of the real QR**,
/// not invented. That matters more than it sounds: the two bugs these tests
/// pin down were both invisible in synthetic fixtures, because nobody writes a
/// fixture with `mc=` and nothing after it. Reality did.
///
/// If a future change breaks one of these, it has broken a code that exists on
/// a counter in Thane, and the failure message should say so.
void main() {
  group('Shree Beauty Centre — SVC Co-operative Bank, mc= left blank', () {
    // Photographed on the counter stand; the payment then failed with
    // "merchant doesn't accept credit cards or overdraft accounts".
    const raw = 'upi://pay?pa=SVCMERC00306934@svcbank&pn=SVCMERC00306934'
        '&mc=&tr=00306934&tn=&am=&mam=&cu=INR&refUrl=https://svcbank.com/';

    test('an empty mc= is blank, and blank is not absent', () {
      final upi = UpiUriParser.tryParse(raw)!;
      expect(upi.mcc, isNull);
      expect(upi.mccPublication, MccPublication.blank);
      expect(upi.hasBlankMcc, isTrue);
      // The distinction the old parser could not make.
      expect(upi.mccPublication, isNot(MccPublication.absent));
    });

    test('a <BANK>MERC<id> handle is a registered merchant', () {
      final upi = UpiUriParser.tryParse(raw)!;
      final id = MerchantIdentifier.ofIntent(upi);
      expect(id.kind, PayeeKind.registeredMerchant);
      expect(id.psp, 'SVC Co-operative Bank');
      // A bank does not acquire under the small-merchant tier and then mint a
      // reference-numbered merchant handle.
      expect(id.tier, MerchantTier.fullMerchant);
    });

    test('the RuPay verdict hedges, and says why', () {
      final upi = UpiUriParser.tryParse(raw)!;
      final v = RupayVerdict.of(
          identity: MerchantIdentifier.ofIntent(upi), intent: upi);
      expect(v.outlook, RupayCcOutlook.unlikely);
      // The same hedge CRED uses when it is inferring rather than looking up.
      expect(v.headline, contains('may not'));
      expect(v.because, contains('blank'));
    });

    test('and the absence names the acquirer, not the shop', () {
      final upi = UpiUriParser.tryParse(raw)!;
      final a = MccAbsence.of(
          identity: MerchantIdentifier.ofIntent(upi), intent: upi);
      expect(a.fixable, isTrue);
      expect(a.reason, contains('left'));
      expect(a.routes, isNotEmpty);
    });
  });

  group('Wellness Forever — Pine Labs dynamic QR, the category is right there',
      () {
    const raw = 'upi://pay?pa=WFMLMH2@ybl&pn=WELLNESS%20FOREVER%20MH%202'
        '&am=76.66&mam=76.66&tr=PINE2269706791'
        '&tn=Payment%20for%202053457707&mc=5912&mode=15&purpose=00'
        '&invoiceNo=26203S25030';

    test('reads 5912, drug stores and pharmacies', () {
      final r = CaptureResolver.resolve(raw);
      expect(r.mcc, '5912');
      expect(r.mccPublication, MccPublication.published);
      expect(r.absence, isNull);
    });

    test('a published category proves a full merchant without a loose regex',
        () {
      // `WFMLMH2` matches no merchant handle pattern, and deliberately so — any
      // regex loose enough to catch it also catches `john123@okaxis`. The
      // payload proves it instead.
      final upi = UpiUriParser.tryParse(raw)!;
      final id = MerchantIdentifier.ofIntent(upi);
      expect(id.kind, PayeeKind.registeredMerchant);
      expect(id.tier, MerchantTier.fullMerchant);
      expect(upi.isDynamic, isTrue);
      expect(upi.acquirerHint, 'PINE');
    });

    test('and the card verdict is positive', () {
      final r = CaptureResolver.resolve(raw);
      expect(r.rupay?.outlook, RupayCcOutlook.likely);
    });
  });

  group('The corn-dog stall — a Paytm sticker with nothing in it', () {
    // The whole payload. Two fields. There is no category here to "fail" to
    // catch, and no app on any phone can read one out of it.
    const raw = 'upi://pay?pa=paytm.s26upzx@pty&pn=Paytm';

    test('there is no category, and that is the payload not the parser', () {
      final r = CaptureResolver.resolve(raw);
      expect(r.mcc, isNull);
      expect(r.mccPublication, MccPublication.absent);
    });

    test('the shop is still identified, and Paytm is not called the shop', () {
      final r = CaptureResolver.resolve(raw);
      expect(r.payeeKind, PayeeKind.registeredMerchant);
      expect(r.tier, MerchantTier.fullMerchant);
      // `pn=Paytm` is the payment company. It must never become the merchant
      // name — five shops became "Paytm" once already.
      expect(r.merchantName, isNull);
      expect(r.acquirer, 'Paytm');
    });

    test('CRED reaches the same conclusion on this handle family', () {
      // CRED, at `paytm.s2fqaht@pty`: "this merchant accepts RuPay payments".
      // SWIP, at `paytm.s26upzx@pty`, from the QR alone:
      final r = CaptureResolver.resolve(raw);
      expect(r.rupay?.outlook, RupayCcOutlook.likely);
    });

    test('and the user is handed routes rather than a dead end', () {
      final r = CaptureResolver.resolve(raw);
      expect(r.absence, isNotNull);
      expect(r.absence!.fixable, isTrue);
      expect(
        r.absence!.routes.map((x) => x.kind),
        contains(MccRouteKind.tapTerminal),
      );
    });
  });

  group('The Paytm small-merchant sticker — nothing to find, and say so', () {
    const raw = 'upi://pay?pa=paytmqr70ivq3@ptys&pn=Paytm';

    test('small-merchant tier is read from the @ptys handle', () {
      final r = CaptureResolver.resolve(raw);
      expect(r.tier, MerchantTier.smallMerchant);
    });

    test('the card answer is the one unhedged claim on the screen', () {
      final r = CaptureResolver.resolve(raw);
      expect(r.rupay?.outlook, RupayCcOutlook.blocked);
      expect(r.rupay?.headline, contains('will not work'));
    });

    test('and no routes are offered, because none of them would work', () {
      final r = CaptureResolver.resolve(raw);
      expect(r.absence?.fixable, isFalse);
      expect(r.absence?.routes, isEmpty);
    });
  });

  group('the loose-regex trap that was almost shipped', () {
    test('a person with digits in their handle is never a merchant', () {
      for (final h in const [
        'john123@okaxis',
        'aditya1990@ybl',
        'ramesh7@paytm',
      ]) {
        final r = CaptureResolver.resolve('upi://pay?pa=$h&pn=Aditya');
        expect(r.payeeKind, isNot(PayeeKind.registeredMerchant),
            reason: '$h must not be called a registered merchant');
        expect(r.rupay?.outlook ?? RupayCcOutlook.unknown,
            RupayCcOutlook.unknown,
            reason: 'no card claim should be made about $h');
      }
    });
  });

  group('observed outcomes outrank every inference', () {
    const raw = 'upi://pay?pa=paytm.s26upzx@pty&pn=Paytm';

    test('a remembered decline overturns a positive payload reading', () {
      final upi = UpiUriParser.tryParse(raw)!;
      final v = RupayVerdict.of(
        identity: MerchantIdentifier.ofIntent(upi),
        intent: upi,
        declinedBefore: true,
      );
      expect(v.outlook, RupayCcOutlook.unlikely);
      expect(v.headline, contains('declined'));
    });

    test('a remembered success is the only certainty available', () {
      final upi = UpiUriParser.tryParse(raw)!;
      final v = RupayVerdict.of(
        identity: MerchantIdentifier.ofIntent(upi),
        intent: upi,
        succeededBefore: true,
      );
      expect(v.outlook, RupayCcOutlook.confirmed);
    });
  });
}
