import 'package:flutter/material.dart';

import '../core/theme/swip_tokens.dart';

/// `F-181` — the chrome every SWIP walkthrough shares.
///
/// ## Why this is a file rather than two copies
///
/// `F-159` built a five-screen wizard for the floating button because four
/// prerequisites and one counter-intuitive behaviour do not fit in a subtitle.
/// The merchant-name lookup has exactly the same problem — a network call, a
/// credential that can move money, and an account on somebody else's website —
/// and the owner said so plainly: *"it is not even understandable for me"*.
///
/// So there are two walkthroughs now. The second one could have copied the
/// first one's private `_Screen` and `_Progress`, and that is how a layout
/// starts to drift: the two look identical the day they are written and differ
/// by a round of polish six weeks later, on the screen nobody re-opened.
/// `CLAUDE.md` records the same lesson about the bubble's resting position,
/// where three copies of one bound disagreed ten minutes apart.
///
/// Nothing here is new behaviour. It is `F-159`'s layout, with its reasons
/// carried over intact, given a name.

/// The segmented bar at the top of every wizard screen.
///
/// It is doing real work rather than decoration: a flow that sends you into
/// Android Settings — or off to razorpay.com — feels unbounded, and people
/// abandon unbounded flows. Filled segments are a promise that this ends.
class WizardProgress extends StatelessWidget {
  const WizardProgress({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(total, (i) {
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i <= step ? SwipColors.gold500 : SwipColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      );
}

/// One screen: headline, scrollable body, and a button stuck to the bottom.
///
/// **The button does not scroll.** On a small phone with the text scale turned
/// up, a "Continue" that has scrolled off the end of a long explanation is a
/// flow that dead-ends, and the user has no way to know there was ever a button
/// there.
class WizardScreen extends StatelessWidget {
  const WizardScreen({
    super.key,
    required this.title,
    required this.body,
    required this.action,
    this.secondary,
  });

  final String title;

  /// Named `body` rather than `children` deliberately. `children` is a widget
  /// slot name, and the analyzer's `sort_child_properties_last` insists it be
  /// the final argument — which would put the page's content *after* the
  /// button that ends the page, in every one of these constructors. Renaming
  /// is the honest fix; suppressing the lint would not be.
  final List<Widget> body;
  final Widget action;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  SwipSpace.gutter, SwipSpace.xxl, SwipSpace.gutter, 0),
              children: [
                Text(title,
                    style: SwipType.display
                        .copyWith(color: SwipColors.textPrimary)),
                const SizedBox(height: SwipSpace.xl),
                ...body,
                const SizedBox(height: SwipSpace.xxxl),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(SwipSpace.gutter, SwipSpace.md,
                SwipSpace.gutter, SwipSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                action,
                if (secondary != null) ...[
                  const SizedBox(height: SwipSpace.sm),
                  secondary!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A numbered step whose payload can be a **picture of the control** the user
/// is about to look for.
///
/// This is the single most useful idea on page 12 of the owner's Wispr Flow
/// PDF. Written instructions make somebody parse a sentence and then search a
/// screen; a picture of the row makes them match a shape. It is the difference
/// between a flow people finish and one they abandon halfway through.
class WizardStep extends StatelessWidget {
  const WizardStep({
    super.key,
    required this.n,
    required this.text,
    this.mock,
    this.warn = false,
  });

  final int n;
  final String text;

  /// An optional mock of what they are looking for.
  final Widget? mock;

  /// A step that is a caution rather than an instruction.
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SwipSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text('$n.',
                    style: SwipType.bodyM
                        .copyWith(color: SwipColors.textSecondary)),
              ),
              Expanded(
                child: Text(
                  text,
                  style: SwipType.bodyM.copyWith(
                    color: warn ? SwipColors.danger : SwipColors.textPrimary,
                    fontWeight: warn ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
          if (mock != null)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: SwipSpace.md),
              child: mock,
            ),
        ],
      ),
    );
  }
}
