import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/sources/capture_resolver.dart';
import 'package:swip/data/sources/merchant_identity.dart';

/// `F-182` — **48 real QR codes off real shops, and what SWIP makes of them.**
///
/// > *"sharing you multiple QRs I went to market the other day, it failed on
/// > major of the Paytm QRs, help me get it resolved man… find a pattern for
/// > which QR codes are not new, are tough to scan, and are not giving away
/// > MCC codes directly."*
///
/// 52 photographs, taken in one afternoon at a market. 48 decoded; the four
/// that did not are listed in the fixture and discussed in
/// [`docs/42`](../../docs/42-MARKET-QR-CORPUS.md).
///
/// ## Why this suite exists and what makes it different
///
/// `test/qr_corpus_test.dart` proves SWIP parses **correctly-formed** payloads
/// from every scheme. It is generated from the EMVCo spec, so it is
/// known-correct by construction — and that is also its limit: it proves
/// nothing about what Indian acquirers actually emit.
///
/// This one is the opposite. Nothing here was generated. Every string below
/// came out of a photograph of a sticker, a soundbox or a standee, which means
/// it is evidence rather than a model, and it is the only fixture in the
/// project that can answer *"how often is the category actually there?"*
///
/// **The answer is five times out of forty-eight**, and the point of pinning it
/// in a test is that it is the number the product is built around. If a change
/// makes it go up, that is a real improvement and this test should be updated
/// deliberately. If a change makes it go down, something broke.
void main() {
  final fixture = jsonDecode(
    File('test/fixtures/market_qr_corpus.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  final vectors = (fixture['vectors'] as List)
      .cast<Map<String, dynamic>>()
      .map(_Vector.from)
      .toList();

  test('the fixture is the one that was committed', () {
    // A corpus that quietly shrinks is a corpus that stops proving anything.
    expect(fixture['photos'], 52);
    expect(vectors, hasLength(48));
    expect(fixture['undecodable'], [14, 22, 33, 41]);
  });

  group('every one of them parses', () {
    test('nothing throws, and every payload yields a payment address', () {
      for (final v in vectors) {
        final r = CaptureResolver.resolve(v.payload);
        expect(r.merchantHandle, isNotNull, reason: 'page ${v.page}');
      }
    });

    test('every acquirer is named', () {
      // `F-182`. This is the assertion the market walk paid for. Five handles
      // in this corpus were unknown to SWIP — `pta`, `okbizaxis`, `okbizicici`,
      // `unitype` and `fbpe` — so five real shops would have shown a blank
      // where the payment company goes.
      //
      // A gap like that is invisible by reading: the map has fifty entries and
      // looks exhaustive, and the missing ones are missing precisely because
      // nobody thought of them.
      for (final v in vectors) {
        final r = CaptureResolver.resolve(v.payload);
        expect(r.acquirer, isNotNull,
            reason: 'page ${v.page}, handle @${v.handle}');
      }
    });
  });

  group('the distribution, which is the whole product problem', () {
    test('exactly five of forty-eight carry a usable category', () {
      final withMcc =
          vectors.where((v) => CaptureResolver.resolve(v.payload).hasMcc);
      expect(withMcc, hasLength(5),
          reason: 'change this deliberately, never to make a build pass');
    });

    test('and all five are Google Pay for Business or a bank-acquired biller',
        () {
      // The pattern in one line: **the acquirer decides, not the shop.** Google
      // Pay populates `mc` on every business QR it mints; Paytm, PhonePe and
      // BharatPe populate it on none of them.
      for (final v in vectors) {
        final r = CaptureResolver.resolve(v.payload);
        if (!r.hasMcc) continue;
        expect(
          v.brand,
          anyOf('Google Pay', 'Vyapar / HDFC'),
          reason: 'page ${v.page} carries ${r.mcc}',
        );
      }
    });

    test('no Paytm code in the corpus carries a category at all', () {
      // Fourteen of them, and not one has an `mc` parameter — not empty, not
      // zero, **absent**. `CLAUDE.md` has recorded this since the first corpus
      // and this is the sample that makes it a measurement.
      final paytm = vectors.where((v) => v.brand == 'Paytm');
      expect(paytm, hasLength(14));
      for (final v in paytm) {
        expect(v.mc, isNull, reason: 'page ${v.page}: ${v.payload}');
      }
    });

    test('twenty-two PhonePe codes say 0000, which is not a category', () {
      final zeros = vectors.where((v) => v.mc == '0000');
      expect(zeros, hasLength(22));
      for (final v in zeros) {
        final r = CaptureResolver.resolve(v.payload);
        // The literal is kept so the app can say "the acquirer filled this in
        // with zeros", which is a different sentence from "no field was
        // published". What must never happen is 0000 reaching a screen as the
        // hero number — `F-154`, where two getters of the same name disagreed.
        expect(r.mcc, '0000', reason: 'page ${v.page}');
        expect(r.hasMcc, isFalse, reason: 'page ${v.page}');
      }
    });
  });

  group('the payment company never becomes the shop', () {
    test('no capture is named Paytm, PhonePeMerchant or Verified Merchant', () {
      // `F-42`. Every `pn` in this corpus is a placeholder printed by the PSP:
      // "Paytm", "PhonePeMerchant", "Verified Merchant", "Google Pay Merchant",
      // "Default". Forty-eight shops, and the QR names none of them.
      //
      // That is the entire argument for the merchant-name lookup in
      // `docs/41` — and the reason it is worth the one network call it costs.
      for (final v in vectors) {
        final r = CaptureResolver.resolve(v.payload);
        final name = r.merchantName?.toLowerCase();
        if (name == null) continue;
        expect(
          name,
          isNot(anyOf(
            'paytm',
            'phonepe',
            'phonepemerchant',
            'verified merchant',
            'google pay merchant',
            // `F-182`. This one is why the assertion is worth having: it
            // failed here on the first CI run, on two Vyapar codes carrying
            // `pn=Default`. Every earlier placeholder in this list is PSP
            // branding; this one is a billing app's unset form field, which is
            // why no amount of reading the list would have suggested it.
            'default',
          )),
          reason: 'page ${v.page} took the PSP placeholder as a shop name',
        );
      }
    });
  });

  group('who can take a RuPay credit card', () {
    test('a merchant-minted handle is never called a person', () {
      // Every local part in this corpus is one a PSP mints at onboarding:
      // `paytm.s…`, `paytmqr…`, `Q…`, `BHARATPE…`, `gpay-…`. A person cannot
      // obtain one, so calling any of these undetermined would be SWIP
      // refusing to answer a question it can answer.
      for (final v in vectors) {
        final r = CaptureResolver.resolve(v.payload);
        expect(r.payeeKind, isNot(PayeeKind.person), reason: 'page ${v.page}');
      }
    });

    test('and the three signed PhonePe codes are registered merchants', () {
      // `sign=` is a **DER ECDSA signature** over the QR's fields — an ASN.1
      // SEQUENCE of two INTEGERs, r and s. It is not a JWT and it carries no
      // payload of its own, so its only use is as proof that NPCI minted this
      // code. Three of the twenty-four PhonePe codes have one.
      final signed = vectors.where((v) => v.signed);
      expect(signed, hasLength(3));
      for (final v in signed) {
        final r = CaptureResolver.resolve(v.payload);
        expect(r.payeeKind, PayeeKind.registeredMerchant,
            reason: 'page ${v.page}');
      }
    });
  });
}

class _Vector {
  const _Vector(this.page, this.payload, this.brand, this.handle, this.mc,
      this.signed);

  factory _Vector.from(Map<String, dynamic> j) => _Vector(
        j['page'] as int,
        j['payload'] as String,
        j['brand'] as String,
        j['handle'] as String,
        j['mc'] as String?,
        j['signed'] as bool,
      );

  final int page;
  final String payload;
  final String brand;
  final String handle;
  final String? mc;
  final bool signed;
}
