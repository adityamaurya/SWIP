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
  // Two segments and a milestone. The first is the live foreclosure figure -
  // the debt that is actually being carried right now. The second is the money
  // that was earned and did not stay, which is the longer thing being worked
  // back toward.
  //
  // Deliberately NOT stored: which lenders, what schedule, what dates. A goal
  // and a percentage are all a progress bar needs.

  /// The live portfolio foreclosure figure. The first milestone on the bar.
  static const milestone = 1350308;

  /// Earned, and gone. The rest of the bar.
  static const stretch = 3902887;

  static const total = milestone + stretch;

  /// Raised so far. There is no server, so this is not fetched - it is edited
  /// when it changes, which is honest about what the app can actually know.
  static const raised = 0;

  static double get milestoneFraction => milestone / total;
  static double get raisedFraction => (raised / total).clamp(0.0, 1.0);

  // ── how to pay ──────────────────────────────────────────────────────────
  //
  // PLACEHOLDERS. The support section renders a "not set up yet" state while
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
