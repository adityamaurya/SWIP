import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/swip_tokens.dart';
import '../data/sources/merchant_reconciler.dart';

/// `F-49` — "is this the same shop?"
///
/// The one question SWIP cannot answer for itself and the user answers in a
/// second, because they were standing there.
///
/// The whole card is built to make **No** as easy as **Yes**. A prompt that
/// nudges toward confirmation gets confirmed by reflex, and a wrong link is
/// silently inherited by every future scan of that sticker — the exact failure
/// mode this app exists to remove. So: no pre-selection, no colour on the
/// affirmative, both buttons the same weight, and the evidence stated plainly
/// enough that a person can disagree with it.
class MerchantLinkCard extends StatelessWidget {
  const MerchantLinkCard({
    super.key,
    required this.proposal,
    this.onConfirm,
    this.onDismiss,
  });

  final MerchantLinkProposal proposal;
  final VoidCallback? onConfirm;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final place = proposal.place;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SwipSpace.lg),
      decoration: BoxDecoration(
        color: SwipColors.surfaceRaised,
        borderRadius: SwipRadius.cardAll,
        border: Border.all(color: SwipColors.gold700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.hub_outlined, size: 18, color: SwipColors.gold500),
            const SizedBox(width: SwipSpace.sm),
            Text('SAME SHOP?',
                style:
                    SwipType.labelS.copyWith(color: SwipColors.gold500)),
          ]),
          const SizedBox(height: SwipSpace.md),

          Text(
            'You read ${proposal.mcc} from ${proposal.teacherLabel}'
            '${place == null ? '' : ' in $place'}, and scanned '
            '${proposal.learnerLabel} '
            '${proposal.minutesApart == 0 ? 'moments' : '${proposal.minutesApart} min'} '
            'later in the same place.',
            style: SwipType.bodyM.copyWith(color: SwipColors.textPrimary),
          ),
          const SizedBox(height: SwipSpace.sm),
          Text(
            'If they are the same shop, SWIP will remember that code for this '
            'QR — and every time anyone scans it.',
            style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
          ),

          const SizedBox(height: SwipSpace.lg),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onDismiss,
                child: const Text('Different shops'),
              ),
            ),
            const SizedBox(width: SwipSpace.md),
            Expanded(
              child: OutlinedButton(
                onPressed: onConfirm,
                child: const Text('Same shop'),
              ),
            ),
          ]),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 320.ms)
        .moveY(begin: 12, curve: SwipMotion.captureCurve);
  }
}
