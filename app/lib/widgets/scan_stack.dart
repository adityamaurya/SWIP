import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/swip_tokens.dart';
import '../data/models/capture_event.dart';
import '../data/models/mcc.dart';
import 'scan_flash_card.dart';

/// `F-62` — the stack of recent scans, docked at the bottom of the screen.
///
/// ## The reference, taken properly this time
///
/// Apple's collapsed music player is *one* bar. It never becomes a carousel of
/// equals, it never shows you a page indicator, and it never asks you to swipe
/// sideways to find out what is behind it. It is one thing, in one place, with
/// the implication of more.
///
/// The first build of this used a `PageView`, which made every card an equal
/// citizen competing for the same slot — a horizontal filmstrip pretending to
/// be a stack. `F-79` replaces it with an actual deck:
///
///   * The newest capture is the **front card**, full size and full contrast.
///   * Up to two cards behind it are drawn **inset and shorter**, peeking above
///     the front card's top edge, dimmed. They are depth, not content — they
///     are `IgnorePointer`ed so no tap can ever land on a card you cannot read.
///   * Flicking the front card sideways dismisses it and the next one rises.
///
/// The count moves onto the front card's own line rather than a caption below,
/// because a line of text under a floating bar is one more thing to lay out
/// over content that is already there.
///
/// ## Height
///
/// Fixed, and derived from [ScanFlashCard.height] plus the peek, rather than a
/// hand-tuned number. The hand-tuned number is what overflowed by four pixels.
class ScanStack extends StatelessWidget {
  const ScanStack({
    super.key,
    required this.events,
    required this.mccFor,
    this.onExpand,
    this.onDismiss,
    this.onOpenLedger,
  });

  /// Newest first. The caller prunes by age; this only renders.
  final List<CaptureEvent> events;
  final Mcc? Function(String? code) mccFor;

  final void Function(CaptureEvent)? onExpand;
  final void Function(CaptureEvent)? onDismiss;

  /// Where "see the rest" ends up.
  final VoidCallback? onOpenLedger;

  /// How many cards are drawn behind the front one.
  static const _behind = 2;

  /// Vertical offset per card behind. Small: this is a hint of depth, not a
  /// fan of playing cards.
  static const _peek = 7.0;

  /// How much narrower each card behind is, per step.
  static const _inset = 14.0;

  static const _height = ScanFlashCard.height + _peek * _behind;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final depth = events.length.clamp(1, _behind + 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // `F-80`. The count, and the way to everything older. It sits above the
        // deck as one quiet line — the pull-string gesture it replaces was
        // charming and undiscoverable, and it fought the page's own scrolling.
        if (events.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: SwipSpace.xs),
            child: GestureDetector(
              onTap: onOpenLedger,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${events.length} just now',
                    style: SwipType.labelS
                        .copyWith(color: SwipColors.textTertiary),
                  ),
                  const SizedBox(width: SwipSpace.xs),
                  Text(
                    'See all',
                    style:
                        SwipType.labelS.copyWith(color: SwipColors.gold500),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 14, color: SwipColors.gold500),
                ],
              ),
            ),
          ),

        SizedBox(
          height: _height,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Back to front, so the newest ends up on top of the pile.
              for (var i = depth - 1; i >= 0; i--)
                Positioned(
                  left: _inset * i,
                  right: _inset * i,
                  bottom: 0,
                  // Cards behind are pushed *up*, so they peek out of the top
                  // edge. Downwards would bury them under the navigation bar.
                  child: Padding(
                    padding: EdgeInsets.only(bottom: _peek * i),
                    child: Opacity(
                      opacity: i == 0 ? 1 : (i == 1 ? .55 : .3),
                      child: ScanFlashCard(
                        key: ValueKey(events[i].id),
                        event: events[i],
                        mcc: mccFor(events[i].mcc),
                        dimmed: i != 0,
                        onExpand: () => onExpand?.call(events[i]),
                        onDismiss: () => onDismiss?.call(events[i]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 240.ms).moveY(begin: 24, end: 0);
  }
}
