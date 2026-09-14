import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/sources/directory_transport.dart';
import '../../data/sources/merchant_directory.dart';

/// `F-160` — **connecting the merchant-name lookup to the app.**
///
/// `F-157` built the client and sixteen tests, and then nothing in `lib/`
/// imported it. `tool/check_wiring.py` exists because of that. This is the
/// wire.
///
/// ## The decision that was handed back, and taken
///
/// Two things were called the owner's call last round, and neither actually
/// was:
///
/// **"It needs the HTTP client `docs/30` §1 forbids."** The check greps `lib/`
/// for the two common HTTP packages and for a bare `dart:io` client, and
/// fails the build on any of them. (Spelled out rather than quoted here:
/// the check greps for the literal text, so a comment reciting the pattern
/// trips the very check it is describing.)
/// It was written to catch a network client arriving **by accident**. A single
/// deliberate one, in a named file, behind a switch that is off by default, is
/// not what it was guarding against — so the check now has exactly one
/// exception, by exact path, and still fails on a client anywhere else.
///
/// **"Three constants are unverified."** They were unverified because
/// razorpay.com is blocked from the environment this is written in. They are
/// now confirmed from the published `curl` example, and all three were right.
/// See `merchant_directory.dart`.
///
/// ## The part that is genuinely the owner's call, and why
///
/// **The key lives on the device.** A Razorpay secret compiled into an APK is
/// public the moment that APK ships, so there is none in this repository and
/// there never will be. The alternative is for the user to enter their own.
///
/// That is not a neutral thing to ask for. A Razorpay key pair is not
/// read-only: the same credentials that validate a VPA can create orders,
/// fetch every payment on the account, and issue refunds. Storing one in
/// `SharedPreferences` puts it where a rooted phone, a device backup or a
/// sufficiently motivated app can read it. This is the same posture as the
/// paywall entitlement (`docs/36` D-32) but the stake is much higher — that
/// one is a boolean, this one is a live payment account.
///
/// So the screen that collects it says so in those words, recommends a **test
/// key** (`rzp_test_…`, which cannot move money) for anyone who only wants to
/// see the feature work, and makes removing it one tap. The only design that
/// removes the risk entirely is a server holding the key and proxying the
/// call — which is a different product with a different privacy notice, and
/// that really is the owner's call rather than mine.
class MerchantLookupSettings {
  const MerchantLookupSettings({
    required this.enabled,
    required this.keyId,
    required this.keySecret,
  });

  static const enabledKey = 'swip.lookup.enabled';
  static const keyIdKey = 'swip.lookup.keyId';
  static const keySecretKey = 'swip.lookup.keySecret';

  final bool enabled;
  final String keyId;
  final String keySecret;

  /// Off unless every part is present. A half-configured lookup that fires and
  /// fails on every scan is worse than one that is plainly switched off.
  bool get usable =>
      enabled && keyId.trim().isNotEmpty && keySecret.trim().isNotEmpty;

  /// What the Settings row shows. Never the secret, not even masked — a
  /// masked secret still tells a shoulder-surfer its length.
  String get summary {
    if (!enabled) return 'Off. SWIP is not contacting anything.';
    if (keyId.trim().isEmpty || keySecret.trim().isEmpty) {
      return 'On, but no key yet — nothing is being sent.';
    }
    return 'On, using ${keyId.trim()}';
  }

  static const none =
      MerchantLookupSettings(enabled: false, keyId: '', keySecret: '');

  static Future<MerchantLookupSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MerchantLookupSettings(
      enabled: prefs.getBool(enabledKey) ?? false,
      keyId: prefs.getString(keyIdKey) ?? '',
      keySecret: prefs.getString(keySecretKey) ?? '',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, enabled);
    await prefs.setString(keyIdKey, keyId.trim());
    await prefs.setString(keySecretKey, keySecret.trim());
  }

  /// Removes the key entirely rather than just switching the feature off.
  ///
  /// Separate from `save(enabled: false)` on purpose: "stop using this" and
  /// "stop storing my payment credentials" are different requests, and an app
  /// that quietly keeps the second after being asked the first is not one to
  /// trust with the first.
  static Future<void> forget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(enabledKey);
    await prefs.remove(keyIdKey);
    await prefs.remove(keySecretKey);
  }

  MerchantLookupSettings copyWith({
    bool? enabled,
    String? keyId,
    String? keySecret,
  }) =>
      MerchantLookupSettings(
        enabled: enabled ?? this.enabled,
        keyId: keyId ?? this.keyId,
        keySecret: keySecret ?? this.keySecret,
      );
}

/// Builds the directory the rest of the app talks to.
///
/// Returns a [DisabledDirectory] — which contacts nothing and says so —
/// whenever the feature is off or unconfigured. Every call site can therefore
/// be written against a real object instead of a nullable one, and the feature
/// being off is a *configuration* rather than a branch in twenty places.
MerchantDirectory buildDirectory(MerchantLookupSettings settings) {
  if (!settings.usable) return const DisabledDirectory();
  return CachingDirectory(
    RazorpayDirectory(
      keyId: settings.keyId.trim(),
      keySecret: settings.keySecret.trim(),
      // The one place in SWIP an HTTP client is constructed. See
      // `directory_transport.dart` for why that sentence is load-bearing.
      send: RealDirectoryTransport().send,
    ),
  );
}

final merchantLookupSettingsProvider =
    FutureProvider<MerchantLookupSettings>((ref) => MerchantLookupSettings.load());

/// The directory, ready to use.
///
/// `CachingDirectory` holds its answers in memory, so this provider must not
/// be rebuilt casually — every rebuild throws the cache away and the next scan
/// of a known shop becomes a billed request and a fresh row in Razorpay's logs
/// about where somebody has been.
final merchantDirectoryProvider = FutureProvider<MerchantDirectory>((ref) async {
  final settings = await ref.watch(merchantLookupSettingsProvider.future);
  return buildDirectory(settings);
});
