import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swip/data/sources/merchant_directory.dart';
import 'package:swip/features/lookup/merchant_lookup.dart';

/// `F-160` — the wire between the lookup client and the app.
///
/// `F-157` built a correct, well-tested client that nothing imported. These
/// tests are about the part that was missing: whether the app can actually get
/// to it, and — more importantly — whether it can be got to **by accident**.
///
/// The whole security posture of this feature is "off unless deliberately
/// configured". Every test below is a way that could quietly stop being true.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('off by default, and off is really off', () {
    test('a fresh install contacts nothing', () async {
      final s = await MerchantLookupSettings.load();
      expect(s.enabled, isFalse);
      expect(s.usable, isFalse);
      expect(buildDirectory(s), isA<DisabledDirectory>());
    });

    test('the disabled directory is not merely a no-op, it says so', () async {
      final d = buildDirectory(MerchantLookupSettings.none);
      final e = await d.lookup('paytm.s1jii6k@pty');
      expect(e.ok, isFalse);
      expect(e.problem, contains('switched off'));
      expect(e.name, isNull);
    });
  });

  group('switched on but not configured is still off', () {
    // The dangerous middle state. A user who flips the switch, does not paste
    // a key, and walks away must not end up with something that fires a
    // request on every scan and fails — that is cost, noise, and a privacy
    // notice that has become untrue for no benefit whatsoever.
    test('enabled with no key at all', () {
      const s = MerchantLookupSettings(enabled: true, keyId: '', keySecret: '');
      expect(s.usable, isFalse);
      expect(buildDirectory(s), isA<DisabledDirectory>());
    });

    test('enabled with a key id but no secret', () {
      const s = MerchantLookupSettings(
          enabled: true, keyId: 'rzp_test_x', keySecret: '');
      expect(s.usable, isFalse);
      expect(buildDirectory(s), isA<DisabledDirectory>());
    });

    test('whitespace is not a key', () {
      const s = MerchantLookupSettings(
          enabled: true, keyId: '   ', keySecret: '   ');
      expect(s.usable, isFalse);
      expect(buildDirectory(s), isA<DisabledDirectory>());
    });

    test('a key with the switch off does not enable it', () {
      const s = MerchantLookupSettings(
          enabled: false, keyId: 'rzp_test_x', keySecret: 'shh');
      expect(s.usable, isFalse);
      expect(buildDirectory(s), isA<DisabledDirectory>());
    });
  });

  group('fully configured', () {
    test('builds a real, caching directory', () {
      const s = MerchantLookupSettings(
          enabled: true, keyId: 'rzp_test_x', keySecret: 'shh');
      expect(s.usable, isTrue);
      // Caching rather than bare: each call tells the provider somebody looked
      // up that address, so looking the same shop up on every visit would
      // build a visit history at the provider. That is the thing SWIP exists
      // not to create, and it is a property of this factory, not of a call
      // site somebody might forget.
      expect(buildDirectory(s), isA<CachingDirectory>());
    });
  });

  group('what the settings row is allowed to say', () {
    test('never the secret', () {
      const s = MerchantLookupSettings(
          enabled: true, keyId: 'rzp_test_abc', keySecret: 'super-secret');
      expect(s.summary, isNot(contains('super-secret')));
      expect(s.summary, contains('rzp_test_abc'));
    });

    test('off says nothing is being contacted', () {
      expect(MerchantLookupSettings.none.summary, contains('not contacting'));
    });

    test('on-but-unconfigured admits nothing is being sent', () {
      const s = MerchantLookupSettings(enabled: true, keyId: '', keySecret: '');
      expect(s.summary, contains('nothing is being sent'));
    });
  });

  group('storage', () {
    test('a saved key comes back', () async {
      await const MerchantLookupSettings(
              enabled: true, keyId: 'rzp_test_x', keySecret: 'shh')
          .save();
      final s = await MerchantLookupSettings.load();
      expect(s.enabled, isTrue);
      expect(s.keyId, 'rzp_test_x');
      expect(s.keySecret, 'shh');
    });

    test('surrounding whitespace is trimmed on the way in', () async {
      // Pasting a key from a dashboard picks up a trailing newline more often
      // than not, and a key with a newline on the end fails authentication
      // with a message that blames the key.
      await const MerchantLookupSettings(
              enabled: true, keyId: '  rzp_test_x \n', keySecret: ' shh ')
          .save();
      final s = await MerchantLookupSettings.load();
      expect(s.keyId, 'rzp_test_x');
      expect(s.keySecret, 'shh');
    });

    test('forget removes the credentials, not just the switch', () async {
      // "Stop using this" and "stop storing my payment credentials" are
      // different requests. An app that quietly keeps the second after being
      // asked the first is not one to trust with the first.
      await const MerchantLookupSettings(
              enabled: true, keyId: 'rzp_test_x', keySecret: 'shh')
          .save();
      await MerchantLookupSettings.forget();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MerchantLookupSettings.keyIdKey), isNull);
      expect(prefs.getString(MerchantLookupSettings.keySecretKey), isNull);
      expect(prefs.getBool(MerchantLookupSettings.enabledKey), isNull);

      final s = await MerchantLookupSettings.load();
      expect(s.usable, isFalse);
    });
  });
}
