import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/swip_tokens.dart';
import '../data/models/capture_event.dart';
import '../data/models/mcc.dart';
import 'scan_flash_card.dart';

/// `F-62` — the stack of recent scans, docked at the bottom of the screen.
///
/// ## Why the bottom, and why a toast
///
/// The first version put the condensed card under the camera. Wrong place: it
/// pushed the page around every time a code drifted through frame, and it sat
/// in the middle of the layout as though it were content. It is not content —
/// it is *notification*, and notifications belong at an edge.
///
/// The reference is Apple's condensed music player: a small floating bar over
/// the interface, always in the same place, ignorable, and one tap from the
/// full thing. Nothing behind it moves when it appears.
///
/// ## The stack
///
/// Scanning continues, so cards accumulate. They page horizontally — newest
/// first — and the cards behind peek out at the right edge so the depth is
/// visible rather than implied. Anything older than a minute drops off the
/// stack on its own; the ledger has it for ever, and a toast that never expires
/// stops being a toast.
class ScanStack extends StatefulWidget {
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

  /// `F-63` — where the pull-string ends up.
  final VoidCallback? onOpenLedger;

  @override
  State<ScanStack> createState() => _ScanStackState();
}

class _ScanStackState extends State<ScanStack> {
  final _pages = PageController(viewportFraction: .93);
  int _page = 0;

  /// `F-63`. How far the stack has been dragged down, 0–1. Drives the number
  /// of `e`s in "vieeeeew older scans", which is the whole joke: the word
  /// stretches like bubblegum and snaps into the ledger when it has stretched
  /// far enough.
  double _pull = 0;

  static const _pullToOpen = 4; // e-count past which the ledger opens

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  int get _eCount => (_pull * 7).round().clamp(0, 9);

  void _onPullEnd() {
    if (_eCount > _pullToOpen) {
      widget.onOpenLedger?.call();
    }
    setState(() => _pull = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── F-63, the pull string ──
        if (_pull > 0.02)
          Padding(
            padding: const EdgeInsets.only(bottom: SwipSpace.xs),
            child: Text(
              'vi${'e' * (2 + _eCount)}w older scans',
              style: SwipType.labelS.copyWith(
                color: _eCount > _pullToOpen
                    ? SwipColors.gold500
                    : SwipColors.textTertiary,
                letterSpacing: .5 + _pull * 2,
              ),
            ),
          ),

        GestureDetector(
          // Dragging the stack downwards stretches the word. Downwards because
          // the stack is docked at the bottom: you are pulling it further out
          // of the way to look behind it.
          onVerticalDragUpdate: (d) => setState(
              () => _pull = (_pull + d.primaryDelta! / 160).clamp(0.0, 1.0)),
          onVerticalDragEnd: (_) => _onPullEnd(),
          child: SizedBox(
            height: 86,
            child: PageView.builder(
              controller: _pages,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: widget.events.length,
              padEnds: false,
              itemBuilder: (context, i) {
                final event = widget.events[i];
                return Padding(
                  padding: EdgeInsets.only(
                    right: SwipSpace.sm,
                    // The cards behind sit slightly lower, so the stack reads
                    // as depth rather than as a carousel of equals.
                    top: i == _page ? 0 : 5,
                    bottom: i == _page ? 0 : 5,
                  ),
                  child: ScanFlashCard(
                    event: event,
                    mcc: widget.mccFor(event.mcc),
                    onExpand: () => widget.onExpand?.call(event),
                    onDismiss: () => widget.onDismiss?.call(event),
                  ),
                );
              },
            ),
          ),
        ),

        if (widget.events.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: SwipSpace.xs),
            child: Text(
              '${_page + 1} of ${widget.events.length} in the last minute',
              style:
                  SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
            ),
          ),
      ],
    ).animate().fadeIn(duration: 240.ms).moveY(begin: 24, end: 0);
  }
}
