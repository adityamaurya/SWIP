import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/swip_tokens.dart';
import '../data/models/capture_event.dart';
import '../data/models/mcc.dart';

/// `F-61` — the condensed detection card.
///
/// ## Why the modal was wrong
///
/// A full-height bottom sheet is the correct answer to *a scan you asked for*.
/// It is the wrong answer to *ambient scanning you did not*. With the camera
/// always looking, the sheet fired on every code that drifted through frame,
/// covered the viewfinder, and had to be dismissed before the next one — which
/// is exactly the frustration you hit.
///
/// The research agrees: modals are the most interrupting pattern available, and
/// lighter in-place responses are dramatically less disruptive. See
/// `docs/22-FEEDBACK-ROUND-3.md` for the sources.
///
/// So the rule is now:
///
///   * **ambient scan** (dashboard viewfinder) → this card, quiet, in place
///   * **deliberate scan** (full-screen scanner, tap, link, share) → full sheet
///
/// ## What it shows, in your order
///
///   the MCC · the merchant · the universal MCC description · how it was
///   detected · a chevron to open the full sheet
class ScanFlashCard extends StatelessWidget {
  const ScanFlashCard({
    super.key,
    required this.event,
    required this.mcc,
    this.onExpand,
    this.onDismiss,
  });

  final CaptureEvent event;
  final Mcc? mcc;

  /// The chevron. Opens the full sheet — everything the old modal showed.
  final VoidCallback? onExpand;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final known = event.hasMcc;

    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onDismiss?.call(),
      child: Material(
        color: SwipColors.surfaceRaised,
        borderRadius: SwipRadius.cardAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onExpand,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: SwipRadius.cardAll,
              border: Border.all(
                color: known ? SwipColors.gold700 : SwipColors.hairline,
              ),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: SwipSpace.md, vertical: SwipSpace.md),
            child: Row(
              children: [
                // ── the code ──
                SizedBox(
                  width: 62,
                  child: Text(
                    event.mcc ?? '—',
                    style: SwipType.mcc.copyWith(
                      fontSize: 24,
                      height: 1.1,
                      color: known
                          ? SwipColors.gold500
                          : SwipColors.textTertiary,
                    ),
                    semanticsLabel: known
                        ? 'Category ${event.mcc!.split('').join(' ')}'
                        : 'No category',
                  ),
                ),
                const SizedBox(width: SwipSpace.sm),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── the merchant ──
                      Text(
                        event.identityLine ?? 'Unnamed merchant',
                        style: SwipType.bodyM
                            .copyWith(color: SwipColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      // ── the universal MCC description ──
                      Text(
                        mcc?.displayName ?? event.categoryFallback,
                        style: SwipType.bodyS
                            .copyWith(color: SwipColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: SwipSpace.xs),
                      // ── how it was detected ──
                      Row(
                        children: [
                          Icon(_icon(event.vector),
                              size: 12, color: SwipColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            _how(event.vector),
                            style: SwipType.bodyS
                                .copyWith(color: SwipColors.textTertiary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── expand ──
                Icon(Icons.keyboard_arrow_up_rounded,
                    size: 22, color: SwipColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 260.ms)
        .moveY(begin: 16, curve: SwipMotion.captureCurve)
        .then(delay: 60.ms)
        .shimmer(
            duration: SwipMotion.foilSweep,
            color: known ? SwipColors.gold100 : SwipColors.hairline);
  }

  static IconData _icon(CaptureVector v) => switch (v) {
        CaptureVector.nfc => Icons.contactless_rounded,
        CaptureVector.qr => Icons.qr_code_scanner_rounded,
        CaptureVector.link => Icons.link_rounded,
        CaptureVector.intent => Icons.open_in_new_rounded,
        CaptureVector.graph => Icons.hub_outlined,
        CaptureVector.manual => Icons.edit_outlined,
        CaptureVector.probe => Icons.badge_outlined,
      };

  /// `F-61` asked for "a type of detection i.e (qr or pos detection)".
  static String _how(CaptureVector v) => switch (v) {
        CaptureVector.nfc => 'POS detection',
        CaptureVector.qr => 'QR detection',
        CaptureVector.link => 'Link, inferred',
        CaptureVector.intent => 'App hand-off',
        CaptureVector.graph => 'Already known',
        CaptureVector.manual => 'You entered it',
        CaptureVector.probe => 'Probe card',
      };
}
