import 'package:flutter/foundation.dart';

import 'mcc.dart';

/// How an MCC reached the ledger.
///
/// Implements ideation `D-02`: *"whenever a swipe, scan, or link URL happens, it
/// gets added to the ledger."* Every vector writes through one path so the
/// ledger can never disagree with itself about what happened.
enum CaptureVector {
  /// Vector 1 — merchant-presented QR (EMVCo tag 52, or UPI `mc`).
  qr('Scan', 'QR code'),

  /// Vector 2 — POS terminal over NFC (EMV tag 9F15 via PDOL). Android only.
  nfc('Tap', 'POS terminal'),

  /// Vector 3 — payment link inference.
  link('Link', 'Payment link'),

  /// Vector 4 — declined authorization on a SWIP Probe card (v2).
  probe('Probe', 'Probe card'),

  /// Vector 7 — a merchant's "pay by any UPI app" intent, read on the way
  /// through. The MCC arrives in the intent's `mc` parameter before payment.
  intent('App', 'Pay-by-app intent'),

  /// Vector 5 — the user told us what posted on their statement.
  manual('Manual', 'You confirmed it'),

  /// Vector 6 — answered from the merchant graph, no live capture.
  graph('Known', 'SWIP merchant graph');

  const CaptureVector(this.shortLabel, this.longLabel);
  final String shortLabel;
  final String longLabel;

  /// Whether this vector read the code from the transaction itself, as opposed
  /// to inferring it. Drives the default confidence and the disclosure banner.
  bool get isLiveCapture =>
      this == CaptureVector.qr ||
      this == CaptureVector.nfc ||
      this == CaptureVector.probe ||
      // The intent's `mc` is set by the merchant's own PSP, so it is as
      // authoritative as a QR — it is the same field arriving by a different
      // route, and it arrives before the payment rather than after.
      this == CaptureVector.intent;
}

/// One row of the ledger.
///
/// Immutable by design: a ledger entry is a record of something that happened,
/// and corrections are new rows referencing the old one via [correctsId], never
/// edits in place. That is ordinary practice for financial records and it costs
/// nothing to adopt now — retrofitting it later is painful.
@immutable
class CaptureEvent {
  const CaptureEvent({
    required this.id,
    required this.mcc,
    required this.vector,
    required this.confidence,
    required this.capturedAt,
    this.merchantName,
    this.merchantCity,
    this.countryCode,
    this.merchantKey,
    this.amount,
    this.currency,
    this.cardId,
    this.terminalId,
    this.acquirer,
    this.rawPayload,
    this.correctsId,
    this.syncedAt,
    this.geohash,
    this.placeLabel,
    this.placeCountry,
  });

  final String id;

  /// The four digits. `null` when the source carried no category at all — a
  /// legitimate outcome that must be shown as "no category", not as a failure.
  final String? mcc;

  final CaptureVector vector;
  final MccConfidence confidence;

  /// When the capture happened, in UTC. Always stored UTC, always rendered in
  /// the device's local zone — a user who captures in Dubai and reads the
  /// ledger in Mumbai must see the moment, not a shifted one.
  final DateTime capturedAt;

  final String? merchantName;
  final String? merchantCity;

  /// ISO 3166-1 alpha-2.
  final String? countryCode;

  /// Stable, globally unique merchant identifier used to key the merchant
  /// graph. Composed per vector:
  ///   qr    → `upi:<vpa>` or `emv:<country>:<acct-template-hash>`
  ///   nfc   → `emv:<9F1A>:<9F16>`
  ///   link  → `<psp>:<merchant-key>`   e.g. `razorpay:rzp_live_Lq7…`
  final String? merchantKey;

  final double? amount;

  /// ISO 4217 alpha, e.g. `INR`.
  final String? currency;

  /// Local id of the card the user says they used. Never a PAN.
  final String? cardId;

  /// EMV tag 9F1C.
  final String? terminalId;

  final String? acquirer;

  /// Raw TLV, APDU trace or URL, for the level-2 "Raw payload" view. This
  /// audience does not trust a number it cannot verify, and being the app that
  /// shows its working is a durable trust advantage.
  final String? rawPayload;

  /// Set when this row supersedes an earlier one.
  final String? correctsId;

  /// Null until contributed to the graph. Sync is opt-in and off by default.
  final DateTime? syncedAt;

  /// `F-40`. A 6-character geohash — a cell of roughly 1.2 km × 0.6 km — and
  /// never the raw fix. The ledger is exported to the user's own Drive, so a
  /// file of exact coordinates for every shop they have paid at is not
  /// something SWIP is willing to create. Null unless location is switched on.
  final String? geohash;

  /// "Bandra, IN". Best-effort, cosmetic, and frequently null offline.
  final String? placeLabel;

  /// Where **you** were, ISO alpha-2. Distinct from [countryCode], which is the
  /// merchant's registration: when the two disagree, that is a fact worth
  /// showing rather than a conflict to resolve.
  final String? placeCountry;

  bool get hasLocation => geohash != null;

  bool get isSynced => syncedAt != null;
  bool get hasMcc => mcc != null && mcc!.length == 4;
  bool get isUnclassified => mcc == '0000';

  /// `F-42`. The payee handle, recovered from [merchantKey] rather than stored
  /// twice — `upi:paytmqr6twbbd@ptys` → `paytmqr6twbbd@ptys`.
  ///
  /// Derived rather than a column because it is the same fact written two ways,
  /// and a second copy is a second thing that can disagree. It also means no
  /// schema migration for ledgers that already exist on people's phones.
  String? get merchantHandle {
    final k = merchantKey;
    if (k == null || !k.startsWith('upi:')) return null;
    final h = k.substring(4);
    return h.isEmpty ? null : h;
  }

  /// `F-44`. What goes where the shop's name goes.
  ///
  /// A real name if the code carried one, else the handle — which a person can
  /// read off the sticker in front of them and check. Never the PSP's name:
  /// "Paytm" on five rows for five different shops is worse than no name.
  String? get identityLine => merchantName ?? merchantHandle;

  /// The category line when there is no name for the code. Each case is a
  /// different situation with a different remedy, so each gets its own words.
  String get categoryFallback {
    if (isUnclassified) return 'No category set by the merchant\'s bank';
    if (mcc == null) return 'Category not written into this code';
    return 'Category $mcc — not in the offline table yet';
  }

  CaptureEvent copyWith({
    String? mcc,
    MccConfidence? confidence,
    String? merchantName,
    String? cardId,
    DateTime? syncedAt,
  }) =>
      CaptureEvent(
        id: id,
        mcc: mcc ?? this.mcc,
        vector: vector,
        confidence: confidence ?? this.confidence,
        capturedAt: capturedAt,
        merchantName: merchantName ?? this.merchantName,
        merchantCity: merchantCity,
        countryCode: countryCode,
        merchantKey: merchantKey,
        amount: amount,
        currency: currency,
        cardId: cardId ?? this.cardId,
        terminalId: terminalId,
        acquirer: acquirer,
        rawPayload: rawPayload,
        correctsId: correctsId,
        syncedAt: syncedAt ?? this.syncedAt,
        geohash: geohash,
        placeLabel: placeLabel,
        placeCountry: placeCountry,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'mcc': mcc,
        'vector': vector.name,
        'confidence': confidence.name,
        'captured_at': capturedAt.toUtc().millisecondsSinceEpoch,
        'merchant_name': merchantName,
        'merchant_city': merchantCity,
        'country_code': countryCode,
        'merchant_key': merchantKey,
        'amount': amount,
        'currency': currency,
        'card_id': cardId,
        'terminal_id': terminalId,
        'acquirer': acquirer,
        'raw_payload': rawPayload,
        'corrects_id': correctsId,
        'synced_at': syncedAt?.toUtc().millisecondsSinceEpoch,
        'geohash': geohash,
        'place_label': placeLabel,
        'place_country': placeCountry,
      };

  factory CaptureEvent.fromRow(Map<String, Object?> r) => CaptureEvent(
        id: r['id']! as String,
        mcc: r['mcc'] as String?,
        vector: CaptureVector.values.byName(r['vector']! as String),
        confidence: MccConfidence.values.byName(r['confidence']! as String),
        capturedAt: DateTime.fromMillisecondsSinceEpoch(
            r['captured_at']! as int,
            isUtc: true),
        merchantName: r['merchant_name'] as String?,
        merchantCity: r['merchant_city'] as String?,
        countryCode: r['country_code'] as String?,
        merchantKey: r['merchant_key'] as String?,
        amount: (r['amount'] as num?)?.toDouble(),
        currency: r['currency'] as String?,
        cardId: r['card_id'] as String?,
        terminalId: r['terminal_id'] as String?,
        acquirer: r['acquirer'] as String?,
        rawPayload: r['raw_payload'] as String?,
        correctsId: r['corrects_id'] as String?,
        geohash: r['geohash'] as String?,
        placeLabel: r['place_label'] as String?,
        placeCountry: r['place_country'] as String?,
        syncedAt: r['synced_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(r['synced_at']! as int,
                isUtc: true),
      );
}
