/// `F-124` — will a RuPay credit card work at this shop, and how sure are we?
///
/// ## Why this is its own file
///
/// The old answer was a getter on [MerchantTier] with three outcomes, two of
/// which were sentences and one of which was `null`. That was fine when the
/// only evidence was a handle prefix. It is not fine now: the payload carries
/// five or six independent signals, they disagree with each other, and the
/// honest output is a **confidence with its reasons attached**, not a sentence.
///
/// ## What CRED does, and the one word that gives it away
///
/// CRED shows, on a RuPay card at a merchant it is unsure about:
///
/// > MERCHANT MAY NOT ACCEPT RUPAY CC
///
/// **"may".** If CRED held an authoritative acceptance flag it would say "does
/// not". It hedges because it is inferring — from the handle, from the QR, and
/// from its own history of declines across millions of payments. At a merchant
/// it *is* sure about, the same app says plainly *"this merchant accepts RuPay
/// payments"*.
///
/// So the shape to copy is not a lookup. It is a **prior from the payload,
/// corrected by observed outcomes**, stated at the confidence it has earned.
/// SWIP has four of the five layers CRED has; the missing one is a licensed
/// merchant directory, and the copy hedges exactly where that gap is.
///
/// ## The one thing that is not a guess
///
/// [RupayCcOutlook.blocked] is absolute, and it is absolute because it is NPCI
/// policy rather than a merchant's setting:
///
/// > P2P, P2PM and card-to-card payments shall not be permitted for RuPay
/// > credit card transactions on UPI.
/// > — NPCI, Operating circular for RuPay Credit Cards linked to UPI
///
/// A small-merchant code cannot take a credit card on UPI no matter what the
/// shopkeeper would like. That is the only claim here stated without a hedge.
library;

import 'merchant_identity.dart';
import 'upi_uri_parser.dart';

/// How likely a RuPay credit card on UPI is to be accepted here.
enum RupayCcOutlook {
  /// NPCI policy forbids it. Not a merchant setting, not a guess.
  blocked,

  /// Evidence points against it: the acquirer left the category blank, or a
  /// card payment has already been declined here.
  unlikely,

  /// Nothing decisive either way. **Shown as silence**, never as a shrug.
  unknown,

  /// A fully onboarded merchant. Should work, said as "should".
  likely,

  /// You have already paid by card here. The only certainty on the accepting
  /// side, and it can only ever come from the user's own history.
  confirmed;

  bool get isNegative => this == blocked || this == unlikely;
}

/// An outlook, the sentence for it, and **why** — never a colour on its own.
class RupayVerdict {
  const RupayVerdict(this.outlook, {this.headline, this.because});

  final RupayCcOutlook outlook;

  /// The line the user reads. `null` for [RupayCcOutlook.unknown] — a screen
  /// that says "we don't know" about everything teaches you to ignore it.
  final String? headline;

  /// The evidence, in one clause, so the claim can be checked rather than
  /// believed. Shown under the headline in smaller type.
  final String? because;

  static const _unknown = RupayVerdict(RupayCcOutlook.unknown);

  /// Work out the verdict from everything SWIP can see.
  ///
  /// [declinedBefore] and [succeededBefore] come from the merchant graph: the
  /// user's own history at this exact merchant key. They outrank every
  /// payload signal, because an observed outcome beats an inference.
  static RupayVerdict of({
    required MerchantIdentity identity,
    UpiIntent? intent,
    bool declinedBefore = false,
    bool succeededBefore = false,
  }) {
    // ── Observed outcomes first. Nothing derived beats something witnessed. ──
    if (succeededBefore) {
      return const RupayVerdict(
        RupayCcOutlook.confirmed,
        headline: 'Your card has worked here before',
        because: 'You recorded a successful card payment at this merchant.',
      );
    }
    if (declinedBefore) {
      return const RupayVerdict(
        RupayCcOutlook.unlikely,
        headline: 'Your card was declined here before',
        because: 'You recorded a card payment that this merchant refused.',
      );
    }

    // ── NPCI policy. The only unhedged claim on this screen. ──
    if (identity.tier == MerchantTier.smallMerchant) {
      return const RupayVerdict(
        RupayCcOutlook.blocked,
        headline: 'RuPay credit card will not work here',
        because: 'NPCI does not permit credit card on UPI at small-merchant '
            'codes. That is also why this shop has no category.',
      );
    }

    final pub = intent?.mccPublication;

    // ── The acquirer wrote the category field and left it empty. ──
    //
    // Seen on a bank-acquired merchant whose card payment was then refused with
    // "merchant doesn't accept credit cards". One blank field is not proof, so
    // this is "may not" — the same hedge CRED uses, for the same reason.
    if (pub == MccPublication.blank) {
      return const RupayVerdict(
        RupayCcOutlook.unlikely,
        headline: 'This merchant may not accept RuPay credit card',
        because: 'Their bank built the QR but left the category blank, which '
            'usually means a partial onboarding. Keep a bank account ready.',
      );
    }

    if (pub == MccPublication.published) {
      return const RupayVerdict(
        RupayCcOutlook.likely,
        headline: 'RuPay credit card should work here',
        because: 'This QR publishes a merchant category, which is only issued '
            'at the full-merchant tier.',
      );
    }

    if (identity.tier == MerchantTier.fullMerchant) {
      return const RupayVerdict(
        RupayCcOutlook.likely,
        headline: 'RuPay credit card should work here',
        because: 'The payment handle is one issued only after full merchant '
            'onboarding.',
      );
    }

    return _unknown;
  }
}
