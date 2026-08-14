/// `F-111` — the one place the support numbers and links live.
///
/// Separated from the widget so that changing a figure or a payment link is a
/// one-line edit in a file with no layout in it, and so the numbers can be read
/// by a test without pumping a screen.
///
/// See `docs/27-DONATIONS.md` for the tax position these are built against.
class SupportGoal {
  const SupportGoal._();

  // ── the goal ────────────────────────────────────────────────────────────
  //
  // `F-120`. **One bar, two milestones** — not two goals added together.
  //
  // It used to be `milestone + stretch = total`, which put the finish line at
  // ₹52.5 lakh and made the first marker sit at a quarter of the way along. That
  // is not the shape of the thing. The shape is: one road to ₹39 lakh, with a
  // marker at ₹13.5 lakh where the debt is cleared and the rest stops being
  // urgent.
  //
  // Deliberately NOT stored: which lenders, what schedule, what dates. A goal
  // and a percentage are all a progress bar needs.

  /// The first marker on the bar. The live foreclosure figure — the debt that is
  /// actually being carried right now.
  static const milestone = 1350308;

  /// The end of the bar. Earned over the years, and gone.
  static const goal = 3902887;

  /// Raised so far. There is no server, so this is not fetched - it is edited
  /// when it changes, which is honest about what the app can actually know.
  static const raised = 0;

  static double get milestoneFraction => milestone / goal;
  static double get raisedFraction => (raised / goal).clamp(0.0, 1.0);

  /// How far along the *first* milestone is on its own, for the line that reads
  /// "₹0 of ₹13.5 lakh".
  static double get milestoneProgress =>
      (raised / milestone).clamp(0.0, 1.0);

  /// `₹13.5 lakh`, `₹39.0 lakh`. Lakh rather than a full rupee figure on
  /// purpose: the exact number is a private fact, and the bar only needs a
  /// scale.
  static String lakh(int rupees) {
    final l = rupees / 100000;
    return '₹${l.toStringAsFixed(1)} lakh';
  }

  // ── how to pay ──────────────────────────────────────────────────────────
  //
  // PLACEHOLDERS. The support surfaces render a "not set up yet" state while
  // either of these is empty, rather than opening a broken link - see
  // [isConfigured].

  /// e.g. `adityamaurya@okhdfcbank`
  static const upiId = '';

  /// A Razorpay payment-page link, e.g. `https://rzp.io/l/xxxxxxxx`
  static const razorpayLink = '';

  static bool get hasUpi => upiId.isNotEmpty;
  static bool get hasCard => razorpayLink.isNotEmpty;
  static bool get isConfigured => hasUpi || hasCard;

  // ── what SWIP would post as ─────────────────────────────────────────────
  //
  // `F-111`. SWIP shows its own capture sheet before taking a rupee, so the
  // donor gets the same screen every merchant gets. 7372 is the code for
  // computer programming, data processing and integrated systems design -
  // which is what this is.
  static const ownMcc = '7372';
  static const ownName = 'SWIP';

  /// Held here rather than looked up through the MCC table, so the sheet needs
  /// no provider and no async read for a string that cannot change.
  static const ownMccName =
      'Computer Programming, Data Processing and Integrated Systems Design';

  /// The suggested amounts. Small, and the largest is not large - the section
  /// is not trying to land a big number, it is trying not to be a plea.
  static const suggested = <int>[100, 500, 1000];
}
