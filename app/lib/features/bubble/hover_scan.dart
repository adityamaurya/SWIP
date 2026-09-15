import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/runtime/surface.dart';
import '../../core/theme/swip_palette.dart';
import '../../core/theme/swip_theme.dart';
import '../../core/theme/swip_tokens.dart';
import '../../core/theme/theme_setting.dart';
import '../capture_qr/scan_page.dart';

/// `F-163` — **the scanner, hovering over whatever you are in.**
///
/// > *"can we get a hovering window on tap of this widget accessible anywhere
/// > everywhere and same camera window of the dashboard visible on the tap of
/// > the swip icon"*
///
/// This is step 4 of [`docs/32`](../../../../docs/32-FLOATING-BUBBLE.md), and
/// until now tapping the bubble opened SWIP full-screen — you left the app you
/// were in, which is the one thing the bubble exists to avoid.
///
/// ## The design, and why it is not the one `docs/32` §3 describes
///
/// That section proposed CameraX and ML Kit drawn into a **second overlay
/// window**, native, alongside the bubble. `F-161` removed the blocker that was
/// stopping it — `bootstrap.sh` now keeps Gradle dependencies — so it was
/// buildable. It is still not what this does, for a reason that matters more
/// than the blocker did:
///
/// **A native overlay scanner would be a second implementation of scanning.**
/// SWIP's scanner is not a camera and a barcode library. It is
/// [`ScanPage`](../capture_qr/scan_page.dart) plus the aim detector, the
/// `noDuplicates` trap in `CLAUDE.md`, the resolver, the merchant graph, the
/// ledger write and the result screen — several rounds of hard-won behaviour,
/// most of it recorded in
/// [`docs/29`](../../../../docs/29-QR-DETECTION-FORENSICS.md) because it was
/// wrong first. A Kotlin twin of all that would be correct on the day it was
/// written and drift from the original by the round after.
///
/// So this hovers the **real** scanner: a transparent Activity, drawn over
/// whatever app you are in, with `ScanPage` itself inside a floating card.
/// Same camera, same detection, same resolver, same ledger, same result — one
/// implementation, because there is one.
///
/// ## What "hovering" honestly means here
///
/// The app underneath stays **visible** and is **paused**. A transparent
/// Activity does not stop the window behind it being drawn, but Android does
/// stop delivering it frames — so a video behind this will hold still.
///
/// A true overlay window would not pause it. That is the one thing this design
/// gives up, and for a two-second glance at a shop's QR while somebody waits
/// for you to pay, it is worth far less than having one scanner rather than
/// two.
///
/// ## Cost, stated plainly
///
/// This Activity runs its **own Flutter engine** — a second one, started cold
/// when the bubble is tapped. That is roughly half a second before the card
/// appears and some tens of megabytes while it is open, both of which end when
/// the window closes. Caching a warm engine would remove the delay and pay
/// that memory *the whole time the bubble is switched on*, which for a button
/// that sits idle all day is the wrong trade.
class HoverScanApp extends ConsumerWidget {
  const HoverScanApp({super.key});

  /// The initial route `SwipHoverActivity` launches with.
  ///
  /// `main()` branches on this: the same Dart entrypoint runs in both
  /// Activities, and this string is the only thing that tells them apart.
  ///
  /// `F-175`. The literal moved to [SwipSurface.hoverRoute] so that code with
  /// no business importing this feature — the capture result popup, which has
  /// to know whether *Tap POS* can push a screen or has to bring the app
  /// forward — can ask the same question without an import cycle.
  static const route = SwipSurface.hoverRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeSettingProvider);
    final platformIsDark =
        View.of(context).platformDispatcher.platformBrightness ==
            Brightness.dark;
    // Same assignment `SwipApp.build` makes, for the same reason: `SwipColors`
    // reads a global, and this engine is a different process-level tree that
    // has never run `SwipApp`.
    SwipPalette.active = choice.palette(platformIsDark: platformIsDark);

    return MaterialApp(
      key: ValueKey('hover/${SwipPalette.active.name}'),
      debugShowCheckedModeBanner: false,
      theme: SwipTheme.dark(),
      darkTheme: SwipTheme.dark(),
      themeMode: choice.themeMode,
      home: const _HoverWindow(),
    );
  }
}

class _HoverWindow extends StatelessWidget {
  const _HoverWindow();

  /// Closing means finishing the Activity, not popping a route.
  ///
  /// There is nothing beneath this in the Navigator — it *is* the root — so
  /// `Navigator.pop` would do nothing at all and the window would look stuck.
  static void _close() => SystemNavigator.pop();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final inset = MediaQuery.viewPaddingOf(context);

    // Tall enough to aim with, short enough that the app underneath is still
    // recognisable around it — which is the whole point of hovering rather
    // than taking the screen.
    final cardHeight =
        ((size.height - inset.top - inset.bottom) * 0.62).clamp(320.0, 620.0);

    return Scaffold(
      // Transparent all the way down. The Activity is translucent and Flutter
      // is in transparent mode; a `Scaffold` with its default background would
      // paint over both and there would be nothing to hover above.
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tap anywhere outside to dismiss. `behavior` is load-bearing: the
          // scrim is mostly empty space, and without `opaque` a tap on a
          // transparent pixel falls through to the app underneath — which
          // would be a tap the user did not intend to send to someone else's
          // checkout.
          Positioned.fill(
            // `F-177`. The dim arrives, it does not slam.
            //
            // > *"no obvious bottom-to-top shadow animation… no feeling that a
            // > separate app/window is opening"*
            //
            // Two separate things were producing that. The **system's**
            // activity-open transition — a bottom-up slide with a dim, which
            // is what an app opening looks like because it is literally what
            // an app opening is — is killed in `SwipHoverActivity`;
            // `windowAnimationStyle: @null` in the theme had not been enough.
            // And SWIP's own entrance, which used to lift the card up from
            // below, is gone: see the card's own note.
            //
            // What is left is a scrim easing in over a quarter of a second.
            // Longer than the 140 ms it was, and `easeOutSine` rather than
            // linear, because a dim that reaches full strength quickly reads
            // as a shutter coming down. Slower and softer reads as a light
            // being turned down, which is the difference the owner is
            // describing.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              // `F-172`. The scrim is **SWIP's**, not the app underneath's,
              // which is the fact the chrome below depends on: this card
              // floats over an arbitrary screen, but it does not float over an
              // arbitrary *colour*, because this is painted first.
              child: ColoredBox(color: HoverChrome.scrim),
            ).animate().fadeIn(duration: 260.ms, curve: Curves.easeOutSine),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  SwipSpace.md, 0, SwipSpace.md, SwipSpace.lg + inset.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Grip(),
                  const SizedBox(height: SwipSpace.sm),
                  ClipRRect(
                    borderRadius: SwipRadius.cardAll,
                    child: SizedBox(
                      height: cardHeight,
                      width: double.infinity,
                      // The real scanner, unmodified — its own Scaffold, its
                      // own mark and torch, its own camera lifecycle, its own
                      // result route.
                      //
                      // `F-168`. Wrapped in its **own Navigator** so the MCC
                      // lands in the card rather than over the whole screen.
                      //
                      // `ScanPage` finishes a scan with
                      // `CaptureResultPage.open(context, …)`, which pushes on
                      // the nearest Navigator. Without this that was the hover
                      // app's root one, whose surface is the entire
                      // transparent window — so the result covered everything,
                      // the app underneath vanished, and dismissing it left
                      // the user on the card with a second dismissal still to
                      // go. A Navigator here bounds the push to these pixels.
                      //
                      // `F-171`. `removeTop` is the other half of the header
                      // re-layout, and without it that work is invisible here.
                      //
                      // `ScanPage` asks for the top inset with a `SafeArea` so
                      // its mark clears the status bar — correct full-screen.
                      // Inside this card it is not: the card's top edge is
                      // most of the way down the screen, and the phone's
                      // status-bar height is a measurement of somewhere else
                      // entirely. Left in, it pushed the mark ~30 px below the
                      // card's rounded corner and left a band of dead camera
                      // above it. The `AppBar` that used to be here had the
                      // same bug, which is most likely what the owner saw as
                      // the logo "not aligning".
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        child: Navigator(
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            builder: (_) => const ScanPage(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: SwipSpace.md),
                  _CloseButton(onTap: _close),
                ],
              )
                  // `F-177`. **No slide. It resolves where it already is.**
                  //
                  // This used to rise from below — `slideY(begin: 0.06)` — on
                  // the reasoning that motion from the bottom edge reads as
                  // the card being sent up by the bubble that summoned it.
                  // That was wrong in a way worth keeping written down: a
                  // panel entering from the bottom of the screen is the exact
                  // gesture Android uses for *a new activity*, so however
                  // small the distance, the grammar said "an app is opening".
                  // The owner read it as one.
                  //
                  // A scale from 0.98 has no direction. Nothing travels, so
                  // nothing arrives from anywhere — the card resolves into
                  // focus at the size and place it will stay. Two per cent is
                  // deliberately almost nothing: enough that the frame is not
                  // a hard cut, too little to read as a zoom.
                  .animate()
                  .fadeIn(duration: 220.ms, curve: Curves.easeOutSine)
                  .scaleXY(
                      begin: 0.98,
                      end: 1,
                      duration: 260.ms,
                      curve: Curves.easeOutCubic),
            ),
          ),
        ],
      ),
    );
  }
}

/// The drag handle every Android sheet has, purely so the card reads as a
/// panel that can be dismissed rather than a screen that has taken over.
class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: HoverChrome.grip,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

/// `F-172` — the chrome the hovering card draws around itself.
///
/// Pulled out of the widgets as plain colours so the claims about them can be
/// **asserted** rather than eyeballed — see `hover_chrome_test.dart`, which
/// composites each of these over both a white app and a black one and checks
/// the contrast survives. The bug below is the reason that test exists.
abstract final class HoverChrome {
  /// How hard the app underneath is pushed back.
  ///
  /// Weighted by the ground rather than a flat 45%. Material scrims a light
  /// surface less heavily than a dark one, and the reason is legibility of
  /// what sits on top.
  /// 0.52 and 0.62, not the 0.45 this started at, and the numbers were
  /// chosen by the arithmetic in `hover_chrome_test.dart` rather than by eye:
  /// at 0.45 in Paper, over a *white* app, the pale close button scored 2.6:1
  /// against its own scrim — under WCAG's 3:1 for a graphical object. The
  /// scrim is the only free variable there, because the button is already as
  /// light as SWIP goes.
  static double get scrimAlpha => SwipPalette.active.isDark ? 0.62 : 0.52;

  static Color get scrim => Colors.black.withValues(alpha: scrimAlpha);

  /// The close button's fill, and **the fix for why it was not prominent.**
  ///
  /// It was `Color(0xCC060507)` — SWIP's near-black at 80% — carrying
  /// `Color(0xFFF2EFE9)` text. That pairing has excellent contrast *with
  /// itself* and almost none with what it sits on. Composite it honestly: a
  /// near-black pill, on a 45%-black scrim, over a dark app, is three dark
  /// layers. Against a black app the button lands at about RGB 5 on a black
  /// ground — a contrast ratio of **1.03**, which is invisible. Making it
  /// bigger would have produced a bigger invisible button.
  ///
  /// The first attempt at fixing it followed the palette —
  /// `SwipColors.surfaceRaised` — and that works beautifully in Paper and
  /// fails in Foil for the same reason as the original: Foil's raised surface
  /// is `#141216`, which over a dark scrim over a dark app is the near-black
  /// pill again with extra steps.
  ///
  /// So it does not follow the palette, and `CLAUDE.md` already says why:
  ///
  /// > Camera overlays must use `onCamera*` colours, never
  /// > `bg`/`textPrimary`/`gold500` — the feed is an arbitrary image; the app
  /// > ground is white.
  ///
  /// A card floating over somebody else's app is that rule's case exactly. The
  /// pairing is therefore **inverted** rather than re-tinted: the pale ink
  /// becomes the fill and the near-black becomes the text, which is the
  /// lightest thing SWIP owns sitting on the darkest thing it owns, in both
  /// grounds, over any app.
  static Color get closeFill => SwipColors.onCameraInk.withValues(alpha: 0.94);

  static Color get closeInk => SwipColors.onCameraScrim;

  /// The grip, which can only borrow contrast — it is a 4 px line with nothing
  /// behind it but [scrim] — so it is pinned to the same light end.
  static Color get grip => SwipColors.onCameraInk.withValues(alpha: 0.55);
}

/// `F-172` — the way out, made findable.
///
/// > *"the close button at the below should be a bit more prominent, keep it
/// > transparent or maybe use the latest Android design system"*
///
/// The colour half of that is [HoverChrome.closeFill], which is where the
/// interesting part is written down. This is the shape half.
///
/// ## Transparent *and* Material 3, rather than one or the other
///
/// The owner offered a choice; both are available. 94% keeps the requested
/// translucency — the app underneath ghosts through, so the card still reads
/// as hovering rather than as a screen that has taken over — and the shape is
/// Material 3's: a full pill, a 56 px target, an icon paired with a label, and
/// a tonal fill rather than a bordered outline.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.close_rounded, size: 20),
        label: Text('Close', style: SwipType.label),
        style: FilledButton.styleFrom(
          foregroundColor: HoverChrome.closeInk,
          backgroundColor: HoverChrome.closeFill,
          // `F-177`. **No elevation, reversing `F-172`.**
          //
          // That round gave this a shadow on the argument that the button
          // genuinely is floating, so a little lift is honest rather than
          // decorative. The argument was fine and the result was not: a
          // shadow under a pill arriving over another app is one more thing
          // that says *a window has been placed on top of yours*, which is
          // the whole feeling being removed here.
          //
          // It costs nothing, and that is checkable rather than hopeful:
          // `hover_chrome_test.dart` asserts this button's contrast against
          // its scrim over both a white app and a black one, and the shadow
          // was never what was carrying it.
          elevation: 0,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: SwipSpace.xxl),
          shape: const RoundedRectangleBorder(
              borderRadius: SwipRadius.pillAll),
        ),
      );
}
