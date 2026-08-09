import '../models/capture_event.dart';
import 'emv_qr_parser.dart';
import 'merchant_identity.dart';
import 'upi_uri_parser.dart';

/// One entry point for every string SWIP can be handed.
///
/// Ideation: *"country agnostic — no matter what QR, no matter what merchant,
/// it must give me the MCC."* This is where that promise is kept, and where it
/// is kept **honestly**: SWIP always returns an answer, and the answer always
/// carries how much to trust it.
///
/// Resolution order matters. UPI is checked before EMVCo because an Indian
/// merchant QR is frequently *both* — a `upi://` intent whose payload also
/// validates as EMVCo — and the UPI `mc` parameter is the more reliable of the
/// two in practice.
///
///  1. **UPI intent** (`upi:`, `paytmmp:`, `phonepe:`, `gpay:` …) → `mc`
///  2. **EMVCo MPM** — the international standard behind BharatQR, PIX (BR),
///     QRIS (ID), PayNow (SG), PromptPay (TH), NETS (SG), DuitNow (MY),
///     VietQR (VN), Alipay/WeChat merchant-presented codes and 30+ national
///     schemes → tag `52`
///  3. **Payment link** (Razorpay, Stripe, PayPal, Cashfree, Paytm …) → the
///     PSP is identified and the merchant slug becomes a graph key
///  4. **Anything else** → recorded as unknown, with the raw payload kept
///
/// Steps 1–2 *read* the category out of the payload. Step 3 can only *infer*
/// it. Step 4 admits it does not know. A capture that says "Unknown" is a
/// correct capture — guessing in grey and hoping is the one thing this app
/// must never do.
abstract final class CaptureResolver {
  static ResolvedCapture resolve(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return const ResolvedCapture(
        vector: CaptureVector.qr,
        kind: CaptureKind.unrecognised,
        sourceLabel: 'Empty code',
      );
    }

    // 1 ── UPI and the wallet schemes that wrap it.
    if (UpiUriParser.looksLikeUpiUri(raw)) {
      final upi = UpiUriParser.tryParse(raw);
      if (upi != null) {
        final vpa = upi.payeeAddress;

        // `F-42`. The handle, not `pn`, is the reliable identity. A Paytm shop
        // sticker says `pn=Paytm`, which is the payment company rather than the
        // shop — showing it as the merchant put "Paytm" on five ledger rows
        // that were five different shops.
        final identity = vpa == null
            ? null
            : MerchantIdentifier.of(
                vpa,
                payeeName: upi.payeeName,
                signed: upi.isSigned,
                mode: upi.params['mode'],
              );

        return ResolvedCapture(
          vector: CaptureVector.qr,
          kind: CaptureKind.upi,
          mcc: upi.mcc,
          merchantName: identity?.displayName ??
              (vpa == null ? upi.payeeName : null),
          merchantHandle: vpa?.toLowerCase(),
          payeeKind: identity?.kind ?? PayeeKind.undetermined,
          acquirer: identity?.psp,
          merchantKey: vpa == null ? null : 'upi:${vpa.toLowerCase()}',
          amount: upi.amount,
          currency: upi.currency ?? 'INR',
          countryCode: 'IN',
          rawPayload: raw,
          sourceLabel: identity?.psp == null
              ? 'UPI QR'
              : 'UPI QR · ${identity!.psp}',
        );
      }
    }

    // 2 ── EMVCo merchant-presented QR. The global case.
    if (EmvQrParser.looksLikeEmvQr(raw)) {
      // CRC is enforced first. A payload that fails its own checksum is
      // corrupt, and a corrupt payload's tag 52 is not a category — it is
      // noise that happens to be four digits long.
      final emv = EmvQrParser.tryParse(raw);
      if (emv != null) {
        return ResolvedCapture(
          vector: CaptureVector.qr,
          kind: CaptureKind.emvco,
          mcc: emv.mcc,
          // Tag 59 is free text the QR printer fills in, and PSP-printed
          // BharatQR stickers carry the same placeholders as UPI's `pn`.
          merchantName: MerchantIdentifier.isGenericName(emv.merchantName)
              ? null
              : emv.merchantName,
          merchantCity: emv.merchantCity,
          countryCode: emv.countryCode,
          merchantKey: _emvMerchantKey(emv),
          amount: emv.amount,
          currency: emv.currencyNumeric == null
              ? null
              : _currencyFromNumeric(emv.currencyNumeric!),
          terminalId: emv.terminalLabel,
          rawPayload: raw,
          sourceLabel: emv.schemeHint,
        );
      }

      // Reached only when the CRC failed. Say so rather than silently
      // dropping to "unrecognised" — a damaged print or a bad camera read is
      // a different problem from an unknown format, and the fix differs too.
      return ResolvedCapture(
        vector: CaptureVector.qr,
        kind: CaptureKind.corrupt,
        rawPayload: raw,
        sourceLabel: 'Damaged QR — checksum failed',
      );
    }

    // 3 ── A payment link.
    final link = PaymentLinkInference.match(raw);
    if (link != null) return link;

    // 4 ── Unrecognised. Still a row: the user pointed SWIP at something and
    // deserves to see that it was seen.
    return ResolvedCapture(
      vector: CaptureVector.qr,
      kind: CaptureKind.unrecognised,
      rawPayload: raw,
      merchantName: _hostOf(raw),
      sourceLabel: _looksLikeUrl(raw) ? 'Web link' : 'Unrecognised code',
    );
  }

  /// A stable merchant key from an EMVCo payload.
  ///
  /// The merchant account templates (tags 26–51) hold the acquirer's own
  /// identifier for the merchant, which is the most stable thing in the
  /// payload — merchant *name* is free text and varies between terminals at
  /// the same shop. Falls back to name+city so a key always exists.
  static String? _emvMerchantKey(EmvQrPayload emv) {
    for (var i = EmvTag.merchantAccountFirst;
        i <= EmvTag.merchantAccountLast;
        i++) {
      final tag = i.toString().padLeft(2, '0');
      final v = emv.fields[tag];
      if (v != null && v.trim().isNotEmpty) {
        final country = emv.countryCode ?? 'XX';
        return 'emv:$country:${_stableHash(v)}';
      }
    }
    final name = emv.merchantName;
    if (name == null || name.isEmpty) return null;
    final city = emv.merchantCity ?? '';
    return 'emv:${emv.countryCode ?? 'XX'}:${_stableHash('$name|$city')}';
  }

  /// FNV-1a. Deterministic across devices and platforms, which a Dart
  /// `hashCode` is explicitly not — and this key has to match when two
  /// different phones capture the same shop.
  static String _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  static bool _looksLikeUrl(String s) {
    final t = s.toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  static String? _hostOf(String s) {
    if (!_looksLikeUrl(s)) return null;
    return Uri.tryParse(s)?.host;
  }

  /// ISO 4217 numeric → alpha, for the currencies SWIP is likely to meet.
  /// Unknown codes pass through as the numeric string rather than being
  /// dropped: showing "978" is honest, showing nothing is not.
  static String _currencyFromNumeric(String n) =>
      const {
        '008': 'ALL', '012': 'DZD', '032': 'ARS', '036': 'AUD', '048': 'BHD',
        '050': 'BDT', '051': 'AMD', '052': 'BBD', '060': 'BMD', '064': 'BTN',
        '068': 'BOB', '072': 'BWP', '084': 'BZD', '090': 'SBD', '096': 'BND',
        '104': 'MMK', '108': 'BIF', '116': 'KHR', '124': 'CAD', '132': 'CVE',
        '136': 'KYD', '144': 'LKR', '152': 'CLP', '156': 'CNY', '170': 'COP',
        '174': 'KMF', '188': 'CRC', '191': 'HRK', '192': 'CUP', '203': 'CZK',
        '208': 'DKK', '214': 'DOP', '222': 'SVC', '230': 'ETB', '232': 'ERN',
        '238': 'FKP', '242': 'FJD', '262': 'DJF', '270': 'GMD', '292': 'GIP',
        '320': 'GTQ', '324': 'GNF', '328': 'GYD', '332': 'HTG', '340': 'HNL',
        '344': 'HKD', '348': 'HUF', '352': 'ISK', '356': 'INR', '360': 'IDR',
        '364': 'IRR', '368': 'IQD', '376': 'ILS', '388': 'JMD', '392': 'JPY',
        '398': 'KZT', '400': 'JOD', '404': 'KES', '408': 'KPW', '410': 'KRW',
        '414': 'KWD', '417': 'KGS', '418': 'LAK', '422': 'LBP', '426': 'LSL',
        '430': 'LRD', '434': 'LYD', '446': 'MOP', '454': 'MWK', '458': 'MYR',
        '462': 'MVR', '480': 'MUR', '484': 'MXN', '496': 'MNT', '498': 'MDL',
        '504': 'MAD', '512': 'OMR', '516': 'NAD', '524': 'NPR', '532': 'ANG',
        '533': 'AWG', '548': 'VUV', '554': 'NZD', '558': 'NIO', '566': 'NGN',
        '578': 'NOK', '586': 'PKR', '590': 'PAB', '598': 'PGK', '600': 'PYG',
        '604': 'PEN', '608': 'PHP', '634': 'QAR', '643': 'RUB', '646': 'RWF',
        '654': 'SHP', '682': 'SAR', '690': 'SCR', '694': 'SLL', '702': 'SGD',
        '704': 'VND', '706': 'SOS', '710': 'ZAR', '728': 'SSP', '748': 'SZL',
        '752': 'SEK', '756': 'CHF', '760': 'SYP', '764': 'THB', '776': 'TOP',
        '780': 'TTD', '784': 'AED', '788': 'TND', '800': 'UGX', '807': 'MKD',
        '818': 'EGP', '826': 'GBP', '834': 'TZS', '840': 'USD', '858': 'UYU',
        '860': 'UZS', '882': 'WST', '886': 'YER', '901': 'TWD', '925': 'SLE',
        '926': 'VED', '927': 'UYW', '928': 'VES', '929': 'MRU', '930': 'STN',
        '932': 'ZWL', '933': 'BYN', '934': 'TMT', '936': 'GHS', '938': 'SDG',
        '940': 'UYI', '941': 'RSD', '943': 'MZN', '944': 'AZN', '946': 'RON',
        '947': 'CHE', '948': 'CHW', '949': 'TRY', '950': 'XAF', '951': 'XCD',
        '952': 'XOF', '953': 'XPF', '967': 'ZMW', '968': 'SRD', '969': 'MGA',
        '970': 'COU', '971': 'AFN', '972': 'TJS', '973': 'AOA', '975': 'BGN',
        '976': 'CDF', '977': 'BAM', '978': 'EUR', '980': 'UAH', '981': 'GEL',
        '985': 'PLN', '986': 'BRL',
      }[n] ??
      n;
}

/// Payment-link inference — ideation `C-07`.
///
/// **This vector can only ever infer.** An MCC is assigned by the *acquiring
/// bank* when the merchant is onboarded; it is not encoded anywhere in a
/// payment URL. What a link does give up is *which PSP* and *which merchant*,
/// and that is enough to key the merchant graph — so the second time anyone
/// pays that link, SWIP can answer from what it learned the first time.
///
/// Everything here therefore returns `likely` at best, and the UI says so.
abstract final class PaymentLinkInference {
  /// host pattern → (PSP name, path segment index holding the merchant slug)
  static const _psps = <String, (String, int)>{
    'rzp.io': ('Razorpay', 1),
    'razorpay.com': ('Razorpay', 1),
    'pages.razorpay.com': ('Razorpay', 0),
    'buy.stripe.com': ('Stripe', 0),
    'checkout.stripe.com': ('Stripe', 0),
    'stripe.com': ('Stripe', 1),
    'paypal.me': ('PayPal', 0),
    'paypal.com': ('PayPal', 1),
    'cashfree.com': ('Cashfree', 1),
    'payments.cashfree.com': ('Cashfree', 0),
    'paytm.me': ('Paytm', 0),
    'p.paytm.me': ('Paytm', 0),
    'phon.pe': ('PhonePe', 0),
    'bill.instamojo.com': ('Instamojo', 0),
    'imjo.in': ('Instamojo', 0),
    'payu.in': ('PayU', 1),
    'ccavenue.com': ('CCAvenue', 1),
    'checkout.square.site': ('Square', 0),
    'squareup.com': ('Square', 1),
    'venmo.com': ('Venmo', 1),
    'wise.com': ('Wise', 1),
    'revolut.me': ('Revolut', 0),
    'mollie.com': ('Mollie', 1),
    'adyen.link': ('Adyen', 0),
    'link.mercadopago.com': ('Mercado Pago', 0),
    'mpago.la': ('Mercado Pago', 0),
    'pay.line.me': ('LINE Pay', 0),
    'qr.alipay.com': ('Alipay', 0),
    'intl.alipay.com': ('Alipay', 0),
    'wechat.com': ('WeChat Pay', 1),
    'flutterwave.com': ('Flutterwave', 1),
    'paystack.com': ('Paystack', 1),
    'sumup.link': ('SumUp', 0),
  };

  static ResolvedCapture? match(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    final host = uri.host.toLowerCase();

    // Most specific host wins. Relying on map insertion order silently breaks
    // the moment two entries overlap — `pages.razorpay.com` also matches
    // `razorpay.com`, and the two disagree about which path segment holds the
    // merchant slug, so the wrong one produces a merchant key that never
    // matches the same merchant again.
    String? bestKey;
    for (final key in _psps.keys) {
      if (host != key && !host.endsWith('.$key')) continue;
      if (bestKey == null || key.length > bestKey.length) bestKey = key;
    }

    if (bestKey != null) {
      final (psp, slugIndex) = _psps[bestKey]!;
      final segments =
          uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
      final slug =
          segments.length > slugIndex ? segments[slugIndex] : null;

      return ResolvedCapture(
        vector: CaptureVector.link,
        kind: CaptureKind.paymentLink,
        // Deliberately null. Inventing a category from a URL would be exactly
        // the wrong-data problem SWIP exists to solve. The graph fills this in
        // once the merchant has been captured by any other vector.
        mcc: null,
        merchantName: slug == null ? psp : '$psp · $slug',
        merchantKey: slug == null
            ? 'link:${psp.toLowerCase()}:$host'
            : 'link:${psp.toLowerCase()}:${slug.toLowerCase()}',
        rawPayload: raw,
        acquirer: psp,
        sourceLabel: '$psp payment link',
      );
    }
    return null;
  }
}

enum CaptureKind {
  upi,
  emvco,
  paymentLink,
  corrupt,
  unrecognised;

  /// Whether the category was read out of the payload rather than inferred.
  bool get readsCategory => this == upi || this == emvco;
}

/// What the resolver made of a payload, before it becomes a ledger row.
class ResolvedCapture {
  const ResolvedCapture({
    required this.vector,
    required this.kind,
    required this.sourceLabel,
    this.mcc,
    this.merchantName,
    this.merchantCity,
    this.countryCode,
    this.merchantKey,
    this.amount,
    this.currency,
    this.terminalId,
    this.acquirer,
    this.rawPayload,
    this.merchantHandle,
    this.payeeKind = PayeeKind.undetermined,
  });

  final CaptureVector vector;
  final CaptureKind kind;

  /// Human-readable provenance, shown under the result: "UPI QR",
  /// "PIX (Brazil)", "Razorpay payment link", "Damaged QR — checksum failed".
  final String sourceLabel;

  final String? mcc;
  final String? merchantName;
  final String? merchantCity;
  final String? countryCode;
  final String? merchantKey;
  final double? amount;
  final String? currency;
  final String? terminalId;
  final String? acquirer;
  final String? rawPayload;

  /// `F-42`. The payee handle exactly as the code carried it —
  /// `paytmqr6twbbd@ptys`. Shown when no trustworthy merchant name exists,
  /// because a handle a person can read off the sticker and check is worth
  /// more than a name SWIP made up.
  final String? merchantHandle;

  /// Whether the payee is a registered business, a person, or undetermined.
  final PayeeKind payeeKind;

  bool get hasMcc => mcc != null && mcc!.length == 4 && mcc != '0000';

  /// The line to print where a shop's name goes. Falls back through: a real
  /// name → the handle → nothing (and the UI then leads with the category).
  String? get identityLine => merchantName ?? merchantHandle;
}
