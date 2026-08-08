/// EMVCo Merchant-Presented Mode (MPM) QR parser — Capture Vector 1.
///
/// This is the cheapest and most reliable MCC in the world: for any
/// EMVCo-compliant merchant QR, the merchant category code is sitting in the
/// payload in plaintext at **root tag 52**, four numeric digits, mandatory.
/// No network, no account, no licence. It works on a plane.
///
/// Spec: EMVCo Merchant-Presented QR Specification v1.1.
/// Reference: docs/03-RESEARCH-MCC-CAPTURE.md §2.
///
/// ## Design notes
///
/// **Overlay-agnostic by design.** PIX, PromptPay, DuitNow, PayNow/SGQR,
/// BharatQR, QRIS, KHQR, QR Ph, VietQR and HKQR all sit on this format, but each
/// market layers on its own reserved ID ranges and mandatory sub-tags. A parser
/// that requires a domestic sub-tag will reject a valid foreign payload — which
/// is exactly the bug that makes most QR apps country-locked. This parser reads
/// the root TLV, takes tag 52, and never requires a domestic template.
///
/// **CRC is enforced.** A mis-scanned or tampered payload can still decode into
/// something that *looks* like a valid MCC. Showing a confidently wrong four
/// digits is worse than showing nothing, so a payload that fails CRC is
/// rejected outright rather than surfaced with low confidence.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Root tags in the EMVCo MPM payload that SWIP reads.
abstract final class EmvTag {
  static const payloadFormatIndicator = '00';
  static const pointOfInitiation = '01';

  /// Merchant Account Information templates.
  /// 02–03 Visa · 04–05 Mastercard · 06–08 EMVCo · 09–10 Discover ·
  /// 11–12 Amex · 13–14 JCB · 15–16 UnionPay · 26–51 domestic schemes.
  static const merchantAccountFirst = 2;
  static const merchantAccountLast = 51;

  /// **Merchant Category Code.** The prize. 4 numeric digits, mandatory.
  static const merchantCategoryCode = '52';

  static const transactionCurrency = '53';
  static const transactionAmount = '54';
  static const countryCode = '58';
  static const merchantName = '59';
  static const merchantCity = '60';
  static const postalCode = '61';
  static const additionalData = '62';
  static const crc = '63';
  static const languageTemplate = '64';
}

/// Sub-tags inside tag 62, Additional Data Field Template.
abstract final class EmvAdditionalTag {
  static const billNumber = '01';
  static const mobileNumber = '02';
  static const storeLabel = '03';
  static const loyaltyNumber = '04';
  static const referenceLabel = '05';
  static const customerLabel = '06';
  static const terminalLabel = '07';
  static const purposeOfTransaction = '08';
}

/// Why a parse failed. Each maps to a *distinct*, human-readable state in
/// `S-02`; none of them surfaces as the word "Error".
enum EmvQrFailure {
  /// Not TLV-shaped at all — a web URL, a wifi code, a vCard.
  notEmvQr,

  /// Structurally TLV but malformed: truncated length, non-numeric tag.
  malformed,

  /// Decoded cleanly but the CRC does not match. Possibly corrupt — refuse.
  crcMismatch,
}

@immutable
class EmvQrException implements Exception {
  const EmvQrException(this.failure, [this.detail]);
  final EmvQrFailure failure;
  final String? detail;

  @override
  String toString() => 'EmvQrException($failure${detail == null ? '' : ': $detail'})';
}

/// One decoded EMVCo merchant-presented QR.
@immutable
class EmvQrPayload {
  const EmvQrPayload({
    required this.raw,
    required this.fields,
    required this.merchantAccounts,
    required this.additionalData,
    required this.crcValid,
  });

  /// The original payload string, kept for the level-2 "Raw payload" view —
  /// this audience does not trust a number it cannot verify.
  final String raw;

  /// Root-level tag → value.
  final Map<String, String> fields;

  /// Tags 02–51: the payment-scheme templates present in this QR. The tag
  /// number identifies the scheme; the value is scheme-defined.
  final Map<String, String> merchantAccounts;

  /// Parsed sub-tags of tag 62.
  final Map<String, String> additionalData;

  final bool crcValid;

  /// **The merchant category code.** `null` when tag 52 is absent — which is
  /// legal in practice and common for personal handles, and must be presented
  /// as "this QR carries no category", never as a failure.
  String? get mcc {
    final v = fields[EmvTag.merchantCategoryCode];
    if (v == null) return null;
    final t = v.trim();
    if (t.length != 4 || int.tryParse(t) == null) return null;
    return t;
  }

  /// True when the QR encodes a category of `0000` — an explicit "unclassified",
  /// typically a personal or unregistered merchant handle. Distinct from absent.
  bool get isUnclassified => mcc == '0000';

  String? get merchantName => fields[EmvTag.merchantName]?.trim();
  String? get merchantCity => fields[EmvTag.merchantCity]?.trim();

  /// ISO 3166-1 alpha-2.
  String? get countryCode => fields[EmvTag.countryCode]?.trim().toUpperCase();

  /// ISO 4217 numeric, e.g. `356` for INR.
  String? get currencyNumeric => fields[EmvTag.transactionCurrency]?.trim();

  /// Present only on dynamic QRs — a static counter QR has no amount.
  double? get amount {
    final v = fields[EmvTag.transactionAmount];
    return v == null ? null : double.tryParse(v.trim());
  }

  /// `11` static (reusable) · `12` dynamic (single transaction).
  bool get isDynamic => fields[EmvTag.pointOfInitiation]?.trim() == '12';

  String? get storeLabel => additionalData[EmvAdditionalTag.storeLabel];
  String? get terminalLabel => additionalData[EmvAdditionalTag.terminalLabel];

  /// Best-effort scheme label from which merchant-account templates are present.
  /// Used for display only — never for deciding whether to trust the MCC.
  String get schemeHint {
    final tags = merchantAccounts.keys.map(int.parse).toSet();
    bool any(Iterable<int> r) => r.any(tags.contains);
    if (any([2, 3])) return 'Visa';
    if (any([4, 5])) return 'Mastercard';
    if (any([9, 10])) return 'Discover';
    if (any([11, 12])) return 'Amex';
    if (any([13, 14])) return 'JCB';
    if (any([15, 16])) return 'UnionPay';
    if (any(List.generate(26, (i) => i + 26))) return 'Domestic scheme';
    return 'Unknown scheme';
  }

  @override
  String toString() =>
      'EmvQrPayload(mcc: $mcc, merchant: $merchantName, country: $countryCode)';
}

/// Parses EMVCo merchant-presented QR payloads.
abstract final class EmvQrParser {
  /// Returns `true` if [input] looks like an EMVCo MPM payload.
  ///
  /// Cheap pre-check so the scanner can route a decoded string to the right
  /// parser (EMVCo TLV vs UPI intent URI vs "not a payment code") without
  /// throwing on every non-payment QR the camera happens to see.
  static bool looksLikeEmvQr(String input) {
    final s = input.trim();
    // Every conformant payload opens with tag 00, length 02, then a 2-digit
    // format version (`01` today). Matching the version loosely leaves room for
    // a future EMVCo revision without a code change.
    if (s.length < 8 || !s.startsWith('0002')) return false;
    return int.tryParse(s.substring(4, 6)) != null;
  }

  /// Parses [input], throwing [EmvQrException] on failure.
  ///
  /// Set [requireValidCrc] to `false` only in tests or diagnostics. Production
  /// paths must leave it `true`.
  static EmvQrPayload parse(String input, {bool requireValidCrc = true}) {
    final raw = input.trim();
    if (raw.length < 8) {
      throw const EmvQrException(EmvQrFailure.notEmvQr, 'too short');
    }

    final fields = _parseTlv(raw);

    if (!fields.containsKey(EmvTag.payloadFormatIndicator)) {
      throw const EmvQrException(EmvQrFailure.notEmvQr, 'no tag 00');
    }

    final crcValid = _verifyCrc(raw);
    if (requireValidCrc && !crcValid) {
      throw const EmvQrException(EmvQrFailure.crcMismatch);
    }

    // Split out the merchant-account templates (02–51).
    final accounts = <String, String>{};
    for (final entry in fields.entries) {
      final n = int.tryParse(entry.key);
      if (n != null &&
          n >= EmvTag.merchantAccountFirst &&
          n <= EmvTag.merchantAccountLast) {
        accounts[entry.key] = entry.value;
      }
    }

    final additional = fields[EmvTag.additionalData] == null
        ? <String, String>{}
        : _parseTlv(fields[EmvTag.additionalData]!);

    return EmvQrPayload(
      raw: raw,
      fields: fields,
      merchantAccounts: accounts,
      additionalData: additional,
      crcValid: crcValid,
    );
  }

  /// Non-throwing variant.
  static EmvQrPayload? tryParse(String input, {bool requireValidCrc = true}) {
    try {
      return parse(input, requireValidCrc: requireValidCrc);
    } on EmvQrException {
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────── internals

  /// Walks a TLV structure: 2-digit tag, 2-digit decimal length, then that many
  /// **bytes** of value.
  ///
  /// Deliberately byte-oriented rather than string-oriented. EMV lengths count
  /// bytes, and tag 64 (Merchant Information — Language Template) legitimately
  /// carries the merchant name in local script — Japanese, Thai, Devanagari.
  /// Indexing a Dart `String` walks UTF-16 code units, so a payload containing
  /// any multi-byte character would slice at the wrong offset and every
  /// subsequent tag — including tag 52 — would be garbage. That failure would
  /// appear only outside ASCII markets, which is precisely where the "works on
  /// any QR on earth" promise has to hold.
  static Map<String, String> _parseTlv(String s) => _parseTlvBytes(utf8.encode(s));

  static Map<String, String> _parseTlvBytes(List<int> bytes) {
    final out = <String, String>{};
    var i = 0;

    int? twoDigits(int at) {
      final a = bytes[at] - 0x30;
      final b = bytes[at + 1] - 0x30;
      if (a < 0 || a > 9 || b < 0 || b > 9) return null;
      return a * 10 + b;
    }

    while (i + 4 <= bytes.length) {
      if (twoDigits(i) == null) {
        throw EmvQrException(EmvQrFailure.malformed, 'bad tag at offset $i');
      }
      final tag = String.fromCharCodes(bytes, i, i + 2);
      final len = twoDigits(i + 2);
      if (len == null) {
        throw EmvQrException(EmvQrFailure.malformed, 'bad length at offset $i');
      }

      final start = i + 4;
      final end = start + len;
      if (end > bytes.length) {
        throw EmvQrException(
            EmvQrFailure.malformed, 'length $len overruns payload at offset $i');
      }

      // Duplicate root tags are not conformant; first occurrence wins so a
      // crafted payload cannot override a legitimate MCC by appending one.
      out.putIfAbsent(
        tag,
        // allowMalformed: a single bad byte in a merchant name must not cost us
        // the whole payload — and therefore the category.
        () => utf8.decode(bytes.sublist(start, end), allowMalformed: true),
      );
      i = end;
    }
    return out;
  }

  /// CRC-16/CCITT-FALSE — poly 0x1021, init 0xFFFF, no reflection, no final XOR.
  ///
  /// Per spec the checksum is computed over the payload **including** the CRC
  /// tag and length (`6304`) but excluding the four hex digits of the checksum
  /// itself.
  static bool _verifyCrc(String payload) {
    final idx = payload.lastIndexOf('6304');
    // Must be exactly 4 checksum characters at the very end.
    if (idx < 0 || idx + 8 != payload.length) return false;

    final expected = payload.substring(idx + 4).toUpperCase();
    final actual = crc16ccitt(payload.substring(0, idx + 4))
        .toRadixString(16)
        .toUpperCase()
        .padLeft(4, '0');
    return expected == actual;
  }

  /// CRC-16/CCITT-FALSE over the UTF-8 bytes of [input]. Exposed for tests and
  /// for generating payloads in the QR fixtures.
  ///
  /// UTF-8, not `codeUnits`: tag 64 (Merchant Information — Language Template)
  /// legitimately carries the merchant name in local script, and for anything
  /// outside ASCII the UTF-16 code units differ from the bytes the QR actually
  /// encodes. Using `codeUnits` would fail CRC on exactly the payloads that
  /// matter most for the "works in every country" promise.
  @visibleForTesting
  static int crc16ccitt(String input) {
    var crc = 0xFFFF;
    for (final byte in utf8.encode(input)) {
      crc ^= (byte & 0xFF) << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
        crc &= 0xFFFF;
      }
    }
    return crc;
  }
}
