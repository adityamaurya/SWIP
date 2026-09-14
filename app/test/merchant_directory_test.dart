import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/sources/merchant_directory.dart';

/// `F-157` — resolving a VPA to the name CRED shows.
///
/// Every case here is driven through an injected transport, so the suite never
/// touches a network and `docs/30` §1's "no HTTP client in a no-server app"
/// check stays meaningful.
///
/// The fixture is the real one: page 1 of the owner's PDF is a Paytm sticker
/// carrying `pn=Paytm`, and page 3 is CRED showing **Jagannathrao Hospitality
/// Private Limited** for that same code. The name is not in the QR. This is
/// the lookup that produces it.
void main() {
  const realSticker = 'paytm.s1jii6k@pty';
  const realName = 'Jagannathrao Hospitality Private Limited';

  // The fixture key is `key-id` rather than an `rzp_test_…` lookalike on
  // purpose. `docs/30` §1 step 2 greps the tree for Razorpay key prefixes
  // before every build, and a fixture that trips it on every run is how a real
  // key eventually gets scrolled past.
  RazorpayDirectory dir(
    DirectoryResponse Function(DirectoryRequest r) handler, {
    void Function(DirectoryRequest r)? spy,
  }) =>
      RazorpayDirectory(
        keyId: 'key-id',
        keySecret: 'secret',
        send: (r) async {
          spy?.call(r);
          return handler(r);
        },
      );

  group('the lookup that CRED is making', () {
    test('a VPA with no name in its QR resolves to the registered name',
        () async {
      final d = dir((_) => DirectoryResponse(
            statusCode: 200,
            body: jsonEncode({
              'success': true,
              'customer_name': realName,
              'vpa': realSticker,
            }),
          ));

      final e = await d.lookup(realSticker);
      expect(e.ok, isTrue);
      expect(e.name, realName);
      expect(e.valid, isTrue);
      expect(e.provider, 'Razorpay');
    });

    test('a VPA that does not exist is a finding, not an error', () async {
      // Razorpay answers a non-existent address with a 400. A sticker whose
      // VPA does not resolve is a sticker worth not paying, so this is
      // information rather than a failure.
      final d = dir((_) => const DirectoryResponse(statusCode: 400, body: '{}'));
      final e = await d.lookup('nobody@nowhere');
      expect(e.ok, isTrue);
      expect(e.valid, isFalse);
      expect(e.name, isNull);
    });

    test('a 200 with no name is not turned into one', () async {
      final d = dir((_) => DirectoryResponse(
          statusCode: 200, body: jsonEncode({'success': true})));
      final e = await d.lookup(realSticker);
      expect(e.ok, isTrue);
      expect(e.name, isNull);
    });

    test('an empty or whitespace name is treated as no name', () async {
      final d = dir((_) => DirectoryResponse(
          statusCode: 200,
          body: jsonEncode({'success': true, 'customer_name': '   '})));
      expect((await d.lookup(realSticker)).name, isNull);
    });
  });

  group('only the address is ever sent', () {
    test('the request body carries the VPA and nothing else', () async {
      // This is the assertion that keeps the privacy notice true. If this body
      // ever grows a field — a capture id, an amount, a device identifier —
      // the sentence the app shows about what leaves the phone is wrong, and
      // this test is what makes that impossible to do by accident.
      DirectoryRequest? sent;
      final d = dir(
        (_) => DirectoryResponse(
            statusCode: 200,
            body: jsonEncode({'success': true, 'customer_name': realName})),
        spy: (r) => sent = r,
      );

      await d.lookup(realSticker);

      final body = jsonDecode(sent!.body) as Map<String, Object?>;
      expect(body.keys.toList(), ['vpa']);
      expect(body['vpa'], realSticker);
    });

    test('the request is authenticated with basic auth over the key pair',
        () async {
      DirectoryRequest? sent;
      final d = dir(
        (_) => DirectoryResponse(
            statusCode: 200, body: jsonEncode({'success': true})),
        spy: (r) => sent = r,
      );
      await d.lookup(realSticker);

      final auth = sent!.headers['Authorization']!;
      expect(auth, startsWith('Basic '));
      expect(utf8.decode(base64Decode(auth.substring(6))), 'key-id:secret');
    });
  });

  group('every failure is a sentence, and none of them throws', () {
    test('bad keys', () async {
      final d = dir((_) => const DirectoryResponse(statusCode: 401, body: ''));
      final e = await d.lookup(realSticker);
      expect(e.ok, isFalse);
      expect(e.problem, contains('API keys'));
    });

    test('the provider is down', () async {
      final d = dir((_) => const DirectoryResponse(statusCode: 503, body: ''));
      final e = await d.lookup(realSticker);
      expect(e.ok, isFalse);
      expect(e.problem, contains('not responding'));
    });

    test('an unreadable answer', () async {
      final d = dir(
          (_) => const DirectoryResponse(statusCode: 200, body: 'not json'));
      final e = await d.lookup(realSticker);
      expect(e.ok, isFalse);
      expect(e.problem, isNotNull);
    });

    test('the transport itself throwing', () async {
      final d = RazorpayDirectory(
        keyId: 'k',
        keySecret: 's',
        send: (_) async => throw StateError('no network'),
      );
      final e = await d.lookup(realSticker);
      expect(e.ok, isFalse);
      expect(e.problem, contains('could not be made'));
    });

    test('something that is not a UPI address is refused before any call',
        () async {
      var called = false;
      final d = dir((_) {
        called = true;
        return const DirectoryResponse(statusCode: 200, body: '{}');
      });
      for (final junk in ['', '   ', 'just a string', '5912']) {
        final e = await d.lookup(junk);
        expect(e.ok, isFalse, reason: junk);
      }
      expect(called, isFalse, reason: 'nothing should have been sent');
    });
  });

  group('the disabled default', () {
    test('contacts nothing and says so', () async {
      final e = await const DisabledDirectory().lookup(realSticker);
      expect(e.ok, isFalse);
      expect(e.problem, contains('switched off'));
      expect(e.name, isNull);
    });
  });

  group('caching, which is a privacy control as much as a cost one', () {
    test('the same merchant is only ever looked up once', () async {
      // Each call tells the provider somebody looked up that VPA. Looking up
      // the same shop on every visit builds a visit history at the provider —
      // exactly what SWIP exists not to create.
      var calls = 0;
      final inner = dir((_) {
        calls++;
        return DirectoryResponse(
            statusCode: 200,
            body: jsonEncode({'success': true, 'customer_name': realName}));
      });
      final cache = CachingDirectory(inner);

      for (var i = 0; i < 5; i++) {
        final e = await cache.lookup(realSticker);
        expect(e.name, realName);
      }
      expect(calls, 1);
    });

    test('case and whitespace do not defeat the cache', () async {
      var calls = 0;
      final inner = dir((_) {
        calls++;
        return DirectoryResponse(
            statusCode: 200,
            body: jsonEncode({'success': true, 'customer_name': realName}));
      });
      final cache = CachingDirectory(inner);

      await cache.lookup(realSticker);
      await cache.lookup('  ${realSticker.toUpperCase()}  ');
      expect(calls, 1);
    });

    test('a failure is not cached, so a timeout today does not poison it',
        () async {
      var calls = 0;
      final inner = RazorpayDirectory(
        keyId: 'k',
        keySecret: 's',
        send: (_) async {
          calls++;
          if (calls == 1) throw StateError('flaky');
          return DirectoryResponse(
              statusCode: 200,
              body: jsonEncode({'success': true, 'customer_name': realName}));
        },
      );
      final cache = CachingDirectory(inner);

      expect((await cache.lookup(realSticker)).ok, isFalse);
      expect((await cache.lookup(realSticker)).name, realName);
      expect(calls, 2);
    });

    test('a seeded cache answers without any call at all', () async {
      var calls = 0;
      final inner = dir((_) {
        calls++;
        return const DirectoryResponse(statusCode: 200, body: '{}');
      });
      final cache = CachingDirectory(inner, seed: {
        realSticker: const DirectoryEntry(
            vpa: realSticker, name: realName, valid: true),
      });

      expect((await cache.lookup(realSticker)).name, realName);
      expect(calls, 0, reason: 'the merchant graph already knew this one');
    });
  });
}
