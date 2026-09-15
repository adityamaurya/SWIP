import 'package:flutter/widgets.dart';

/// `F-175` — which of SWIP's two windows is this engine running in?
///
/// ## Why this exists at all
///
/// SWIP runs **two Flutter engines**, in two Android Activities, from one
/// `main()`. `MainActivity` is the app; `SwipHoverActivity` is the transparent
/// window the floating bubble opens, and they are told apart by the initial
/// route — see `hover_scan.dart` and `SwipHoverActivity.ROUTE_HOVER`.
///
/// Almost nothing needs to know the difference, and that is deliberate: the
/// hovering scanner is *the same widget* as the full-screen one, which is the
/// whole argument in `docs/32` §10 for not writing a second scanner.
///
/// But one thing does need to know. **The hover engine is not `MainActivity`'s,
/// so `MainActivity`'s method channel does not exist in it** — its handler is a
/// closure over `MainActivity` state and `MainActivity` is not on screen. NFC
/// is read entirely through that channel, so *Tap POS* cannot simply push the
/// POS screen inside the hovering card: it would come up, spin, and never hear
/// back. What it has to do there is bring the real app forward.
///
/// ## Why the route and not a global someone sets
///
/// A mutable global would have to be written before anything reads it, which
/// is one more ordering to get wrong in a process that has two entry paths.
/// `defaultRouteName` is set by the platform before Dart starts, never
/// changes, and is the same value `main()` already branches on — so there is
/// exactly one source of truth and it cannot be stale.
abstract final class SwipSurface {
  /// The initial route `SwipHoverActivity` launches with.
  ///
  /// Must match `SwipHoverActivity.ROUTE_HOVER` on the Kotlin side. If the two
  /// ever disagree the bubble silently opens the entire app inside a
  /// transparent window instead of a card.
  static const hoverRoute = '/hover';

  /// True when this engine is the hovering window over another app.
  static bool get isHoverWindow =>
      WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
          hoverRoute;
}
