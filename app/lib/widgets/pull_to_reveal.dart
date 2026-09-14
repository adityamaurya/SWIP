// `ValueNotifier` arrives with `material.dart`; **`ValueListenable` does not.**
// `widgets.dart` re-exports `foundation.dart` through a `show` clause, and the
// read-only half of the pair is not on that list - so the type used in the
// public API here has to be imported directly. Discovered the only way it can
// be: the build failed on the one line that names it.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
    this.onTapReveal,
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

  /// `F-129`. Tapping the chevron opens the same panel the pull does.
  final VoidCallback? onTapReveal;

  /// How far past the end of the page counts as open. About a thumb's travel:
  /// far enough that momentum never gets there by accident, close enough that a
  /// deliberate pull arrives in one movement.
  static const openAt = 96.0;

  @override
  State<PullToReveal> createState() => _PullToRevealState();
}

class _PullToRevealState extends State<PullToReveal>
    with SingleTickerProviderStateMixin {
  /// `F-151` — **the hint breathes a few times and then stops.**
  ///
  /// > *"It's not fluid enough."*
  ///
  /// This used to be `repeat(reverse: true)` with no end, and
  /// `docs/33` §3.4 already called it out: the references — Ramp, CRED's
  /// Circle — share one habit worth stealing, which is that *nothing moves
  /// unless it is telling you something changed*. A chevron that bobs forever
  /// at the foot of the page is not an invitation after the first few seconds;
  /// it is a thing twitching on screen while you try to read the paragraph
  /// above it, and the eye starts reading it as a fault.
  ///
  /// Six cycles is about seven seconds — long enough to be noticed on the way
  /// down the page, short enough that it is still by the time anyone settles.
  /// It restarts whenever the page is scrolled back to the foot, so somebody
  /// who returns looking for it is shown it again.
  static const _hintCycles = 6;

  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  int _cyclesRun = 0;
  double _wasAtRest = 0;

  // ───────────────────────────────────────────────────────────────────────
  // `F-152` — **the red panel the owner actually photographed.**
  // ───────────────────────────────────────────────────────────────────────
  //
  // ```text
  // Duplicate keys found.
  // Stack(alignment: Alignment.center, fit: loose) has multiple children
  // with key [<[<[<'PULL FOR THE BIT NOBODY READS'>]>]>].
  // ```
  //
  // `F-141` fixed a *different* red panel ("Build scheduled during frame")
  // and I reported that as the one in the screenshots. It was not. This is,
  // and it is worse: the exception is thrown while building a sliver, which
  // takes the whole `CustomScrollView` down with it — so the dashboard does
  // not merely show a red box, it **goes black**. Three pages of the PDF show
  // exactly that, and the black screen has been on the open list for rounds
  // as if it were unrelated.
  //
  // ## The mechanism
  //
  // The prompt label sat in an `AnimatedSwitcher` keyed on its own text:
  //
  // ```dart
  // AnimatedSwitcher(child: Text(_prompt(t), key: ValueKey(_prompt(t))))
  // ```
  //
  // An `AnimatedSwitcher` keeps the outgoing child alive in a `Stack` for the
  // length of its transition. `t` is the live rubber-band value, and a
  // bouncing overscroll **oscillates** — 0.35, 0.10, 0.40, 0.05 — crossing the
  // 0.28 boundary several times inside one 180 ms transition. So the text goes
  // A → B → A while the first A is still fading out, and the Stack ends up
  // holding two children with the identical key. Flutter asserts.
  //
  // ## The fix, which is two things and both of them are needed
  //
  // 1. **Hysteresis on the stage.** A label driven directly off a jittery
  //    continuous value flickers, and flicker is the actual user-visible
  //    defect — the crash is just what flicker does when it meets a keyed
  //    switcher. A stage now has to be *left* by a wider margin than it was
  //    entered by, so the rubber band settling does not strobe the copy.
  //
  // 2. **A key that is never reused.** `_promptSeq` increments on every real
  //    stage change and never goes back, so two children cannot share a key
  //    even if the stage somehow changes twice in one frame. Hysteresis alone
  //    would make this rare rather than impossible, and "rare" is what let it
  //    ship.
  //
  // The stage is computed in a listener rather than in `build`, because
  // deciding it during build would mean mutating state during build — which is
  // how `F-141` happened.

  /// How far in you must go to enter each stage, and how far back you must
  /// come to leave it. The gap between the two is the hysteresis.
  static const _enter = <double>[0.28, 0.66];
  static const _leave = <double>[0.18, 0.54];

  int _stage = 0;
  int _promptSeq = 0;

  @override
  void initState() {
    super.initState();
    _bounce.addStatusListener(_countCycles);
    widget.pull.addListener(_onPull);
    _breathe();
  }

  @override
  void didUpdateWidget(PullToReveal old) {
    super.didUpdateWidget(old);
    if (old.pull != widget.pull) {
      old.pull.removeListener(_onPull);
      widget.pull.addListener(_onPull);
    }
  }

  /// Decide the stage, with hysteresis, off the live pull value.
  void _onPull() {
    final t = widget.pull.value.clamp(0.0, 1.0);

    var next = _stage;
    // Climbing: cross the entry threshold of the stage above.
    while (next < _enter.length && t > _enter[next]) {
      next++;
    }
    // Falling: drop below the *lower* exit threshold of the current stage.
    while (next > 0 && t < _leave[next - 1]) {
      next--;
    }

    if (next == _stage) return;
    setState(() {
      _stage = next;
      // Monotonic. Never returns to a value it has already used.
      _promptSeq++;
    });
  }

  void _countCycles(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    _cyclesRun++;
    if (_cyclesRun < _hintCycles && mounted) _bounce.forward();
  }

  void _breathe() {
    _cyclesRun = 0;
    if (mounted) _bounce.repeat(reverse: true, count: _hintCycles);
  }

  @override
  void dispose() {
    widget.pull.removeListener(_onPull);
    _bounce.removeStatusListener(_countCycles);
    _bounce.dispose();
    super.dispose();
  }

  /// Restart the hint when the reader comes back to the foot of the page after
  /// having been away from it. Without this the animation is a one-time event
  /// that most people scroll straight past on their first visit and never see
  /// again.
  void _maybeBreatheAgain(double t) {
    final atRest = t <= 0.001;
    if (atRest && _wasAtRest > 0.08 && !widget.revealed) {
      // Came back down from a partial pull. They were looking for it.
      _breathe();
    }
    _wasAtRest = t;
  }

  /// `F-118`. Three phrases, and the joke is that the label keeps changing its
  /// mind the harder you pull. A static "pull to reveal" tells you what to do;
  /// this tells you that something is *happening*, which is the only thing that
  /// makes a hidden gesture worth finishing.
  ///
  /// `F-152`. Reads the **stage**, not the raw value. The thresholds live in
  /// [_enter] / [_leave] so that entering and leaving a phrase are different
  /// distances and the label cannot strobe while the band settles.
  String get _prompt {
    if (widget.revealed) return 'THERE IT IS';
    return switch (_stage) {
      >= 2 => 'ALMOST WORTH IT',
      1 => 'KEEP GOING, IT GETS BETTER',
      _ => 'PULL OR TAP FOR THE BIT NOBODY READS',
    };
  }

  /// `F-152`. The switcher's key. Monotonic, so no two children in its
  /// `Stack` can ever collide — which is the assertion that was black-screening
  /// the dashboard.
  ///
  /// `revealed` is folded in because it changes the text without going
  /// through [_onPull].
  ValueKey<String> get _promptKey => ValueKey('$_promptSeq/${widget.revealed}');

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: widget.pull,
        builder: (context, raw, _) {
          final t = raw.clamp(0.0, 1.0);
          _maybeBreatheAgain(t);

          // `F-151`. How far past the threshold the finger has gone, 0..1.
          // The rubber band keeps reporting past 1.0 (the controller clamps at
          // 1.4), and that overshoot is the only signal available for "you can
          // let go now" — so it is spent on the one thing that says it.
          final over = ((raw - 1.0) / 0.4).clamp(0.0, 1.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── the sign-off ──
              //
              // `F-151`. It lifts very slightly and fades as the panel comes
              // up, so the page reads as one thing making room for another
              // rather than two things stacked. Eight pixels: enough that the
              // eye registers the hand-off, not enough to be a movement
              // anybody would describe.
              Transform.translate(
                offset: Offset(0, -8 * t),
                child: Opacity(
                  opacity: 1 - 0.35 * t,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(SwipSpace.gutter,
                        SwipSpace.colossal, SwipSpace.gutter, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.signOff,
                          style: SwipType.display.copyWith(
                            color:
                                SwipColors.textTertiary.withValues(alpha: .55),
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
                ),
              ),

              // `F-119`. More room than before, so the sign-off reads as the
              // end of the page rather than as a label on the thing under it.
              const SizedBox(height: SwipSpace.giant),

              // ── the invitation ──
              //
              // `F-129`. **Tap works too, and that is not a concession.**
              //
              // This gesture has been reported broken twice. The first time it
              // genuinely was; the second time the fix had shipped but had not
              // reached the phone. Either way the lesson is the same: a reveal
              // that can *only* be reached by a gesture nobody can see has no
              // way of telling you whether it is broken or merely undiscovered.
              // A tap target removes that ambiguity for good, and costs the
              // Easter egg nothing - you still have to be at the foot of the
              // page to find it.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTapReveal,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _bounce,
                    builder: (_, __) => Transform.translate(
                      // Stops bouncing the moment a pull starts: the hint has
                      // done its job and the gesture takes over.
                      offset: Offset(0, t > 0.02 ? 0 : _bounce.value * 6 - 3),
                      child: Column(
                        children: [
                          // `F-151`. The chevron carries the "you can let go
                          // now" signal, and it carries it two ways at once:
                          // it darkens with the pull, and it **rotates to
                          // point the other way** across the last stretch of
                          // overshoot.
                          //
                          // The rotation is what makes the threshold legible.
                          // Colour alone is a gradient with no edge in it —
                          // you cannot tell from a slightly darker grey
                          // whether you have gone far enough. A chevron that
                          // has visibly turned over has crossed something.
                          Transform.rotate(
                            angle: math.pi * (widget.revealed ? 1 : over),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 22 + 4 * over,
                              color: Color.lerp(SwipColors.textTertiary,
                                  SwipColors.gold500, t),
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              _prompt,
                              key: _promptKey,
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
              ),

              // ── what is behind it ──
              // `F-151` — **what makes this feel like a spring rather than a
              // drawer.**
              //
              // Two changes, and the second is the one that matters.
              //
              // The curve is `easeOutBack`, not `easeOutCubic`. It overshoots
              // slightly and settles, which is what a physical panel released
              // under tension does — and this panel is literally being
              // released from tension, so the motion is describing the gesture
              // that caused it rather than decorating it. `easeOutCubic`
              // decelerates into place like a drawer closing, which is the
              // right curve for a thing that was pushed and the wrong one for
              // a thing that was pulled.
              //
              // And the opening is **slower than the closing**: 420 ms out,
              // 260 ms back. Asymmetry is not a detail here. Opening is the
              // payoff and wants to be watched; closing is dismissal and
              // wants to be over. Matching the two makes the open feel
              // hurried and the close feel reluctant, which is exactly
              // backwards, and is most of what "not fluid enough" describes.
              ClipRect(
                child: AnimatedAlign(
                  duration: Duration(milliseconds: widget.revealed ? 420 : 260),
                  curve: widget.revealed
                      ? Curves.easeOutBack
                      : Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  heightFactor: widget.revealed ? 1 : t * 0.3,
                  child: AnimatedOpacity(
                    // Fades in over the first half of the expansion, so the
                    // content has arrived by the time the panel stops moving.
                    // Content that fades in after the box has settled reads as
                    // a second, slower thing happening.
                    duration:
                        Duration(milliseconds: widget.revealed ? 240 : 160),
                    curve: Curves.easeOut,
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

  void dispose() {
    _disposed = true;
    pull.dispose();
  }

  /// `F-141` — **the red error string on the dashboard, and why it was there.**
  ///
  /// Every write this controller makes ends up calling `setState` somewhere:
  /// [pull] drives a `ValueListenableBuilder`, and [_onOpen] is the page's own
  /// `setState`. That is fine when the write is caused by a finger, because
  /// pointer events are delivered between frames.
  ///
  /// It is **not** fine when the write is caused by the scroll view's own
  /// physics. A bouncing scroll position springs back under a ticker, which
  /// runs inside `SchedulerPhase.transientCallbacks` — i.e. during the frame.
  /// The `ScrollUpdateNotification` and `ScrollEndNotification` it emits are
  /// therefore dispatched mid-frame, and calling `setState` from there trips:
  ///
  /// ```text
  /// The following assertion was thrown while dispatching notifications for
  /// ValueNotifier<double>: Build scheduled during frame.
  /// ```
  ///
  /// In a debug build an assertion thrown while building renders as Flutter's
  /// `ErrorWidget` — **the full-width red panel of small text that was reported
  /// on the dashboard.** It is not a layout bug and not a styling bug; it is
  /// this, and it fires precisely at the end of the pull that is supposed to
  /// open the panel, which is why the gesture looked like it "broke on
  /// release".
  ///
  /// So: if the scheduler is mid-frame, do the work in a post-frame callback
  /// instead. The common case — a finger actually dragging — is
  /// `SchedulerPhase.idle` and runs inline with no added latency, so the fluid
  /// tracking of the rubber band is untouched.
  ///
  /// Reproduced by `pull_controller_test.dart`, which drags a real dashboard
  /// past the end of its scroll and asserts that nothing is thrown.
  void _safely(VoidCallback fn) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      fn();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      fn();
    });
  }

  bool _disposed = false;

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
      final opening = _peak >= 1 && !revealed;
      if (opening) revealed = true;
      final target = revealed ? 1.0 : 0.0;
      _peak = 0;
      _safely(() {
        if (opening) {
          // One medium impact, at the moment it opens, once. Haptics that
          // repeat while a finger is moving read as a fault rather than a
          // confirmation.
          HapticFeedback.mediumImpact();
          _onOpen();
        }
        // Settles fully open or fully closed. A panel left at 60 % because
        // that is where the finger lifted is not a state, it is an unfinished
        // gesture.
        _set(target);
      });
    }
    return false;
  }

  /// `F-129`. Open it without a gesture. Same state, same haptic, same
  /// callback - so the tap path and the pull path cannot drift apart.
  void openNow() {
    if (revealed) return;
    revealed = true;
    _safely(() {
      HapticFeedback.mediumImpact();
      _onOpen();
      _set(1);
    });
  }

  void _bump(double v) {
    _safely(() {
      _set(v);
      if (pull.value > _peak) _peak = pull.value;
    });
  }

  void _set(double v) {
    if (_disposed) return;
    final next = v.clamp(0.0, 1.4);
    if ((next - pull.value).abs() < 0.004) return;
    pull.value = next;
  }
}
