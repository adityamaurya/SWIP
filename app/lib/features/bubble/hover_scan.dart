import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  static const route = '/hover';

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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
            ),
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
                      // The real scanner, unmodified. It brings its own
                      // Scaffold, its own bar with the torch, its own camera
                      // lifecycle and its own result route — so the card shows
                      // exactly what the dashboard's scanner shows, because it
                      // is that widget.
                      child: const ScanPage(),
                    ),
                  ),
                  const SizedBox(height: SwipSpace.md),
                  _CloseButton(onTap: _close),
                ],
              ),
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
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.close_rounded, size: 18),
        label: const Text('Close'),
        style: TextButton.styleFrom(
          // Hard-coded rather than themed, for the same reason the bubble's
          // colours are: this sits over an arbitrary app, so it has to carry
          // its own contrast instead of borrowing a ground it cannot see.
          foregroundColor: const Color(0xFFF2EFE9),
          backgroundColor: const Color(0xCC060507),
          padding: const EdgeInsets.symmetric(
              horizontal: SwipSpace.lg, vertical: SwipSpace.md),
          shape: const RoundedRectangleBorder(
              borderRadius: SwipRadius.pillAll),
        ),
      );
}
