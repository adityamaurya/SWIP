import 'package:flutter/material.dart';

import '../core/theme/swip_tokens.dart';
import '../data/models/mcc.dart';

/// The MCC number.
///
/// The most-used component in the app and the thing the whole product exists to
/// show, so it has exactly one job and no options that could make it smaller,
/// dimmer, or truncated. Ideation `D-04` / `D-10`: column 1 is never truncated
/// and never behind a tap.
class MccBadge extends StatelessWidget {
  const MccBadge(this.code, {super.key, this.size = MccBadgeSize.md});

  /// `null` renders an em-dash rather than collapsing — a row with no category
  /// must still occupy its column so the ledger stays aligned.
  final String? code;
  final MccBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final style = switch (size) {
      MccBadgeSize.sm => SwipType.label,
      MccBadgeSize.md => SwipType.mcc.copyWith(fontSize: 20, height: 24 / 20),
      MccBadgeSize.lg => SwipType.mcc,
      MccBadgeSize.hero => SwipType.mcc.copyWith(fontSize: 56, height: 60 / 56),
    };

    return Text(
      code ?? '—',
      style: style.copyWith(color: SwipColors.gold500),
      // Never softWrap, never ellipsis: four digits always fit, and if they
      // ever did not that is a layout bug to fix, not to hide.
      softWrap: false,
      maxLines: 1,
      semanticsLabel: code == null
          ? 'No category code'
          : 'Category code ${code!.split('').join(' ')}',
    );
  }
}

enum MccBadgeSize { sm, md, lg, hero }

/// Confidence, as a dot **and** a word.
///
/// Never colour alone — roughly 1 in 12 men has a colour vision deficiency and
/// this audience skews heavily male. The word is not optional.
class ConfidencePill extends StatelessWidget {
  const ConfidencePill(
    this.confidence, {
    super.key,
    this.captureCount,
    this.compact = false,
  });

  final MccConfidence confidence;

  /// Shown as "· 47 captures" when the value came from the merchant graph.
  final int? captureCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Every surface in SWIP is now Ink, so the on-ink set is the only set.
    // The light-surface greens and ambers are 2-3:1 here and would vanish.
    // These are named constants rather than a lerp toward white, because
    // lerping clears AA by removing saturation — verified lands on a sage
    // that stops reading as *green*, which is the one thing colour carries.
    final (fg, label) = switch (confidence) {
      MccConfidence.verified => (SwipConfidenceColors.verifiedOnInk, 'Verified'),
      MccConfidence.likely => (SwipConfidenceColors.likelyOnInk, 'Likely'),
      MccConfidence.unknown => (SwipConfidenceColors.unknownOnInk, 'Unknown'),
      MccConfidence.conflict => (SwipConfidenceColors.conflictOnInk, 'Conflicting'),
    };

    final text = switch ((compact, captureCount)) {
      (true, _) => label,
      (false, final n?) when n > 0 => '$label · $n captures',
      _ => label,
    };

    return Semantics(
      label: 'Confidence: $text',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: SwipSpace.sm - 2),
          Text(text, style: SwipType.bodyS.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// `NATIONAL` · `INTL` · `RUPAY`.
///
/// Ideation `D-05`: ledger column 2 says where the code is published. A code can
/// be published in more than one place, so this renders a set and always in the
/// same order — a chip row that reorders itself is unreadable at a glance.
class PublicationChips extends StatelessWidget {
  const PublicationChips(this.publications, {super.key});

  final Set<MccPublication> publications;

  static const _order = [
    MccPublication.national,
    MccPublication.international,
    MccPublication.rupay,
  ];

  @override
  Widget build(BuildContext context) {
    if (publications.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: SwipSpace.xs,
      runSpacing: SwipSpace.xs,
      children: [
        for (final p in _order)
          if (publications.contains(p)) _chip(p),
      ],
    );
  }

  Widget _chip(MccPublication p) {
    // Chips are outlines, never fills — three filled chips in a ledger row
    // would out-shout the MCC, and the MCC is the point of the screen.
    final (border, text) = switch (p) {
      MccPublication.national => (SwipColors.borderStrong, SwipColors.textSecondary),
      MccPublication.international => (SwipColors.infoOnInk, SwipColors.infoOnInk),
      MccPublication.rupay => (SwipColors.gold700, SwipColors.gold300),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SwipSpace.sm - 2, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: SwipRadius.chipAll,
        border: Border.all(color: border, width: 1),
      ),
      child: Text(p.label, style: SwipType.labelS.copyWith(color: text)),
    );
  }
}
