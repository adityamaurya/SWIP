import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/sources/capture_resolver.dart';
import 'package:swip/data/sources/merchant_identity.dart';
import 'package:swip/data/sources/rupay_outlook.dart';

/// `F-137` — regression tests taken from the **owner's real 85-capture
/// export**, `SWIP_Ledger_2026-09-05`.
///
/// ## What the export showed
///
/// | | |
/// |---|---|
/// | Captures | 85 |
/// | With a category | 43 |
/// | Without | 42 |
///
/// And of those 42 misses, the breakdown is the whole story:
///
/// | Count | Shape |
/// |---|---|
/// | **34** | A UPI sticker with **no `mc` parameter at all** |
/// | 5 | Not a payment QR (a stock photo, a print-shop URL, a test string) |
/// | 2 | `mc=` present and empty — the SVC bank case, `F-123` |
/// | 1 | A raw NFC APDU log |
///
/// **Eighty-one per cent of every miss is a static sticker that never carried a
/// category.** That is not a parser defect and no amount of work on the parser
/// touches it — which is why the effort went into saying so clearly
/// (`F-125`) and into extracting everything else the payload *does* carry.
///
/// The cases below are the ones where SWIP was leaving real information on the
/// table.
void main() {
  group('payment-aggregator handles were being called "undetermined"', () {
    // Both of these are in the export, both with no `mc`, and both were
    // classified as neither merchant nor person.
    test('tatastarbucks.payu@mairtel is a full merchant', () {
      final r = CaptureResolver.resolve(
          'upi://pay?pa=tatastarbucks.payu@mairtel'
          '&pn=TATA%20STARBUCKS%20PRIVATE%20LIMITED');
      expect(r.payeeKind, PayeeKind.registeredMerchant);
      expect(r.tier, MerchantTier.fullMerchant);
      expect(r.rupay?.outlook, RupayCcOutlook.likely);
    });

    test('zepto.payu@mairtel too, despite the PSP truncating the name', () {
      // `pn` arrives as "Zepto Marketplace Private Limite" - cut off mid-word.
      // Matching a suffix would miss it; matching a substring does not.
      final r = CaptureResolver.resolve('upi://pay?pa=zepto.payu@mairtel'
          '&pn=Zepto%20Marketplace%20Private%20Limite');
      expect(r.payeeKind, PayeeKind.registeredMerchant);
      expect(r.tier, MerchantTier.fullMerchant);
    });
  });

  group('a company name in pn is evidence, a personal name is not', () {
    test('a descriptive business name is NOT enough, and that is deliberate',
        () {
      // "Greymode Architectural Products" is obviously a shop to a human, and
      // SWIP does not claim it. Catching it would mean treating "Products" as
      // a business marker - and this same export contains
      // `janhavigraphics@oksbi` whose pn is "Pramod Parkar", a person's name
      // on a business-sounding handle. Vocabulary gets that wrong in both
      // directions; a registration suffix does not.
      final r = CaptureResolver.resolve('upi://pay?pa=greym0d3@okhdfcbank'
          '&pn=Greymode%20Architectural%20Products');
      expect(r.payeeKind, isNot(PayeeKind.registeredMerchant));
      // The name is still kept and shown - it is a real name, unlike "Paytm".
      expect(r.merchantName, 'Greymode Architectural Products');
    });

    test('but the four real people in the export stay people', () {
      // Every one of these is in the export. Calling any of them a merchant
      // would put a RuPay claim on a friend's personal QR.
      const people = {
        'ay125293-6@okhdfcbank': 'Akhilesh Yadav',
        '9359487134@kotakbank': 'ANJALI FULCHAND GUPTA',
        '8657663214@kotak811': 'NIKHIL GAIKWAD',
        'nikhilgaikwad3214@okicici': 'Nikhil Gaikwad',
      };
      for (final e in people.entries) {
        final r = CaptureResolver.resolve(
            'upi://pay?pa=${e.key}&pn=${Uri.encodeComponent(e.value)}');
        expect(r.payeeKind, isNot(PayeeKind.registeredMerchant),
            reason: '${e.key} is a person');
        expect(r.rupay?.outlook ?? RupayCcOutlook.unknown,
            RupayCcOutlook.unknown,
            reason: 'no card claim about a person');
      }
    });
  });

  group('the shapes that dominate the export', () {
    test('paytm.s…@pty — 14 of the 34 misses — is a full merchant', () {
      for (final h in const [
        'paytm.s2070wm@pty',
        'paytm.s1jii6k@pty',
        'paytm.s2424cr@pty',
        'paytm.s2fqaht@pty',
      ]) {
        final r = CaptureResolver.resolve('upi://pay?pa=$h&pn=Paytm');
        expect(r.tier, MerchantTier.fullMerchant, reason: h);
        // `pn=Paytm` is the payment company and must never become the shop.
        expect(r.merchantName, isNull, reason: h);
      }
    });

    test('paytmqr…@ptys — 5 of them — is the small-merchant tier', () {
      for (final h in const [
        'paytmqr650wpv@ptys',
        'paytmqr70ivq3@ptys',
        'paytmqr68yosm@ptys',
      ]) {
        final r = CaptureResolver.resolve('upi://pay?pa=$h&pn=Paytm');
        expect(r.tier, MerchantTier.smallMerchant, reason: h);
        expect(r.rupay?.outlook, RupayCcOutlook.blocked, reason: h);
      }
    });

    test('BharatPe merchants are merchants, and BharatPe is not the shop', () {
      final r = CaptureResolver.resolve(
          'upi://pay?pa=BHARATPE.9041411996@icici'
          '&pn=BharatPe%20Merchant&cu=INR&tn=Verified%20Merchant');
      expect(r.payeeKind, PayeeKind.registeredMerchant);
      expect(r.merchantName, isNull,
          reason: '"BharatPe Merchant" is a placeholder, not a shop name');
      // The PSP suffix is `@icici`, so the payment company really is ICICI -
      // BharatPe is the aggregator in the local part, not the bank behind the
      // handle. Naming the aggregator here would repeat the "Paytm is the
      // shop" mistake one level down.
      expect(r.acquirer, 'ICICI Bank');
    });
  });

  group('the five payloads in the export that are not payment codes', () {
    test('none of them throws, and none claims a category', () {
      const junk = [
        'your payment qr code be here',
        'Nastco stock photos :)',
        'https://pvcprint.shop/product/gpay-pvc-qr-code-print/',
        '904560654601200 350464523 03541261 035416546879 0984684',
        '<< 00A4040007A000000003101000',
      ];
      for (final j in junk) {
        final r = CaptureResolver.resolve(j);
        expect(r.mcc, isNull, reason: j);
        expect(r.payeeKind, isNot(PayeeKind.registeredMerchant), reason: j);
      }
    });
  });
}
