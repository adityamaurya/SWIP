import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/swip_tokens.dart';

/// `F-113` — the thing at the bottom of the page, and the thing behind it.
///
/// ## Two parts, one gesture
///
/// **The sign-off.** Big, low-contrast type at the foot of a scroll: the
/// pattern Blinkit, Swiggy and Zomato all end on. It is not decoration — it is
/// how a page says *this is the end*, so the reader stops hunting for more. It
/// is set at display weight in a colour barely above the background, because
/// the whole effect depends on it being felt rather than read.
///
/// **The Easter egg.** Keep pulling past it and a second thing surfaces. It is
/// deliberately not discoverable by tapping: the only way in is to reach the
/// bottom and keep going, which means the people who find it are the people who
/// were already curious.
///
/// ## The mechanics
///
/// A physical overscroll is not available here — the page is a
/// `CustomScrollView` whose extent ends — so the reveal reads
/// `ScrollNotification` overscroll and drives the panel from it directly. The
/// chevron bounces continuously to advertise that there *is* somewhere to go,
/// and the copy stretches as you pull, so the gesture reports its own progress.
///
/// One [HapticFeedback.mediumImpact] fires at the moment it opens, once, and
/// never again until it has closed. Haptics that repeat while a finger is
/// moving feel like a fault rather than a confirmation.
class PullToReveal extends StatefulWidget {
  const PullToReveal({
    super.key,
    required this.signOff,
    required this.subtitle,
    required this.hidden,
  });

  /// The big sign-off line. Two or three words.
  final String signOff;

  /// The quiet line under it.
  final String subtitle;

  /// What surfaces once the pull passes [_openAt].
  final Widget hidden;

  @override
  State<PullToReveal> createState() => _PullToRevealState();
}

class _PullToRevealState extends State<PullToReveal>
    with SingleTickerProviderStateMixin {
  /// 0 = closed, 1 = fully pulled. Driven straight off overscroll pixels.
  double _pull = 0;
  bool _open = false;

  /// How far past the end of the page counts as "open". 92 logical pixels is
  /// about a thumb's travel — far enough that nobody arrives here by momentum,
  /// close enough that a deliberate pull gets there in one movement.
  static const _openAt = 92.0;

  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  bool _onNotification(ScrollNotification n) {
    if (n is OverscrollNotification && n.overscroll > 0) {
      _set((_pull + n.overscroll / _openAt).clamp(0.0, 1.6));
    } else if (n is ScrollUpdateNotification && _pull > 0) {
      final d = n.scrollDelta ?? 0;
      if (d < 0) _set((_pull + d / _openAt).clamp(0.0, 1.6));
    } else if (n is ScrollEndNotification) {
      if (_pull >= 1 && !_open) {
        _open = true;
        HapticFeedback.mediumImpact();
      }
      // Settles to either fully open or fully closed. A panel left at 60 %
      // because that is where the finger lifted is not a state, it is a
      // half-finished gesture.
      _set(_open ? 1 : 0);
    }
    return false;
  }

  void _set(double v) {
    if ((v - _pull).abs() < 0.005) return;
    setState(() => _pull = v);
    if (_pull <= 0.02) _open = false;
  }

  /// `F-113`. The word stretches as you pull, the way the scan stack's
  /// "vieeeew older scans" did. Same joke, better home for it.
  String get _prompt {
    if (_open) return 'LET GO';
    final e = (_pull * 5).round().clamp(0, 6);
    return 'PU${'L' * (2 + e)} TO REVEAL';
  }

  @override
  Widget build(BuildContext context) {
    final t = _pull.clamp(0.0, 1.0);

    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── the sign-off ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SwipSpace.gutter, SwipSpace.giant, SwipSpace.gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.signOff,
                  style: SwipType.display.copyWith(
                    // Barely there. The line is meant to be felt at the edge of
                    // vision as you run out of page, not read.
                    color: SwipColors.textTertiary.withValues(alpha: .55),
                    height: 1.02,
                  ),
                ),
                const SizedBox(height: SwipSpace.sm),
                Text(
                  widget.subtitle,
                  style: SwipType.bodyS
                      .copyWith(color: SwipColors.textTertiary),
                ),
              ],
            ),
          ),

          const SizedBox(height: SwipSpace.xl),

          // ── the invitation ──
          Center(
            child: AnimatedBuilder(
              animation: _bounce,
              builder: (_, __) => Transform.translate(
                // Stops bouncing the moment a pull begins: the hint has done
                // its job and the gesture takes over.
                offset: Offset(0, t > 0.02 ? 0 : _bounce.value * 5 - 2.5),
                child: Column(
                  children: [
                    Icon(
                      _open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Color.lerp(SwipColors.textTertiary,
                          SwipColors.gold500, t),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _prompt,
                      style: SwipType.labelS.copyWith(
                        color: Color.lerp(SwipColors.textTertiary,
                            SwipColors.gold500, t),
                        letterSpacing: .8 + t * 2.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── what is behind it ──
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: _open ? 1 : t * 0.35,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _open ? 1 : (t * 0.5).clamp(0.0, 1.0),
                child: widget.hidden,
              ),
            ),
          ),

          const SizedBox(height: SwipSpace.xxxl),
        ],
      ),
    );
  }
}
