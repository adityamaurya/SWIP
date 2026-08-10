import '../models/capture_event.dart';

/// `F-49` — one shop, two identities.
///
/// ## The problem, exactly as it happened at Snowberry
///
/// You tapped the terminal and SWIP read `5451`. Three minutes later you
/// scanned the shop's Paytm sticker and SWIP knew nothing. Same counter, same
/// visit — and no link, because the two vectors key on different things and
/// both are right to:
///
/// ```
/// POS tap  →  emv:356:<the terminal's merchant id>
/// QR scan  →  upi:paytm.s233ffl@pty
/// ```
///
/// Nothing in either payload references the other. The acquirer knows they are
/// one merchant; the phone cannot see that.
///
/// ## How the industry solves it, and why SWIP cannot copy it
///
/// Plaid normalises merchant strings with regex and fuzzy matching against a
/// curated knowledge base; Yodlee runs a machine-learning engine over millions
/// of transactions. Both are **corpus-scale and server-side** — they work
/// because they have seen the same merchant a million times across a million
/// users, and they still get names wrong often enough to need cleanup.
///
/// SWIP has no server, no corpus, and frequently n=1. Fuzzy-matching two
/// merchant strings on one phone would be guessing dressed up as inference, and
/// merging two shops that are not the same is the single most damaging thing
/// this app could do to itself — a wrong category, stated confidently, inherited
/// by every future scan.
///
/// ## So SWIP uses evidence instead of similarity
///
/// Two captures are proposed as the same shop only when **circumstance** says
/// so, never because two strings look alike:
///
///   1. **Same place** — the same ~1 km geohash cell.
///   2. **Same visit** — inside a short window. You do not tap a terminal and
///      scan a sticker at two different shops ninety seconds apart.
///   3. **Different identity spaces** — one `emv:`, one `upi:`. Two QRs in one
///      cell are two shops in a market; a tap and a QR are one counter.
///   4. **Complementary** — exactly one of them carries a category. There is no
///      point linking two blanks, and two different categories is a conflict to
///      surface, not a link to make.
///
/// And then **the user confirms**. That is not a cop-out: the person was
/// standing there. They are a better source than any heuristic, and asking them
/// once buys a permanent, correct answer instead of a probabilistic one.
class MerchantLinkProposal {
  const MerchantLinkProposal({
    required this.teacher,
    required this.learner,
    required this.minutesApart,
  });

  /// The capture that has a category — normally the POS tap.
  final CaptureEvent teacher;

  /// The capture that has none, and would inherit it — normally the QR.
  final CaptureEvent learner;

  final int minutesApart;

  String get canonicalKey => teacher.merchantKey!;
  String get aliasKey => learner.merchantKey!;
  String? get mcc => teacher.mcc;

  /// Where it happened, for the confirmation prompt. A person recognises
  /// "Kasarvadavali, Thane" instantly and a geohash never.
  String? get place => teacher.placeLabel ?? learner.placeLabel;

  /// What the two identities look like, said plainly.
  String get teacherLabel => switch (teacher.vector) {
        CaptureVector.nfc => "the card machine you tapped",
        CaptureVector.statement => 'your bank statement',
        _ => teacher.identityLine ?? 'an earlier capture',
      };

  String get learnerLabel => learner.identityLine ?? 'this code';
}

abstract final class MerchantReconciler {
  /// How far apart two captures can be and still be one visit.
  ///
  /// Twenty minutes, not two. A tap that errors, a conversation with the
  /// cashier, then scanning the sticker instead is a completely normal sequence
  /// and it is not quick. The geohash constraint is what keeps this tight — a
  /// long window in the *same 1 km cell* is still one place.
  static const window = Duration(minutes: 20);

  /// Find links worth proposing among [events], newest-first.
  ///
  /// Returns at most one proposal per uncategorised merchant: a screen that
  /// asks the same question six times gets dismissed six times.
  static List<MerchantLinkProposal> propose(
    List<CaptureEvent> events, {
    Set<String> alreadyLinked = const {},
  }) {
    final proposals = <String, MerchantLinkProposal>{};

    for (final learner in events) {
      final learnerKey = learner.merchantKey;
      if (learnerKey == null) continue;
      if (learner.hasMcc && !learner.isUnclassified) continue;
      if (alreadyLinked.contains(learnerKey)) continue;
      if (proposals.containsKey(learnerKey)) continue;
      if (learner.geohash == null) continue;

      for (final teacher in events) {
        if (!_isCandidate(teacher: teacher, learner: learner)) continue;

        proposals[learnerKey] = MerchantLinkProposal(
          teacher: teacher,
          learner: learner,
          minutesApart:
              teacher.capturedAt.difference(learner.capturedAt).inMinutes.abs(),
        );
        break;
      }
    }

    return proposals.values.toList();
  }

  static bool _isCandidate({
    required CaptureEvent teacher,
    required CaptureEvent learner,
  }) {
    final teacherKey = teacher.merchantKey;
    if (teacherKey == null || teacherKey == learner.merchantKey) return false;

    // 4 — complementary. Only a capture with a real category can teach.
    if (!teacher.hasMcc || teacher.isUnclassified) return false;

    // 1 — same place. No location, no proposal: without it this would be
    // "two captures near each other in time", which across a shopping street
    // is simply false.
    if (teacher.geohash == null || teacher.geohash != learner.geohash) {
      return false;
    }

    // 2 — same visit.
    final apart = teacher.capturedAt.difference(learner.capturedAt).abs();
    if (apart > window) return false;

    // 3 — different identity spaces. Two `upi:` keys in one cell are two shops
    // in a market, not one shop twice.
    return _space(teacherKey) != _space(learner.merchantKey!);
  }

  static String _space(String key) {
    final i = key.indexOf(':');
    return i <= 0 ? key : key.substring(0, i);
  }
}
