/// Who is actually behind a UPI handle — `F-42`, `F-45`.
///
/// ## The problem this exists to solve
///
/// A Paytm shop sticker scans as roughly this:
///
/// ```
/// upi://pay?pa=paytmqr6twbbd@ptys&pn=Paytm&mode=02&orgid=159761&sign=MEUC…
/// ```
///
/// There is **no `mc` in it**. The shop is real, registered, and accepting
/// RuPay credit cards — but its category is not written into the sticker. Paytm's
/// own app shows "Shravan Singh Bhavar Singh Balot" because it *asks its server*
/// what that handle resolves to. The QR never said.
///
/// So SWIP showed "Unknown category · Paytm", which is doubly wrong: the
/// category is genuinely absent, but **Paytm is not the merchant** — it is the
/// payment company. Naming the PSP as the shop is the kind of confident-and-wrong
/// that destroys trust in everything else on the screen.
///
/// ## What this file can and cannot do
///
/// It **cannot** invent a category. Nothing can: the value does not exist in the
/// payload, and guessing "probably a grocer" is precisely the behaviour this
/// product exists to replace.
///
/// It **can** tell you three true things the old code threw away:
///
///  1. **This is a registered business, not a person.** A `paytmqr…@ptys`
///     handle, or `mode=02` with a signature, is a merchant handle. That alone
///     answers the question a cardholder is really asking — *"will this earn?"*
///     — better than "Unknown".
///  2. **Which payment company issued it**, kept separate from the merchant.
///  3. **A stable key for the shop**, so the moment anyone learns this shop's
///     category — by tapping its terminal, by a second QR, or by typing it in —
///     every past and future capture of the same handle inherits it.
library;

/// What a payee handle turns out to be.
enum PayeeKind {
  /// A registered business handle: `paytmqr…@ptys`, `…@merchant`, signed QR.
  registeredMerchant,

  /// A person's handle. `9820012345@ybl`, `name@okaxis` with no merchant marks.
  person,

  /// Structurally a VPA, but nothing distinguishes it either way.
  undetermined,
}

/// `F-46`, `F-47`. Which NPCI merchant tier a shop is on — the single fact that
/// explains both halves of what you saw at the counter.
///
/// NPCI onboards merchants in two tiers, and **everything follows from which**:
///
/// | | P2M — full merchant | P2PM — small merchant |
/// |---|---|---|
/// | MCC | **assigned** | **none assigned** |
/// | RuPay credit card on UPI | allowed | **not allowed** |
///
/// A merchant crossing ₹1,00,000 inward for three consecutive months must be
/// re-acquired under P2M *"with applicable Merchant Category Codes"* — which is
/// NPCI saying, in its own words, that a P2PM merchant does not have one.
///
/// So "this shop has no category" and "CRED greys out my RuPay card here" are
/// not two problems. They are one fact seen twice.
///
/// See `docs/22-FEEDBACK-ROUND-3.md` for the evidence and the sources.
enum MerchantTier {
  /// Fully onboarded. Has an MCC somewhere, even when the QR does not carry it,
  /// and can take a RuPay credit card on UPI.
  fullMerchant,

  /// Small-merchant tier. **No MCC exists**, and credit card on UPI is barred.
  smallMerchant,

  /// Not determinable from the handle alone.
  unknown;

  /// Whether a category could exist for this shop *at all*. The difference
  /// between "SWIP could not find it" and "there is nothing to find", which is
  /// the difference between a bug and a fact.
  bool get canHaveMcc => this != MerchantTier.smallMerchant;

  /// `F-47` — the line CRED shows, and now SWIP does too.
  String? get rupayNote => switch (this) {
        MerchantTier.fullMerchant =>
          'RuPay credit card should work here - this looks like a fully '
              'onboarded merchant.',
        MerchantTier.smallMerchant =>
          'RuPay credit card will not work here. NPCI does not allow credit '
              'card on UPI at small-merchant codes - which is also why this '
              'shop has no category.',
        MerchantTier.unknown => null,
      };
}

/// The result of looking at a payee handle and the QR around it.
class MerchantIdentity {
  const MerchantIdentity({
    required this.kind,
    required this.handle,
    this.tier = MerchantTier.unknown,
    this.psp,
    this.displayName,
    this.rawPayeeName,
  });

  final PayeeKind kind;

  /// `F-46`. P2M or P2PM, worked out from the handle the PSP minted.
  final MerchantTier tier;

  /// The VPA as written, lower-cased. `paytmqr6twbbd@ptys`.
  final String handle;

  /// The payment company behind the handle suffix — Paytm, PhonePe, Google Pay,
  /// Yes Bank. **Never** presented as the merchant.
  final String? psp;

  /// The best name SWIP has for the shop, or `null` when the QR only gave a
  /// generic one. `null` is the honest answer and the UI is built for it.
  final String? displayName;

  /// What `pn` literally said, kept for the technical view even when it was
  /// rejected as generic.
  final String? rawPayeeName;

  bool get isMerchant => kind == PayeeKind.registeredMerchant;

  /// The line SWIP shows where a merchant name would go.
  String get identityLine => displayName ?? handle;

  /// One sentence explaining the state of play, in the words of someone who
  /// does not know what a VPA is.
  String get explanation => switch (kind) {
        PayeeKind.registeredMerchant => psp == null
            ? 'A registered business. Its category was not written into the code.'
            : 'A registered business, accepting payments through $psp. '
                'Its category was not written into the code.'
                ' $psp knows the shop\'s name on its own servers - the sticker '
                'itself does not carry it.',
        PayeeKind.person =>
          'A personal code, not a shop. Personal codes never carry a category.',
        PayeeKind.undetermined =>
          'This code identifies who gets paid, but says nothing about what kind '
              'of business they are.',
      };

  @override
  String toString() => 'MerchantIdentity($kind, $handle, psp: $psp)';
}

abstract final class MerchantIdentifier {
  /// UPI handle suffix → the payment company that issues it.
  ///
  /// The suffix after `@` is the PSP's identifier, assigned by NPCI. It is the
  /// single most reliable field in an Indian payment QR, because unlike `pn` it
  /// cannot be typed in by whoever printed the sticker.
  static const _handleSuffixes = <String, String>{
    // Paytm
    'paytm': 'Paytm', 'ptys': 'Paytm', 'pty': 'Paytm', 'ptsbi': 'Paytm',
    'ptaxis': 'Paytm', 'pthdfc': 'Paytm', 'ptyes': 'Paytm',
    // PhonePe
    'ybl': 'PhonePe', 'ibl': 'PhonePe', 'axl': 'PhonePe',
    // Google Pay
    'okaxis': 'Google Pay', 'okhdfcbank': 'Google Pay',
    'okicici': 'Google Pay', 'oksbi': 'Google Pay',
    // Amazon Pay
    'apl': 'Amazon Pay', 'yapl': 'Amazon Pay', 'rapl': 'Amazon Pay',
    // BharatPe / others
    'bharatpe': 'BharatPe', 'yesbankltd': 'BharatPe',
    'jupiteraxis': 'Jupiter', 'fam': 'Fampay', 'naviaxis': 'Navi',
    'superyes': 'super.money', 'slc': 'slice', 'timecosmos': 'CRED',
    'axisb': 'Axis Bank', 'idfcbank': 'IDFC First', 'kotak': 'Kotak',
    'indus': 'IndusInd', 'federal': 'Federal Bank', 'fbl': 'Federal Bank',
    'icici': 'ICICI Bank', 'hdfcbank': 'HDFC Bank', 'sbi': 'SBI',
    'upi': 'BHIM', 'abfspay': 'Aditya Birla', 'freecharge': 'Freecharge',
    'mobikwik': 'MobiKwik', 'waaxis': 'WhatsApp Pay',
    'wahdfcbank': 'WhatsApp Pay', 'waicici': 'WhatsApp Pay',
  };

  /// Handle patterns that only ever appear on business handles. These are
  /// minted by the PSP at merchant onboarding and cannot be obtained by a
  /// person, which is what makes them worth trusting.
  ///
  /// Anchored, and narrower than they look. PhonePe's merchant handles are
  /// `q` **followed by digits** — matching a bare `q` prefix would have called
  /// `quickmart@okaxis` a registered merchant on the strength of one letter.
  static final _merchantHandlePatterns = <RegExp>[
    RegExp(r'^paytmqr[a-z0-9]+$'), // Paytm shop sticker
    RegExp(r'^paytm\.s[a-z0-9]+$'), // Paytm all-in-one soundbox
    RegExp(r'^bharatpe\.?[a-z0-9]*$'),
    RegExp(r'^q\d{6,}$'), // PhonePe merchant
    RegExp(r'^merchant[.\-_]?[a-z0-9]*$'),
  ];

  /// `F-46` — handle shapes that indicate the **full-merchant (P2M)** tier.
  ///
  /// `paytm.s…` is Paytm's Soundbox / All-in-One series: the box that announces
  /// the amount aloud. A shop only gets one after full onboarding, so the handle
  /// is a proxy for the tier that a shop cannot fake — it does not choose its
  /// own prefix.
  ///
  /// **This is a hypothesis, n=3**, from three CRED screenshots at three real
  /// counters:
  ///
  ///   `paytm.s28uaa5@pty`   Akruti Enterprise  → RuPay CC accepted
  ///   `paytm.s233ffl@pty`   Snowberry          → RuPay CC accepted
  ///   `paytmqr6twbbd@ptys`  "Best Wishes"      → "MERCHANT DOES NOT ACCEPT RUPAY CC"
  ///
  /// It is surfaced as *likely*, never as fact, and one counter-example kills
  /// it. A `paytmqr…` shop that does take a RuPay credit card disproves the rule
  /// outright, and that is a far better outcome than a rule nobody can falsify.
  static final _fullMerchantPatterns = <RegExp>[
    RegExp(r'^paytm\.s[a-z0-9]+$'), // Paytm Soundbox / All-in-One
    RegExp(r'^bharatpe\.?[a-z0-9]*$'), // BharatPe onboards P2M
  ];

  /// Handle shapes that indicate the **small-merchant (P2PM)** tier: the basic
  /// printed sticker, issued with light-touch onboarding and no MCC.
  static final _smallMerchantPatterns = <RegExp>[
    RegExp(r'^paytmqr[a-z0-9]+$'),
  ];

  /// Names a QR printer or PSP fills in when it has nothing better. Treating
  /// any of these as the shop's name is how "Paytm" ended up on five ledger
  /// rows that were five different shops.
  static const _genericNames = {
    'paytm', 'paytm merchant', 'paytm user', 'phonepe', 'phonepe merchant',
    'google pay', 'gpay', 'bhim', 'bharatpe', 'upi', 'upi merchant',
    'merchant', 'shop', 'store', 'business', 'test merchant', 'na', 'n/a',
    'unknown', 'customer', 'user', 'amazon pay', 'razorpay', 'cashfree',
    'payu', 'billdesk', 'ccavenue', 'instamojo', 'mobikwik', 'freecharge',
  };

  /// Work out who is behind a payment QR.
  ///
  /// [payeeAddress] is `pa`, [payeeName] is `pn`. [signed] is true when the
  /// payload carried a `sign`, and [mode] is the `mode` parameter — `02` is
  /// NPCI's marker for a merchant-presented static QR.
  static MerchantIdentity of(
    String payeeAddress, {
    String? payeeName,
    bool signed = false,
    String? mode,
  }) {
    final handle = payeeAddress.trim().toLowerCase();
    final at = handle.lastIndexOf('@');
    final local = at <= 0 ? handle : handle.substring(0, at);
    final suffix = at <= 0 || at + 1 >= handle.length
        ? null
        : handle.substring(at + 1);

    final psp = suffix == null ? null : _handleSuffixes[suffix];
    final name = _meaningfulName(payeeName);

    // ── Is this a business? ──
    // Any one of these is sufficient. A merchant-minted handle prefix is the
    // strongest, because a person cannot obtain one.
    final prefixed = _merchantHandlePatterns.any((p) => p.hasMatch(local));
    final merchantMode = mode?.trim() == '02';
    final looksLikePhone = RegExp(r'^\+?\d{10,13}$').hasMatch(local);

    final PayeeKind kind;
    if (prefixed || (merchantMode && signed)) {
      kind = PayeeKind.registeredMerchant;
    } else if (looksLikePhone && !signed) {
      // A bare phone number handle with no signature is a person, near enough
      // always. This is the case F-19 already described.
      kind = PayeeKind.person;
    } else {
      kind = PayeeKind.undetermined;
    }

    // `F-46`. Only ever claimed for a handle whose shape proves it; a signature
    // and `mode=02` prove *a business*, not *which tier*.
    final tier = _fullMerchantPatterns.any((p) => p.hasMatch(local))
        ? MerchantTier.fullMerchant
        : _smallMerchantPatterns.any((p) => p.hasMatch(local))
            ? MerchantTier.smallMerchant
            : MerchantTier.unknown;

    return MerchantIdentity(
      kind: kind,
      tier: tier,
      handle: handle,
      psp: psp,
      displayName: name,
      rawPayeeName: payeeName?.trim(),
    );
  }

  /// `pn`, unless `pn` is one of the placeholder names — in which case `null`,
  /// because no name is more useful than a wrong one.
  static String? _meaningfulName(String? payeeName) {
    final n = payeeName?.trim();
    if (n == null || n.isEmpty) return null;
    final key = n.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (_genericNames.contains(key)) return null;
    // "Paytm Merchant 12345", "PhonePe Merchant" and friends.
    for (final g in _genericNames) {
      if (key.startsWith('$g ') && key.length - g.length < 12) return null;
    }
    return n;
  }

  /// True when [name] is one SWIP should not show as a shop. Exposed so the
  /// EMVCo path (tag 59) can apply the same rule — BharatQR stickers printed
  /// by a PSP carry exactly the same placeholder names.
  static bool isGenericName(String? name) => _meaningfulName(name) == null;
}
