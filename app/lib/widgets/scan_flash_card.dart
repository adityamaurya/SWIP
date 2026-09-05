import 'package:flutter/material.dart';

import '../core/theme/swip_tokens.dart';
import '../data/models/capture_event.dart';
import '../data/models/mcc.dart';
import 'ledger_row.dart' show VectorTag;
import 'mcc_badge.dart';

/// `F-61` — the condensed detection card.
///
/// ## Why the modal was wrong
///
/// A full-height bottom sheet is the correct answer to *a scan you asked for*.
/// It is the wrong answer to *ambient scanning you did not*. With the camera
/// always looking, the sheet fired on every code that drifted through frame,
/// covered the viewfinder, and had to be dismissed before the next one.
///
/// So the rule is:
///
///   * **ambient scan** (dashboard viewfinder) → this card, quiet, in place
///   * **deliberate scan** (full-screen scanner, tap, link, share) → full sheet
///
/// ## The fixed height, and why it is not a suggestion
///
/// `F-78`. This card lives inside a stack of a fixed height, over the top of
/// the dashboard. When its content grew a third line it overflowed by four
/// pixels and Flutter painted the yellow-and-black hazard bars across it — on
/// the one surface in the app that is supposed to be reassuring.
///
/// It is now a strict two-line card with a fixed [height], and everything that
/// used to be a third line is a compact tag on the right. Two lines is also
/// simply the right amount: the merchant and what it is. Anything more is what
/// the chevron is for.
class ScanFlashCard extends StatelessWidget {
  const ScanFlashCard({
    super.key,
    required this.event,
    required this.mcc,
    this.onExpand,
    this.onDismiss,
    this.dimmed = false,
  });

  final CaptureEvent event;
  final Mcc? mcc;

  /// Tap anywhere. Opens the full sheet — everything the old modal showed.
  final VoidCallback? onExpand;
  final VoidCallback? onDismiss;

  /// True for the cards *behind* the front one in the stack. They are scenery:
  /// they show there is more, they are not meant to be read.
  final bool dimmed;

  /// The one number the stack's geometry is built on. Fixed on purpose — see
  /// the note above about the four pixels.
  static const height = 72.0;

  @override
  Widget build(BuildContext context) {
    final known = event.hasMcc;

    final card = Container(
      height: height,
      decoration: BoxDecoration(
        color: SwipColors.surfaceRaised,
        borderRadius: SwipRadius.cardAll,
        border: Border.all(
          color: known ? SwipColors.gold700 : SwipColors.hairline,
        ),
        boxShadow: dimmed ? null : SwipElevation.e3,
      ),
      padding: const EdgeInsets.symmetric(horizontal: SwipSpace.md),
      child: Row(
        children: [
          // ── the code ── `F-76`: `NA`, never a dash.
          //
          // `F-133`. **This was cropping the fourth digit.** It was
          // `SizedBox(width: 46)`, and four digits of `SwipType.mcc` at 20 px
          // in Inter w700 measure about 49 px — so `5085` rendered as `508`
          // plus a sliver, on the one card whose entire job is to show four
          // digits.
          //
          // A fixed width was the wrong tool for a column that must **align**
          // across stacked cards: the alignment needs a *minimum*, not a
          // maximum. `minWidth` keeps the column straight, `scaleDown` handles
          // the reader who has text size turned up, and neither can clip.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 52),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MccBadge(event.mcc, size: MccBadgeSize.md),
            ),
          ),
          const SizedBox(width: SwipSpace.sm),

          // ── who, and what kind of place ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.identityLine ?? 'Unnamed merchant',
                  style:
                      SwipType.bodyM.copyWith(color: SwipColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  mcc?.displayName ?? event.categoryFallback,
                  style:
                      SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: SwipSpace.sm),

          // ── how it was read, then the way in ──
          VectorTag(event.vector),
          const Icon(Icons.keyboard_arrow_up_rounded,
              size: 22, color: SwipColors.textSecondary),
        ],
      ),
    );

    if (dimmed) return IgnorePointer(child: card);

    return Dismissible(
      key: ValueKey(event.id),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onDismiss?.call(),
      // The ink goes *over* the card rather than under it. A `Material` beneath
      // an opaque `Container` swallows its own ripple, which is how a control
      // ends up feeling dead even though the tap registers.
      child: Stack(
        children: [
          card,
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              borderRadius: SwipRadius.cardAll,
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onExpand),
            ),
          ),
        ],
      ),
    );
  }
}
