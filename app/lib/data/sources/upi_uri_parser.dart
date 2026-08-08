/// UPI intent URI parser — the *other* Indian QR format.
///
/// This is the most commonly missed case in QR apps and the reason many of them
/// silently fail on Indian merchant codes. India has **two** QR formats in the
/// field:
///
///   1. **BharatQR** — EMVCo MPM TLV. MCC at tag 52. See [EmvQrParser].
///   2. **UPI intent URI** — not TLV at all. A URI whose `mc` query parameter
///      is the four-digit merchant category code.
///
/// A very large share of Indian merchant QRs are the URI form. NPCI defines
/// `mc` as the MCC used for merchant MIS, statistics and business reports.
///
/// Reference: NPCI UPI Linking Specification 1.6; docs/03-RESEARCH §2.2.
library;

import 'package:flutter/foundation.dart';

/// A decoded `upi://pay?…` intent.
@immutable
class UpiIntent {
  const UpiIntent({required this.raw, required this.params});

  final String raw;
  final Map<String, String> params;

  /// Payee VPA, e.g. `merchant@okhdfcbank`. This doubles as the merchant key
  /// for the merchant graph when no MCC is present.
  String? get payeeAddress => _clean(params['pa']);

  String? get payeeName => _clean(params['pn']);

  /// **The merchant category code**, from `mc`.
  ///
  /// Returns `null` when absent or not four digits. `0000` is returned as-is —
  /// it is meaningful ("unclassified / personal handle"), not missing, and the
  /// UI must say so rather than showing an error.
  String? get mcc {
    final v = _clean(params['mc']);
    if (v == null || v.length != 4 || int.tryParse(v) == null) return null;
    return v;
  }

  bool get isUnclassified => mcc == '0000';

  /// A `mc` that is present but malformed — worth surfacing separately, because
  /// it means the merchant's PSP generated a non-conformant QR.
  bool get hasMalformedMcc {
    final v = _clean(params['mc']);
    return v != null && mcc == null;
  }

  String? get transactionId => _clean(params['tid']);
  String? get transactionRef => _clean(params['tr']);
  String? get transactionNote => _clean(params['tn']);

  /// Present only on dynamic QRs.
  double? get amount {
    final v = _clean(params['am']);
    return v == null ? null : double.tryParse(v);
  }

  /// ISO 4217 alpha, normally `INR`.
  String? get currency => _clean(params['cu'])?.toUpperCase();

  /// Merchants sign their QRs; consumers' P2P codes are unsigned. A signed QR
  /// is a decent secondary signal that the payee really is a registered
  /// merchant, which matters when `mc` is `0000`.
  bool get isSigned => _clean(params['sign']) != null;

  static String? _clean(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  @override
  String toString() => 'UpiIntent(pa: $payeeAddress, mc: $mcc)';
}

abstract final class UpiUriParser {
  /// Schemes seen in the wild. `upi://pay` dominates; issuer-specific schemes
  /// appear on some bank-generated codes and carry the same parameters.
  static const _schemes = {
    'upi',
    'upiapp',
    'bhim',
    'gpay',
    'phonepe',
    'paytmmp',
  };

  static bool looksLikeUpiUri(String input) {
    final s = input.trim().toLowerCase();
    return _schemes.any((sc) => s.startsWith('$sc://'));
  }

  /// Parses a UPI intent URI. Returns `null` if [input] is not one.
  ///
  /// Hand-rolled rather than `Uri.parse` + `queryParameters` because real-world
  /// UPI QRs are frequently non-conformant: unencoded spaces and `&` inside
  /// `pn`, empty values, and duplicated keys. `Uri.parse` throws or silently
  /// drops parameters on those, and losing `mc` to a malformed `pn` earlier in
  /// the string is a bug the user would never be able to diagnose.
  static UpiIntent? tryParse(String input) {
    final raw = input.trim();
    if (!looksLikeUpiUri(raw)) return null;

    final q = raw.indexOf('?');
    if (q < 0 || q + 1 >= raw.length) {
      return UpiIntent(raw: raw, params: const {});
    }

    final params = <String, String>{};
    for (final pair in raw.substring(q + 1).split('&')) {
      if (pair.isEmpty) continue;
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final key = pair.substring(0, eq).trim().toLowerCase();
      final value = pair.substring(eq + 1);
      // First occurrence wins, so a duplicated `mc` appended to a payload
      // cannot override the legitimate one.
      params.putIfAbsent(key, () => _decode(value));
    }

    return UpiIntent(raw: raw, params: params);
  }

  /// Percent-decoding that tolerates the malformed escapes real QRs contain —
  /// a stray `%` in a merchant name must not lose us the whole payload.
  static String _decode(String s) {
    try {
      return Uri.decodeComponent(s.replaceAll('+', ' '));
    } on ArgumentError {
      return s;
    }
  }
}
