import 'package:flutter/material.dart';

import '../../core/theme/swip_tokens.dart';
import 'support_goal.dart';

/// `F-120` — the goal bar. One road, two markers.
///
/// ## Why it is drawn this way
///
/// A progress bar in a donation screen is usually a guilt instrument: a long
/// empty trough with a sliver of colour at the left end, which says *look how
/// far short we are*. This one is drawn as a **gold rail that already exists**,
/// dimmed where it has not been reached yet. The road is the point; the fill is
/// just how far along it is.
///
/// The foil gradient is the same one the wordmark uses
/// ([SwipGradients.foil]), so the bar is made of the brand rather than
/// decorated with it. It is painted **across the full track** and then clipped
/// to the filled width — a gradient that restarts inside the fill would make
/// the same rupee look like a different colour depending on the total, which is
/// exactly the sort of thing this app exists to object to.
///
/// ## The marker
///
/// ₹13.5 lakh is a *notch on the rail*, not a second bar. The two figures are
/// not two goals: the first is the part that is urgent, the second is the part
/// that is long. Drawing them as two bars would say the opposite.
class GoalBar extends StatelessWidget {
  const GoalBar({super.key, this.showLegend = true});

  /// The two lines under the rail. Off inside the dashboard panel, where the
  /// story has already said both numbers in words.
  final bool showLegend;

  static const _height = 14.0;

  @override
  Widget build(BuildContext context) {
    final raised = SupportGoal.raisedFraction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── the numbers above the rail ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: ShaderMask(
                shaderCallback: (r) => SwipGradients.foil.createShader(r),
                child: Text(
                  '₹${SupportGoal.raised}',
                  style: SwipType.mcc.copyWith(
                    fontSize: 30,
                    color: SwipColors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: SwipSpace.sm),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'of ${SupportGoal.lakh(SupportGoal.goal)}',
                  style: SwipType.bodyS
                      .copyWith(color: SwipColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: SwipSpace.md),

        // ── the rail ──
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final markerX =
                (w * SupportGoal.milestoneFraction).clamp(0.0, w - 2);

            return SizedBox(
              height: _height + 22,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The rail itself, gold at 12 % — present, unreached.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      height: _height,
                      decoration: BoxDecoration(
                        borderRadius: SwipRadius.pillAll,
                        color: SwipColors.surfaceRaised2,
                        border: Border.all(color: SwipColors.gold900),
                      ),
                      child: ClipRRect(
                        borderRadius: SwipRadius.pillAll,
                        child: Opacity(
                          opacity: .12,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                                gradient: SwipGradients.foil),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // What has come in. Animated so that the day this stops
                  // being zero, it *arrives* rather than appearing.
                  Positioned(
                    left: 0,
                    top: 0,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: raised),
                      duration: const Duration(milliseconds: 900),
                      curve: SwipMotion.captureCurve,
                      builder: (_, t, __) => ClipRRect(
                        borderRadius: SwipRadius.pillAll,
                        child: SizedBox(
                          height: _height,
                          width: w * t,
                          // The shader spans the whole rail, then gets cut to
                          // the filled width - see the class note.
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            maxWidth: w,
                            minWidth: w,
                            child: Container(
                              height: _height,
                              decoration: const BoxDecoration(
                                  gradient: SwipGradients.foil),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // The ₹13.5 lakh notch.
                  Positioned(
                    left: markerX - 1,
                    top: -3,
                    child: Container(
                      width: 3,
                      height: _height + 6,
                      decoration: BoxDecoration(
                        color: SwipColors.gold300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _height + 7,
                    child: Row(
                      children: [
                        SizedBox(width: (markerX - 30).clamp(0.0, w)),
                        Flexible(
                          child: Text(
                            SupportGoal.lakh(SupportGoal.milestone),
                            style: SwipType.labelS
                                .copyWith(color: SwipColors.gold300),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        if (showLegend) ...[
          const SizedBox(height: SwipSpace.md),
          _Legend(
            colour: SwipColors.gold300,
            text: 'First: clear ${SupportGoal.lakh(SupportGoal.milestone)} '
                'of debt',
            strong: true,
          ),
          const SizedBox(height: SwipSpace.xs),
          _Legend(
            colour: SwipColors.gold900,
            text: 'Then: earn back ${SupportGoal.lakh(SupportGoal.goal)}',
            strong: false,
          ),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.colour,
    required this.text,
    required this.strong,
  });

  final Color colour;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: SwipSpace.sm),
          Expanded(
            child: Text(
              text,
              style: SwipType.bodyS.copyWith(
                color: strong
                    ? SwipColors.textSecondary
                    : SwipColors.textTertiary,
              ),
            ),
          ),
        ],
      );
}
