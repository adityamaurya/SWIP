/// `F-125` — **when the category is not in the code, say how to get it.**
///
/// ## The complaint this exists to answer
///
/// > *"the pop up came but it failed on the catching the mcc find the root
/// > reason and get it sorted and detect fail proof for future"*
///
/// The root reason, for the corn-dog stall's Paytm sticker, is not a bug. It is
/// this, decoded from the photograph of the sticker itself:
///
/// ```
/// upi://pay?pa=paytm.s26upzx@pty&pn=Paytm
/// ```
///
/// **That is the whole payload. Two fields.** There is no category in it to
/// catch, and no app on any phone can read one out of it — CRED included. What
/// CRED shows at that same handle family is *"this merchant accepts RuPay
/// payments"*, which is a **tier flag, not a category**. CRED does not show you
/// an MCC there either.
///
/// So "fail-proof" cannot mean "always find it in the QR". It means: **never
/// leave the person at a dead end.** For every capture where the category is
/// missing, SWIP knows precisely which other routes would work *for this
/// merchant*, and says so as things to do rather than as an apology.
///
/// ## The ladder
///
/// Ordered by how likely each is to succeed for the merchant in hand, not by
/// how clever it is. Anything learned by any route is written to the merchant
/// graph against the payee handle, so it back-fills every past and future
/// capture of the same shop — which is the part that actually compounds.
library;

import 'merchant_identity.dart';
import 'upi_uri_parser.dart';

/// One way to get the category for this specific merchant.
class MccRoute {
  const MccRoute({
    required this.title,
    required this.detail,
    required this.kind,
  });

  final String title;
  final String detail;
  final MccRouteKind kind;
}

enum MccRouteKind {
  /// Tap the shop's card machine. Reads EMV tag `9F15` over NFC.
  tapTerminal,

  /// Ask the shop to generate a bill on their machine, then scan that QR.
  dynamicQr,

  /// Pay once by card, then import the bank statement, which names the
  /// category. Slow, but it never fails.
  statement,

  /// Let the payment app hand SWIP the intent at checkout.
  appHandover,

  /// Nothing will work: there is no category to find, at any price.
  impossible,
}

/// Why the category is missing, in the user's terms rather than the parser's.
class MccAbsence {
  const MccAbsence({
    required this.reason,
    required this.routes,
    required this.fixable,
  });

  /// One sentence. Never the word "error", never the word "failed".
  final String reason;

  /// What to do about it, best first. Empty only when nothing will work.
  final List<MccRoute> routes;

  /// Whether a category exists at all to be found.
  final bool fixable;

  static const _tap = MccRoute(
    kind: MccRouteKind.tapTerminal,
    title: 'Tap their card machine',
    detail: 'A POS terminal broadcasts its category over NFC. One tap, no '
        'payment, and SWIP reads it directly.',
  );

  static const _dynamic = MccRoute(
    kind: MccRouteKind.dynamicQr,
    title: 'Ask them to bill it on the machine',
    detail: 'The QR a terminal prints for one bill carries the category, where '
        'the sticker on the counter does not.',
  );

  static const _statement = MccRoute(
    kind: MccRouteKind.statement,
    title: 'Pay once, then import your statement',
    detail: 'Your bank prints the category on the transaction line. Paste the '
        'statement into SWIP and this shop is filled in for good.',
  );

  static const _handover = MccRoute(
    kind: MccRouteKind.appHandover,
    title: 'Pay through SWIP next time',
    // `F-198`. *"usually"* is doing real work in this sentence and it is worth
    // knowing what it means, because the sentence has been read as a promise.
    //
    // A checkout hand-off carries a category when the merchant's payment
    // aggregator put one in the string — which online aggregators mostly do,
    // because they onboard merchants properly. It is **not** a property of the
    // hand-off. NPCI's linking spec marks `mc` optional and says *"if present
    // then needs to be passed as it is"*: an intent forwards a category, it
    // never mints one. `docs/51`.
    detail: 'An online checkout usually puts the category in the payment it '
        'hands over. A sticker on a counter usually does not.',
  );

  /// `F-198` — **the answer that is taped to the same counter.**
  ///
  /// `docs/42` counted 48 codes from one market walk. Every Google Pay for
  /// Business code published `mc`; **not one** Paytm, PhonePe or BharatPe code
  /// did. A shop with more than one sticker is a shop where the category is
  /// already on the board — just not on the code that was scanned.
  ///
  /// This is the cheapest route on the list by a wide margin. It needs no
  /// terminal, no payment, no statement and no network: a second scan, and a
  /// confirmation that the two are the same shop.
  static const _otherSticker = MccRoute(
    kind: MccRouteKind.dynamicQr,
    title: 'Look for the shop\'s other code',
    detail: 'Google Pay stickers carry the category and Paytm, PhonePe and '
        'BharatPe ones do not. Scan the other code on the counter and SWIP '
        'will offer to join them.',
  );

  /// Work out why there is no category, and what would get one.
  static MccAbsence of({
    required MerchantIdentity identity,
    UpiIntent? intent,
  }) {
    // ── A small merchant has no category to find. Say so and stop. ──
    //
    // Offering four things to try, none of which can work, is worse than
    // saying nothing: it costs the person a trip to a counter to learn what
    // SWIP already knew.
    if (identity.tier == MerchantTier.smallMerchant) {
      return const MccAbsence(
        fixable: false,
        reason: 'Small-merchant codes are not issued a category at all. There '
            'is nothing here for any app to find, and no card will reward this '
            'payment.',
        routes: [],
      );
    }

    switch (intent?.mccPublication) {
      case MccPublication.blank:
        return const MccAbsence(
          fixable: true,
          reason: 'Their bank wrote the category field into this QR and left '
              'it empty. The shop has a category; its acquirer did not print '
              'it.',
          // `F-198`. **This acquirer** left it empty — which says nothing
          // about the one who printed the other sticker on the same counter.
          routes: [_tap, _otherSticker, _dynamic, _statement],
        );

      case MccPublication.malformed:
        return const MccAbsence(
          fixable: true,
          reason: 'The category in this QR is not four digits, so SWIP will '
              'not show it. A wrong category is worse than none.',
          routes: [_tap, _dynamic, _statement],
        );

      case MccPublication.unclassified:
        return const MccAbsence(
          fixable: true,
          reason: 'This QR says 0000, which is the code for "unclassified". '
              'That is a real answer, not a gap - but the shop may have a '
              'better one on its terminal.',
          routes: [_tap, _statement],
        );

      default:
        // The common case, and the corn-dog stall: a static sticker with a
        // payee and nothing else.
        return const MccAbsence(
          fixable: true,
          reason: 'This is a printed sticker. It carries who gets paid and '
              'nothing else - the category lives on the shop\'s terminal and '
              'on their bank\'s servers, never on the sticker.',
          // `F-198`. `_otherSticker` goes **second**, above the dynamic QR and
          // the hand-off, and the order is the argument: it is the only route
          // on this list that needs nothing from anybody. A tap needs their
          // terminal, a dynamic QR needs the cashier to ring it up, a
          // statement needs a payment first. Scanning the code next to this
          // one needs a second scan.
          //
          // It stays below the tap because a tap is *deterministic* where this
          // is a link the user confirms — and `docs/47` notwithstanding, when
          // a terminal does publish `9F15` it is the shop's own category
          // rather than a neighbour's.
          routes: [_tap, _otherSticker, _dynamic, _handover, _statement],
        );
    }
  }
}
