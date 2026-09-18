import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/models/capture_event.dart';
import '../../data/sources/upi_uri_parser.dart';

/// `F-194` — **carrying a scanned code on to the app that will actually pay
/// it.**
///
/// > *"whenever I scan this QR code … I could also have continued payment in
/// > this pop-up which I get for the MCC. I could continue this payment in one
/// > of the apps, right? I don't have to close this dropdown, this modal, and
/// > then go to the payment app and again scan"* — prompt 54
///
/// ## What this is not
///
/// It is not a payment. SWIP renders no amount field, holds no funds, sees no
/// PIN and is not a PSP — the same sentence `docs/18` has carried since vector
/// 7 was built. What it does is hand a `upi://` string to another application
/// and get out of the way, which is an `Intent`, and an intent is not a
/// financial instrument.
///
/// That distinction is the whole reason this can ship this week. Every other
/// route to a category in [`docs/49`](../../../docs/49-EVERY-ROUTE-TO-AN-MCC.md)
/// needs a licence, a sponsor bank or a net worth requirement. This one needs
/// a manifest entry.
///
/// ## The rule that matters: forward the payload, do not rebuild it
///
/// The obvious implementation reads `pa` and `pn` out of the scanned code and
/// composes a fresh `upi://pay?pa=…&pn=…`. **That is wrong, and quietly so.**
///
/// A merchant QR minted by an onboarding flow carries more than an address.
/// `docs/42` §4 decoded the parts: `mode=02`, `orgid`, `mc`, `tr`, and a
/// `sign=` block which is a raw DER ECDSA signature **over the rest of the
/// payload**. Rebuilding the URI from two fields throws all of that away. At
/// best the receiving app loses the merchant's verified status and treats a
/// shop as a person; at worst the signature no longer matches what it signs
/// and the code is rejected outright.
///
/// **So the raw payload is forwarded byte for byte whenever there is one**,
/// and composition is a fallback for the case where SWIP holds an address and
/// no original string. Nothing is added, nothing is reordered, nothing is
/// re-encoded. `payUriFor` below is mostly a function that declines to do
/// anything.
///
/// ## Why the amount is deliberately absent
///
/// > *"For now, let them first get redirected to the list of payment sheet
/// > apps available in their system … select the application from this list of
/// > apps, and then put their amount into that chosen app."*
///
/// UPI's `am` parameter would prefill it, and [compose] takes one so the day
/// that changes is one argument rather than a rewrite. It is not passed today
/// because the owner asked for it not to be, and because an amount SWIP
/// guessed would be an amount somebody pays.
@immutable
class UpiHandoff {
  const UpiHandoff._();

  /// The string to hand on for [event], or null if this capture cannot be
  /// paid.
  ///
  /// Null is the correct and common answer. **A POS tap has no payable
  /// address at all** — `docs/47` decoded a complete EMV exchange in which
  /// every merchant-identity field came back as zeros, and even a terminal
  /// that filled them in would give a merchant id, not a VPA. Cards are paid
  /// by tapping the card; there is no URI to send anywhere. The button that
  /// reads this therefore does not render on a tap, rather than rendering and
  /// failing.
  static String? payUriFor(CaptureEvent event) {
    final raw = event.rawPayload?.trim();
    if (raw != null && raw.isNotEmpty && isPayable(raw)) return raw;

    // No original string. Compose from the address if there is one — this is
    // the path a back-filled or imported row takes.
    final key = event.merchantKey?.trim();
    if (key == null || !_looksLikeVpa(key)) return null;
    return compose(payeeAddress: key, payeeName: event.merchantName);
  }

  /// Whether [payload] is something a UPI app will accept.
  ///
  /// Deliberately narrow. SWIP scans arbitrary QR codes — a Wi-Fi join, a
  /// URL, a parcel tracking number — and handing one of those to a chooser
  /// produces either nothing or the wrong app. It must start with a UPI
  /// scheme **and** carry a payee address, because `upi://pay` with no `pa` is
  /// a screen asking the user to type one, which is the rescanning this whole
  /// feature exists to remove.
  static bool isPayable(String payload) {
    final parsed = UpiUriParser.tryParse(payload);
    if (parsed == null) return false;
    final pa = parsed.payeeAddress;
    return pa != null && _looksLikeVpa(pa);
  }

  /// Build a `upi://pay` string from parts. The fallback path, and the future
  /// home of a prefilled [amount].
  ///
  /// `cu=INR` is included because NPCI's URI spec lists currency as required
  /// and several apps show a currency picker without it. Everything else is
  /// omitted rather than guessed.
  static String compose({
    required String payeeAddress,
    String? payeeName,
    String? amount,
  }) {
    final q = <String, String>{
      'pa': payeeAddress,
      if (payeeName != null && payeeName.trim().isNotEmpty)
        'pn': payeeName.trim(),
      'cu': 'INR',
      if (amount != null && amount.trim().isNotEmpty) 'am': amount.trim(),
    };
    final encoded = q.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return 'upi://pay?$encoded';
  }

  /// `something@handle`, loosely. One `@`, non-empty on both sides, no spaces,
  /// **and no colon.**
  ///
  /// Loose on the handle, on purpose: `docs/42` catalogued fifty handles across
  /// six PSPs and `F-182` still found a hole in the middle of one family. A
  /// validator that knows the list of handles would reject the fifty-first, and
  /// the cost of being wrong that way is one extra chooser, where the cost of
  /// being strict is a shop nobody can pay.
  ///
  /// **The colon is not loose, and it is the interesting rule.** A merchant key
  /// in the ledger can carry a scheme prefix — `upi:WFMLMH2@ybl` is a real one,
  /// from `capture_result_sheet_test.dart`'s own fixture — and that string has
  /// exactly one `@` with text either side, so every other check here passes
  /// it. Composing from it would produce `pa=upi%3AWFMLMH2%40ybl`, which is
  /// not an address any PSP can resolve: a payment app opening on a payee it
  /// cannot find, at a counter.
  ///
  /// A VPA never contains a colon. Found by two existing tests failing on the
  /// button emphasis rather than on the address — which is `CLAUDE.md`'s
  /// *grep for the assertion, not the test name* arriving from the other
  /// direction: a test named for one thing catching a different, worse one.
  static bool _looksLikeVpa(String s) {
    final at = s.indexOf('@');
    if (at <= 0 || at != s.lastIndexOf('@') || at == s.length - 1) return false;
    if (s.contains(':')) return false;
    return !s.contains(' ') && !s.contains('\n');
  }
}

/// One UPI app on this phone, as the platform reported it.
@immutable
class UpiApp {
  const UpiApp({required this.package, required this.label, this.icon});

  final String package;
  final String label;

  /// A PNG, already decoded from the base64 the channel carries. Null when the
  /// platform could not load one, which renders a monogram rather than a gap.
  final Uint8List? icon;

  @override
  bool operator ==(Object other) =>
      other is UpiApp && other.package == package && other.label == label;

  @override
  int get hashCode => Object.hash(package, label);
}

/// Reads the phone's UPI apps and launches one.
///
/// ## Why SWIP draws this list instead of calling `Intent.createChooser`
///
/// The system chooser needs no `<queries>` entry and is one line of Kotlin, so
/// it is the cheaper answer and it is still the fallback here. It is not the
/// default for two reasons.
///
/// The first is the owner's, and it is a real one: *"it gives an option of a
/// list of apps which can make payment to this giver"* — a list belonging to
/// SWIP, in SWIP's sheet, continuing the card the user is already reading,
/// rather than a system surface that looks like the app has ended.
///
/// The second is that a chooser cannot be reasoned about. It shows what
/// Android decides to show, in Android's order, with Android's "just once /
/// always" memory — and an "always" answer given once makes every future
/// hand-off silent, which is indistinguishable from the button being broken.
///
/// ## `<queries>`, and the permission this deliberately does not ask for
///
/// Listing other apps on Android 11+ needs package visibility. There are two
/// ways and only one of them is allowed here:
///
///   * `QUERY_ALL_PACKAGES` — the whole installed-app inventory. Google Play
///     treats it as a **restricted permission**, permitted only when broad
///     visibility *is* the app's core purpose. SWIP's is a shop's category.
///     This is the same shape as the Doze exemption `docs/36` D-45 declined,
///     and it is declined for the same reason: a permission that invites a
///     policy rejection is not worth a nicer list.
///   * A `<queries>` **intent signature** — "show me who can VIEW a `upi:`
///     URI", and nothing else. No permission, no review, no inventory. That
///     is what `AndroidManifest.xml` declares.
///
/// The consequence is worth stating plainly: this list can only ever contain
/// apps that have told Android they can take a UPI payment. It cannot see
/// anything else, which is exactly the property that makes it shippable.
class UpiApps {
  const UpiApps._();

  static const _channel = MethodChannel('in.swip.app/nfc');

  /// Every installed app that can handle a `upi://pay`, SWIP excluded.
  ///
  /// Empty is a normal answer — a phone with no UPI app, or an emulator — and
  /// callers fall back to the system chooser rather than showing an empty
  /// sheet.
  ///
  /// `.timeout()` on every platform read, per `CLAUDE.md`: a `MethodChannel`
  /// future completes when the platform replies and **never completes if it
  /// does not**, and in a widget test there is no engine at all. A sheet that
  /// spins forever because nobody mocked a channel is the `F-158` symptom.
  static Future<List<UpiApp>> list() async {
    try {
      final raw = await _channel
          .invokeListMethod<Map<Object?, Object?>>('upiApps')
          .timeout(const Duration(seconds: 3));
      if (raw == null) return const [];
      return raw
          .map((m) {
            final package = m['package'] as String?;
            final label = m['label'] as String?;
            if (package == null || label == null) return null;
            final icon = m['icon'] as Uint8List?;
            return UpiApp(package: package, label: label, icon: icon);
          })
          .whereType<UpiApp>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Open [uri] in [package]. False if that app could not be started, which
  /// the caller turns into the system chooser rather than into silence.
  static Future<bool> payWith(String package, String uri) async {
    try {
      final ok = await _channel
          .invokeMethod<bool>('payWithApp', {'package': package, 'uri': uri})
          .timeout(const Duration(seconds: 5));
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// The fallback: let Android pick. Already built for vector 7 and reused
  /// here rather than duplicated — see `IntentCapture.forward`.
  static Future<bool> systemChooser(String uri) async {
    try {
      final ok = await _channel
          .invokeMethod<bool>('forwardUpiIntent', {'uri': uri})
          .timeout(const Duration(seconds: 5));
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
