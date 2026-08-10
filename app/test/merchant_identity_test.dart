import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/sources/capture_resolver.dart';
import 'package:swip/data/sources/merchant_identity.dart';

/// `F-42`. These are the two real stickers that produced five ledger rows all
/// reading "Unknown category · Paytm" for five different shops.
///
/// The handles are taken from the photographs; the parameters around them are
/// the shape Paytm's static QR uses. What is being pinned down here is the
/// behaviour, not the exact bytes: a shop handle must never be reported as a
/// person, and the payment company must never be reported as the shop.
void main() {
  group('payee identity', () {
    test('a Paytm shop sticker is a registered merchant, not a person', () {
      final id = MerchantIdentifier.of(
        'paytmqr6twbbd@ptys',
        payeeName: 'Paytm',
        signed: true,
        mode: '02',
      );

      expect(id.kind, PayeeKind.registeredMerchant);
      expect(id.psp, 'Paytm');
      // The whole point: "Paytm" is rejected as the shop's name.
      expect(id.displayName, isNull);
      expect(id.identityLine, 'paytmqr6twbbd@ptys');
    });

    test('the Paytm soundbox handle is also a merchant', () {
      final id = MerchantIdentifier.of('paytm.s28uaa5@pty', payeeName: 'Paytm');
      expect(id.kind, PayeeKind.registeredMerchant);
      expect(id.psp, 'Paytm');
    });

    test('a bare phone-number handle is a person', () {
      final id = MerchantIdentifier.of('9820012345@ybl', payeeName: 'Aditya M');
      expect(id.kind, PayeeKind.person);
      expect(id.psp, 'PhonePe');
      // A real name survives — it is only the placeholders that are dropped.
      expect(id.displayName, 'Aditya M');
    });

    test('a real shop name is kept', () {
      final id = MerchantIdentifier.of(
        'paytmqr2810@ptys',
        payeeName: 'Akruti Enterprise',
        signed: true,
        mode: '02',
      );
      expect(id.displayName, 'Akruti Enterprise');
      expect(id.identityLine, 'Akruti Enterprise');
    });

    test('placeholder names are rejected in every casing and variant', () {
      for (final name in [
        'Paytm',
        'paytm merchant',
        'PhonePe Merchant',
        'GOOGLE PAY',
        'UPI',
        'Merchant',
        'BharatPe',
      ]) {
        expect(MerchantIdentifier.isGenericName(name), isTrue,
            reason: '"$name" must not be shown as a shop');
      }
    });

    test('an unsigned handle with no merchant marks stays undetermined', () {
      final id = MerchantIdentifier.of('somebody@okaxis');
      expect(id.kind, PayeeKind.undetermined);
      expect(id.psp, 'Google Pay');
    });
  });

  group('resolver, end to end', () {
    test('a merchant QR with no mc still identifies the shop and the PSP', () {
      final r = CaptureResolver.resolve(
        'upi://pay?pa=paytmqr6twbbd@ptys&pn=Paytm&mode=02&orgid=159761'
        '&sign=MEUCIQDxyz',
      );

      expect(r.mcc, isNull, reason: 'the code genuinely carries no category');
      expect(r.hasMcc, isFalse);
      expect(r.payeeKind, PayeeKind.registeredMerchant);
      expect(r.acquirer, 'Paytm');
      expect(r.merchantName, isNull, reason: 'Paytm is not the shop');
      expect(r.merchantHandle, 'paytmqr6twbbd@ptys');
      expect(r.identityLine, 'paytmqr6twbbd@ptys');
      expect(r.merchantKey, 'upi:paytmqr6twbbd@ptys');
    });

    test('an mc that is present is still read, and wins', () {
      final r = CaptureResolver.resolve(
        'upi://pay?pa=paytmqr6twbbd@ptys&pn=Kirana%20Store&mc=5411&mode=02',
      );
      expect(r.mcc, '5411');
      expect(r.hasMcc, isTrue);
      expect(r.merchantName, 'Kirana Store');
    });

    test('two captures of the same shop produce the same graph key', () {
      final a = CaptureResolver.resolve(
          'upi://pay?pa=paytmqr6twbbd@ptys&pn=Paytm&mode=02');
      final b = CaptureResolver.resolve(
          'upi://pay?pa=PaytmQR6TWBBD@ptys&pn=Paytm%20Merchant&am=250');

      expect(a.merchantKey, b.merchantKey,
          reason: 'case must not fork the merchant graph');
    });
  });

  /// `F-46`, `F-47`. Three real counters, three CRED verdicts. This is the
  /// hypothesis stated as a test so that a counter-example fails loudly rather
  /// than quietly making the app confidently wrong.
  group('merchant tier — the P2M / P2PM split', () {
    test('a Paytm Soundbox handle is full-merchant tier', () {
      // Akruti Enterprise and Snowberry. CRED offered RuPay credit cards at
      // both, so both are P2M — and a P2M merchant has an MCC somewhere.
      for (final handle in ['paytm.s28uaa5@pty', 'paytm.s233ffl@pty']) {
        final id = MerchantIdentifier.of(handle, payeeName: 'Paytm');
        expect(id.tier, MerchantTier.fullMerchant, reason: handle);
        expect(id.tier.canHaveMcc, isTrue);
        expect(id.tier.rupayNote, contains('should work'));
      }
    });

    test('a basic Paytm sticker handle is small-merchant tier', () {
      // "Best Wishes". CRED: "MERCHANT DOES NOT ACCEPT RUPAY CC".
      final id = MerchantIdentifier.of('paytmqr6twbbd@ptys', payeeName: 'Paytm');
      expect(id.tier, MerchantTier.smallMerchant);
      // The finding that matters: there is nothing to find, so SWIP must stop
      // implying the category is merely missing.
      expect(id.tier.canHaveMcc, isFalse);
      expect(id.tier.rupayNote, contains('will not work'));
    });

    test('both tiers are still registered merchants, not people', () {
      for (final handle in ['paytm.s28uaa5@pty', 'paytmqr6twbbd@ptys']) {
        expect(MerchantIdentifier.of(handle).kind,
            PayeeKind.registeredMerchant, reason: handle);
      }
    });

    test('an unrecognised handle claims no tier', () {
      final id = MerchantIdentifier.of('somebody@okaxis');
      expect(id.tier, MerchantTier.unknown);
      expect(id.tier.rupayNote, isNull,
          reason: 'no claim is better than a guess about someone money');
      expect(id.tier.canHaveMcc, isTrue,
          reason: 'unknown must not be read as "no MCC exists"');
    });

    test('the tier reaches the resolver', () {
      final small = CaptureResolver.resolve(
          'upi://pay?pa=paytmqr6twbbd@ptys&pn=Paytm&mode=02');
      expect(small.tier, MerchantTier.smallMerchant);

      final full = CaptureResolver.resolve(
          'upi://pay?pa=paytm.s233ffl@pty&pn=Paytm&mode=02');
      expect(full.tier, MerchantTier.fullMerchant);
    });
  });
}
