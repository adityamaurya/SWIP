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

/// `F-123`. **Whether a category was published, and if not, in what way.**
///
/// The old code had a boolean's worth of thinking in it: `mcc` was either a
/// string or `null`. That collapsed five genuinely different situations into
/// one, and threw away the most diagnostic payload in the whole corpus.
///
/// The Shree Beauty Centre QR, decoded from the photograph, is exactly this:
///
/// ```
/// upi://pay?pa=SVCMERC00306934@svcbank&pn=SVCMERC00306934&mc=&tr=00306934…
/// ```
///
/// `mc=` — **present and empty**. A bank built a merchant QR and left the
/// category field blank. That is not the same as a sticker that never had the
/// field, and it is not the same as a small merchant who cannot have one. It is
/// an acquirer's omission, it is the merchant's bank's fault, and it is fixable
/// — which is worth saying out loud rather than flattening into "unknown".
enum MccPublication {
  /// Four digits, non-zero. The prize.
  published,

  /// `mc=0000`. Deliberately unclassified. A real value, not a gap.
  unclassified,

  /// `mc=` with nothing after it. The field exists and was left blank.
  blank,

  /// `mc=59`, `mc=abcd`. The PSP generated a non-conformant QR.
  malformed,

  /// No `mc` parameter at all. The common case for static stickers.
  absent,
}

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
  /// Returns `null` unless four digits were actually published. `0000` is
  /// returned as-is — it is meaningful ("unclassified"), not missing.
  /// For *why* it is null, read [mccPublication]; the difference between an
  /// absent field and a blank one is the difference between "this sticker never
  /// carried a category" and "their bank forgot to fill it in".
  String? get mcc {
    final v = _clean(params['mc']);
    if (v == null || v.length != 4 || int.tryParse(v) == null) return null;
    return v;
  }

  /// How the `mc` field was published — see [MccPublication].
  MccPublication get mccPublication {
    if (!params.containsKey('mc')) return MccPublication.absent;
    final rawValue = params['mc']!.trim();
    if (rawValue.isEmpty) return MccPublication.blank;
    if (rawValue.length != 4 || int.tryParse(rawValue) == null) {
      return MccPublication.malformed;
    }
    return rawValue == '0000'
        ? MccPublication.unclassified
        : MccPublication.published;
  }

  bool get isUnclassified => mccPublication == MccPublication.unclassified;

  /// A `mc` that is present but malformed — worth surfacing separately, because
  /// it means the merchant's PSP generated a non-conformant QR.
  bool get hasMalformedMcc => mccPublication == MccPublication.malformed;

  /// `mc=` written out and left empty. The acquirer's omission.
  bool get hasBlankMcc => mccPublication == MccPublication.blank;

  // ── The signals that are not the category, but say a great deal ──────────
  //
  // `F-123`. Every one of these was already in the payloads SWIP was reading
  // and none of them was being looked at. Together they are most of what a
  // licensed PSP knows about a merchant from the QR alone.

  /// NPCI `mode`. `01` static, `02` static-with-signature, `15` dynamic.
  /// Its mere presence marks a QR minted by a merchant-onboarding flow rather
  /// than typed by a person.
  String? get mode => _clean(params['mode']);

  /// The PSP's NPCI organisation id.
  String? get orgId => _clean(params['orgid']);

  /// Merchant ID, where the PSP writes one.
  String? get merchantId => _clean(params['mid']);

  /// Terminal / store identifiers on dynamic QRs.
  String? get terminalId => _clean(params['tid']) ?? _clean(params['qrts']);

  /// `tr` carries the acquirer's own prefix on dynamic QRs — `PINE…` for a Pine
  /// Labs terminal, for instance. Not a category, but it names the rail.
  String? get acquirerHint {
    final tr = _clean(params['tr']);
    if (tr == null) return null;
    final m = RegExp(r'^([A-Za-z]{3,10})').firstMatch(tr);
    return m?.group(1)?.toUpperCase();
  }

  /// A dynamic QR: minted per transaction by a terminal, and by far the most
  /// likely UPI payload to carry a real `mc`.
  bool get isDynamic => mode == '15' || amount != null;

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
