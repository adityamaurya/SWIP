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

import 'upi_uri_parser.dart';

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
    // `F-123`. Banks that acquire merchants directly, seen in the field.
    'svcbank': 'SVC Co-operative Bank', 'cnrb': 'Canara Bank',
    'barodampay': 'Bank of Baroda', 'aubank': 'AU Small Finance Bank',
    'idbi': 'IDBI Bank', 'pnb': 'Punjab National Bank',
    'unionbankofindia': 'Union Bank', 'yesbank': 'Yes Bank',
    'dbs': 'DBS', 'rbl': 'RBL Bank', 'jio': 'Jio',
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

    // `F-123`. Bank-acquired merchants. Decoded from the Shree Beauty Centre
    // stand: `pa=SVCMERC00306934@svcbank`. Co-operative and public-sector banks
    // acquire merchants directly and mint `<BANK>MERC<id>` handles rather than
    // going through a Paytm or a PhonePe. That handle is proof of a merchant
    // onboarding, and SWIP was calling it "undetermined" for want of a pattern.
    RegExp(r'^[a-z]{2,6}merc[a-z0-9]*\d+$'),
    RegExp(r'^merc[a-z0-9]*\d{4,}$'),

    // `F-137`. **Payment-aggregator handles**, found in the owner's own
    // 85-capture export. PayU, Razorpay and Cashfree mint
    // `<merchant>.<aggregator>@<psp>` at onboarding, and the export contained
    // two that SWIP was calling "undetermined":
    //
    //     tatastarbucks.payu@mairtel   pn=TATA STARBUCKS PRIVATE LIMITED
    //     zepto.payu@mairtel           pn=Zepto Marketplace Private Limite
    //
    // A person cannot obtain one of these, which is the same property that
    // makes `paytmqr…` trustworthy.
    RegExp(r'^[a-z0-9._-]+\.(payu|rzp|razorpay|cf|cashfree|ccav|ippo)$'),

    // NOTE: there is deliberately **no** pattern here for terminal handles like
    // `WFMLMH2@ybl` (Wellness Forever, on a Pine Labs box). Any regex loose
    // enough to catch it — "letters, then a digit" — also catches
    // `john123@okaxis`, and calling a person's handle a registered merchant is
    // a worse failure than missing one. That case is proven from the *payload*
    // instead: a dynamic QR carrying an amount and a terminal `tr` prefix is a
    // merchant by construction. See [ofIntent].
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

    // `F-123`. A bank does not acquire a merchant under P2PM and then mint it a
    // `…MERC…` handle with its own reference number; the small-merchant tier is
    // the light-touch one precisely because it skips that. A `<BANK>MERC<id>`
    // handle is a fully acquired merchant, whatever else is or is not in the QR.
    RegExp(r'^[a-z]{2,6}merc[a-z0-9]*\d+$'),

    // `F-137`. An aggregator onboards under P2M - that is what an aggregator
    // is for. Confirmed in the export by Tata Starbucks and Zepto, both of
    // which are unambiguously full merchants.
    RegExp(r'^[a-z0-9._-]+\.(payu|rzp|razorpay|cf|cashfree|ccav|ippo)$'),
  ];

  /// `F-137` — **a legal-entity suffix in `pn` is a business, full stop.**
  ///
  /// The other thing the export made obvious. `pn` is free text and usually
  /// worthless ("Paytm", "BharatPe Merchant"), which is why it is distrusted
  /// everywhere else in this file. But nobody's personal UPI handle says
  /// "PRIVATE LIMITED", and three rows in the export carried exactly that:
  ///
  ///     TATA STARBUCKS PRIVATE LIMITED
  ///     Zepto Marketplace Private Limite      <- note: truncated by the PSP
  ///
  /// Matched as a **substring**, not a suffix, because PSPs truncate `pn` to a
  /// fixed width and "Private Limite" is what actually arrives.
  ///
  /// ## What is deliberately not matched
  ///
  /// The same export contains `Greymode Architectural Products`, which is
  /// obviously a business to a human and is **not** matched here. Catching it
  /// would mean treating words like "Products", "Graphics" or "Services" as
  /// business markers, and that road ends badly: the export also contains
  /// `janhavigraphics@oksbi` whose `pn` is **`Pramod Parkar`** — a person's
  /// name on a business-sounding handle. Guessing from vocabulary gets that
  /// one wrong in both directions.
  ///
  /// A legal-entity suffix is different in kind: it is a **registration
  /// fact**, not a descriptive word. Only those are used.
  static final _entityMarkers = <RegExp>[
    RegExp(r'\bprivate\s+limite', caseSensitive: false),
    RegExp(r'\bpvt\.?\s*ltd', caseSensitive: false),
    RegExp(r'\bltd\b', caseSensitive: false),
    RegExp(r'\bllp\b', caseSensitive: false),
    RegExp(r'\bopc\b', caseSensitive: false),
    RegExp(r'\benterprises?\b', caseSensitive: false),
    RegExp(r'\btraders?\b', caseSensitive: false),
    RegExp(r'\bindustries\b', caseSensitive: false),
    RegExp(r'\bcorporation\b', caseSensitive: false),
    RegExp(r'\bmarketplace\b', caseSensitive: false),
  ];

  /// Whether `pn` names a registered company rather than a person.
  static bool namesALegalEntity(String? payeeName) {
    final n = payeeName?.trim();
    if (n == null || n.length < 4) return false;
    if (isGenericName(n)) return false;
    return _entityMarkers.any((p) => p.hasMatch(n));
  }

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
    // `F-137`. A company name in `pn` is evidence on its own.
    final namedEntity = namesALegalEntity(payeeName);
    final looksLikePhone = RegExp(r'^\+?\d{10,13}$').hasMatch(local);

    final PayeeKind kind;
    if (prefixed || namedEntity || (merchantMode && signed)) {
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

  /// `F-123` — **identify from the whole payload, not just the handle.**
  ///
  /// [of] sees a VPA and, at best, two extra flags. A UPI QR carries far more
  /// than that, and three of the fields it carries settle questions the handle
  /// alone cannot:
  ///
  ///   * a **published `mc`** is issued at merchant onboarding. A category
  ///     cannot exist for a payee who is not a merchant, so `mc=5912` *is* the
  ///     proof — this is how `WFMLMH2@ybl` is known to be Wellness Forever and
  ///     not somebody's personal handle, without a regex loose enough to be
  ///     dangerous;
  ///   * **`mode=15` with an amount** is a QR minted by a terminal for one
  ///     transaction. People do not have terminals;
  ///   * a **blank `mc=`** means a merchant-onboarding flow wrote the field and
  ///     left it empty, which no personal QR ever does.
  ///
  /// Anything this adds is evidence *for* merchant status; nothing here can
  /// demote a payee to `person`, so a false positive needs a merchant-only
  /// field to be present on a personal QR, which does not happen.
  static MerchantIdentity ofIntent(UpiIntent intent) {
    final pa = intent.payeeAddress;
    if (pa == null || pa.isEmpty) {
      return const MerchantIdentity(
          kind: PayeeKind.undetermined, handle: '');
    }

    final base = of(
      pa,
      payeeName: intent.payeeName,
      signed: intent.isSigned,
      mode: intent.mode,
    );

    final pub = intent.mccPublication;
    final payloadProvesMerchant = pub == MccPublication.published ||
        pub == MccPublication.unclassified ||
        pub == MccPublication.blank ||
        (intent.isDynamic && intent.acquirerHint != null);

    if (!payloadProvesMerchant) return base;

    // A published category also settles the tier: NPCI assigns MCCs at the
    // full-merchant tier and does not assign them at the small-merchant tier,
    // so a real category is a full merchant seen from the other direction.
    final tier = pub == MccPublication.published
        ? MerchantTier.fullMerchant
        : base.tier;

    return MerchantIdentity(
      kind: base.kind == PayeeKind.person
          ? PayeeKind.person
          : PayeeKind.registeredMerchant,
      tier: tier,
      handle: base.handle,
      psp: base.psp,
      displayName: base.displayName,
      rawPayeeName: base.rawPayeeName,
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
