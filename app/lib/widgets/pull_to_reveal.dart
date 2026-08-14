import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/swip_tokens.dart';

/// `F-113` — the sign-off at the foot of the page, and the thing behind it.
///
/// ## Why the first version did nothing
///
/// It wrapped itself in a `NotificationListener<ScrollNotification>`. A
/// notification travels **up** the tree from the widget that dispatched it, so a
/// listener only ever hears its own descendants — and the scroll view here is
/// this widget's *ancestor*. It sat inside the `CustomScrollView` waiting for
/// news that could never reach it.
///
/// The listener now lives above the scroll view, in `DashboardPage`, and hands
/// the pull down as a [ValueListenable]. Same gesture, correct direction.
///
/// Two other things were needed to make an overscroll exist at all on Android:
/// the scroll view has to be scrollable even when the content fits
/// (`AlwaysScrollableScrollPhysics`), and it has to be a physics that reports
/// overscroll rather than eating it into a glow.
class PullToReveal extends StatefulWidget {
  const PullToReveal({
    super.key,
    required this.signOff,
    required this.subtitle,
    required this.hidden,
    required this.pull,
    required this.revealed,
  });

  /// The big sign-off line.
  final String signOff;

  /// The quiet line under it.
  final String subtitle;

  /// What surfaces once the pull passes the threshold.
  final Widget hidden;

  /// 0 = closed, 1 = far enough to open. Driven by the scroll view above.
  final ValueListenable<double> pull;

  final bool revealed;

  /// How far past the end of the page counts as open. About a thumb's travel:
  /// far enough that momentum never gets there by accident, close enough that a
  /// deliberate pull arrives in one movement.
  static const openAt = 96.0;

  @override
  State<PullToReveal> createState() => _PullToRevealState();
}

class _PullToRevealState extends State<PullToReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  /// `F-118`. Three phrases, and the joke is that the label keeps changing its
  /// mind the harder you pull. A static "pull to reveal" tells you what to do;
  /// this tells you that something is *happening*, which is the only thing that
  /// makes a hidden gesture worth finishing.
  String _prompt(double t) {
    if (widget.revealed) return 'THERE IT IS';
    if (t > 0.66) return 'ALMOST WORTH IT';
    if (t > 0.28) return 'KEEP GOING, IT GETS BETTER';
    return 'PULL FOR THE BIT NOBODY READS';
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: widget.pull,
        builder: (context, raw, _) {
          final t = raw.clamp(0.0, 1.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── the sign-off ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    SwipSpace.gutter, SwipSpace.colossal, SwipSpace.gutter, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.signOff,
                      style: SwipType.display.copyWith(
                        color: SwipColors.textTertiary.withValues(alpha: .55),
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: SwipSpace.md),
                    Text(
                      widget.subtitle,
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.textTertiary),
                    ),
                  ],
                ),
              ),

              // `F-119`. More room than before, so the sign-off reads as the
              // end of the page rather than as a label on the thing under it.
              const SizedBox(height: SwipSpace.giant),

              // ── the invitation ──
              Center(
                child: AnimatedBuilder(
                  animation: _bounce,
                  builder: (_, __) => Transform.translate(
                    // Stops bouncing the moment a pull starts: the hint has
                    // done its job and the gesture takes over.
                    offset: Offset(0, t > 0.02 ? 0 : _bounce.value * 6 - 3),
                    child: Column(
                      children: [
                        Icon(
                          widget.revealed
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: Color.lerp(SwipColors.textTertiary,
                              SwipColors.gold500, t),
                        ),
                        const SizedBox(height: 3),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            _prompt(t),
                            key: ValueKey(_prompt(t)),
                            textAlign: TextAlign.center,
                            style: SwipType.labelS.copyWith(
                              color: Color.lerp(SwipColors.textTertiary,
                                  SwipColors.gold500, t),
                              letterSpacing: .8 + t * 2.2,
                            ),
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
                  duration: const Duration(milliseconds: 340),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  heightFactor: widget.revealed ? 1 : t * 0.3,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 240),
                    opacity: widget.revealed ? 1 : (t * 0.55).clamp(0.0, 1.0),
                    child: widget.hidden,
                  ),
                ),
              ),

              const SizedBox(height: SwipSpace.giant),
            ],
          );
        },
      );
}

/// Drives [PullToReveal] from above the scroll view.
///
/// Owned by the page rather than the widget, because the notification has to be
/// caught by an **ancestor** of the scroll view — see the note on
/// [PullToReveal].
///
/// ## Two physics, two different notifications
///
/// A pull past the end of a list is reported in one of two entirely different
/// ways depending on the physics in force, and a controller that only listens
/// for one of them works on exactly half of the devices it is tried on:
///
/// * [ClampingScrollPhysics] (Android's default) refuses to move past the end
///   and reports the refused distance as an [OverscrollNotification].
/// * [BouncingScrollPhysics] *does* move past the end — `pixels` simply exceeds
///   `maxScrollExtent` — and so emits no overscroll at all, only ordinary
///   [ScrollUpdateNotification]s with an out-of-range metric.
///
/// Both are handled. SWIP runs bouncing physics here on purpose: the rubber
/// band is the feedback that makes a hidden gesture discoverable, and with
/// clamping physics nothing on screen moves at all while you pull.
///
/// ## Why the peak is remembered
///
/// Under bouncing physics the list springs back *before* the gesture ends, so
/// by the time [ScrollEndNotification] arrives the overshoot has already
/// decayed to zero. Deciding on the live value would mean the panel never
/// opened. [_peak] holds the furthest point reached since the drag started,
/// which is the thing the person actually did.
class PullController {
  PullController(this._onOpen);

  final VoidCallback _onOpen;

  final ValueNotifier<double> pull = ValueNotifier<double>(0);
  bool revealed = false;

  /// Furthest point reached during the current drag.
  double _peak = 0;

  void dispose() => pull.dispose();

  /// Returns false so the notification keeps bubbling: something above may
  /// still want it.
  bool onNotification(ScrollNotification n) {
    if (n is ScrollStartNotification) {
      _peak = 0;
      return false;
    }

    final m = n.metrics;

    if (n is OverscrollNotification && n.overscroll > 0) {
      _bump(pull.value + n.overscroll / PullToReveal.openAt);
    } else if (n is ScrollUpdateNotification &&
        m.hasContentDimensions &&
        m.pixels > m.maxScrollExtent) {
      _bump((m.pixels - m.maxScrollExtent) / PullToReveal.openAt);
    } else if (n is ScrollEndNotification) {
      if (_peak >= 1 && !revealed) {
        revealed = true;
        // One medium impact, at the moment it opens, once. Haptics that repeat
        // while a finger is moving read as a fault rather than a confirmation.
        HapticFeedback.mediumImpact();
        _onOpen();
      }
      // Settles fully open or fully closed. A panel left at 60 % because that
      // is where the finger lifted is not a state, it is an unfinished gesture.
      _set(revealed ? 1 : 0);
      _peak = 0;
    }
    return false;
  }

  void _bump(double v) {
    _set(v);
    if (pull.value > _peak) _peak = pull.value;
  }

  void _set(double v) {
    final next = v.clamp(0.0, 1.4);
    if ((next - pull.value).abs() < 0.004) return;
    pull.value = next;
  }
}
