import 'package:flutter/material.dart';

/// `F-174` — the container every capture popup sits in, and **the fix for the
/// striped bar at the bottom of the screen.**
///
/// > *"THERE IS SOME BUG AT THE BOTTOM IDK WHAT THAT IS"*
///
/// ## What that bar was
///
/// Flutter's overflow indicator: `BOTTOM OVERFLOWED BY 28 PIXELS`. It is drawn
/// when a `Column` is handed less height than its children need, and it is
/// debug-only — in a release build the same layout silently clips instead,
/// which is worse, because the content that falls off the bottom is simply
/// missing with nothing to say so.
///
/// ## Why it appeared, and why only now
///
/// `showCaptureDetail` opened the capture sheet like this:
///
/// ```dart
/// showModalBottomSheet(
///   isScrollControlled: true,
///   builder: (_) => CaptureSheet(...),   // a Column. Not scrollable.
/// );
/// ```
///
/// `isScrollControlled: true` lets the sheet grow to the full height of the
/// screen — and then stops. `CaptureSheet` is a `Column` with no scroll view
/// anywhere in it, so a capture with enough content to exceed the screen had
/// nowhere to put the excess.
///
/// It had been that way for a long time and nobody had seen it, because the
/// only routes in were the ledger rows. **`F-169` wired up the dashboard's
/// MCC tap**, which was the fix for a dead callback — and it opened a door to
/// a screen whose bug had been waiting behind it. Worth recording as its own
/// kind of lesson: connecting something that was never reachable does not only
/// deliver the feature, it exposes everything downstream of it for the first
/// time.
///
/// ## The three jobs this does
///
/// 1. **Caps the height** at a fraction of the screen, so the app or the
///    camera underneath is still visible — the popup is non-intrusive by
///    construction rather than by hoping the content is short.
/// 2. **Scrolls the content**, which is the actual overflow fix. `Flexible`
///    rather than `Expanded` is load-bearing: with `mainAxisSize.min` the
///    column is only as tall as it needs to be, so a short capture produces a
///    short sheet instead of a full-height one with a gap in it.
/// 3. **Pins a footer** below the scroll, so a CTA sits at a predictable place
///    rather than at the end of however much content this capture happened to
///    produce. That was the argument for building `CaptureResultPage` in
///    `F-144`, and it turns out it needed a container rather than a page.
class CaptureSheetShell extends StatelessWidget {
  const CaptureSheetShell({
    super.key,
    required this.child,
    this.footer,
    this.maxHeightFraction = 0.86,
  });

  /// The capture content. Scrolls.
  final Widget child;

  /// Pinned under the scroll view. The split CTA, where there is one.
  final Widget? footer;

  /// How much of the screen the popup may take.
  ///
  /// Under 1.0 on purpose, and not by much: enough of the app underneath has
  /// to stay visible that the sheet reads as *over* something rather than as
  /// having replaced it. That is the whole difference the owner asked for
  /// between this and the full-screen result.
  final double maxHeightFraction;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // `F-180`. **No grabber here.** There used to be one and it was the
          // second of two.
          //
          // `SwipTheme`'s `bottomSheetTheme` sets `showDragHandle: true`, so
          // Flutter draws a handle above this widget on every modal sheet in
          // the app — and this widget only ever appears inside one. Drawing
          // another produced the two stacked pills in the owner's screenshot.
          //
          // The theme's is the one kept, for a reason beyond "pick one": it
          // carries the drag-handle semantics a screen reader announces and
          // the tap-to-dismiss behaviour Material wires to it, where this file
          // had a decorative `Container`. Deleting the decorative one is the
          // fix; deleting the real one would have been the same number of
          // pixels and less of a sheet.
          //
          // The overflow fix, in one word: Flexible.
          Flexible(child: SingleChildScrollView(child: child)),
          if (footer != null)
            Padding(
              // The gesture bar's inset is added here rather than by a
              // `SafeArea` inside the footer, because a `SafeArea` would also
              // pad the sides and the footer's buttons are meant to run to the
              // sheet's own gutter.
              padding: EdgeInsets.only(bottom: inset.bottom),
              child: footer!,
            ),
        ],
      ),
    );
  }
}
