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
      style: style.copyWith(color: SwipColors.goldInk),
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
    this.onInk = false,
  });

  final MccConfidence confidence;

  /// Shown as "· 47 captures" when the value came from the merchant graph.
  final int? captureCount;
  final bool compact;

  /// Set on the black hero card, where the light-surface colours would vanish.
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    // On Ink the light-surface greens and ambers drop below AA, so each has a
    // named counterpart. Lerping toward white would also clear AA, but it
    // desaturates — verified lands on a sage that stops reading as *green*.
    final (color, label) = switch ((confidence, onInk)) {
      (MccConfidence.verified, false) => (SwipConfidenceColors.verified, 'Verified'),
      (MccConfidence.verified, true) => (SwipConfidenceColors.verifiedOnInk, 'Verified'),
      (MccConfidence.likely, false) => (SwipConfidenceColors.likely, 'Likely'),
      (MccConfidence.likely, true) => (SwipConfidenceColors.likelyOnInk, 'Likely'),
      (MccConfidence.unknown, false) => (SwipConfidenceColors.unknown, 'Unknown'),
      (MccConfidence.unknown, true) => (SwipConfidenceColors.unknownOnInk, 'Unknown'),
      (MccConfidence.conflict, false) => (SwipConfidenceColors.conflict, 'Conflicting'),
      (MccConfidence.conflict, true) => (SwipConfidenceColors.conflictOnInk, 'Conflicting'),
    };
    final fg = color;

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
  const PublicationChips(this.publications, {super.key, this.onInk = false});

  final Set<MccPublication> publications;
  final bool onInk;

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
    final (border, text) = switch (p) {
      MccPublication.national => (SwipColors.ink200, SwipColors.ink700),
      MccPublication.international => (SwipColors.info, SwipColors.info),
      MccPublication.rupay => (SwipColors.gold700, SwipColors.goldInk),
    };

    final b = onInk ? SwipColors.ink500 : border;
    final t = onInk ? SwipColors.ink200 : text;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SwipSpace.sm - 2, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: SwipRadius.chipAll,
        border: Border.all(color: b, width: 1),
      ),
      child: Text(p.label, style: SwipType.labelS.copyWith(color: t)),
    );
  }
}
