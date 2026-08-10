import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/theme/swip_tokens.dart';

/// `F-01`, `F-02`. The live camera card that sits at the top of the dashboard.
///
/// ## Why this exists as a card and not a screen
///
/// The app is opened at a counter, one-handed, with a queue behind. Every tap
/// between opening SWIP and reading a category is a tap taken at the worst
/// possible moment. So the camera is *already looking* when the app opens: point
/// and it answers. The full-screen scanner is still there for a code that will
/// not line up — that is what the tap-through is for (`F-02`).
///
/// ## The three states, and why none of them is a spinner
///
///  * **Idle / no permission yet** — the framed placeholder. Gold corner
///    brackets, a slow sweep, and a plain instruction. This is what a first-time
///    user meets, and it must look deliberate rather than broken, because it is
///    the first impression of the whole product.
///  * **Live** — the feed, dimmed under the Ink scrim so the gold reads, with
///    the reticle and a sweep line that says *this is looking right now*.
///  * **Refused** — one sentence and a button into system settings.
///
/// The camera is started only while this widget is mounted **and** [active] is
/// true, so switching to Ledger or backgrounding the app releases it. A
/// permanently live camera is a battery and trust problem, and neither is worth
/// the half-second it saves.
class LiveViewfinder extends StatefulWidget {
  const LiveViewfinder({
    super.key,
    required this.active,
    required this.onDetect,
    this.onExpand,
    this.onToggleShape,
    this.squared = false,
    this.height = 208,
  });

  /// True only when the dashboard is the visible tab and the app is resumed.
  final bool active;

  /// Fired once per code. The parent stops the camera while it handles it.
  final void Function(String raw) onDetect;

  /// `F-67` — **double** tap opens the full-screen scanner.
  final VoidCallback? onExpand;

  /// `F-66` — **single** tap morphs the band into a square and back.
  final VoidCallback? onToggleShape;

  /// Whether the band is currently the square shape.
  final bool squared;

  final double height;

  @override
  State<LiveViewfinder> createState() => _LiveViewfinderState();
}

class _LiveViewfinderState extends State<LiveViewfinder> {
  MobileScannerController? _controller;
  bool _refused = false;
  bool _handling = false;

  /// `F-68`. Where the last tap landed, and whether it was a double. Rendered
  /// as an expanding ring plus a hand glyph, so the gesture teaches itself:
  /// people discover double-tap by seeing single-tap acknowledged.
  Offset? _tapAt;
  bool _tapWasDouble = false;
  int _tapSeq = 0;

  void _ripple(Offset at, {required bool double_}) {
    setState(() {
      _tapAt = at;
      _tapWasDouble = double_;
      _tapSeq++;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(covariant LiveViewfinder old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _start();
    } else if (!widget.active && old.active) {
      _stop();
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _start() {
    if (_controller != null || _refused) return;
    final c = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode, BarcodeFormat.dataMatrix],
      // The dashboard preview runs at a lower resolution than the full-screen
      // scanner: it is a wide, short strip and does not need 1080p to find a
      // shop sticker held 30 cm away. This is most of the battery saving.
      cameraResolution: const Size(1280, 720),
    );
    setState(() => _controller = c);
  }

  void _stop() {
    final c = _controller;
    _controller = null;
    c?.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _handling = true;
    widget.onDetect(raw);
    // A short refractory period, not a lock: the parent may leave the camera
    // running while it shows a sheet, and re-firing on the same sticker while
    // the sheet is open would stack sheets.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    _handling = false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return GestureDetector(
      // `F-66`, `F-67`. One tap reshapes, two taps go full screen.
      //
      // Flutter waits ~300 ms after a single tap before it can rule out a
      // double, so the ripple fires immediately on tap-down and the actions
      // follow. Without that the screen feels dead for a third of a second and
      // people tap again — which then registers as the double they did not
      // want.
      onTapDown: (d) => _ripple(d.localPosition, double_: false),
      onTap: widget.onToggleShape,
      onDoubleTapDown: (d) => _ripple(d.localPosition, double_: true),
      onDoubleTap: widget.onExpand,
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: SwipColors.surfaceRaised,
          borderRadius: SwipRadius.cardAll,
          border: SwipElevation.e1,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null && !_refused)
              MobileScanner(
                controller: controller,
                onDetect: _onDetect,
                errorBuilder: (context, error, child) {
                  // Permission refused, or no camera. Rendered as the same
                  // framed card so the layout never jumps.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_refused) setState(() => _refused = true);
                  });
                  return const SizedBox.shrink();
                },
              ),

            // Ink scrim. The feed is information, not decoration — dimmed so
            // the gold clears AA over a moving, unpredictable background.
            IgnorePointer(
              child: Container(
                color: SwipColors.bg
                    .withValues(alpha: controller == null ? .92 : .58),
              ),
            ),

            const _GoldFrame(),

            if (controller != null && !_refused)
              const _SweepLine()
            else
              _Idle(refused: _refused),

            // `F-68` — the tap acknowledgement.
            if (_tapAt != null)
              _TapRipple(
                key: ValueKey(_tapSeq),
                at: _tapAt!,
                isDouble: _tapWasDouble,
              ),

            // `F-66` — what the gestures do, faint, only while idle-ish.
            if (!_handling)
              Positioned(
                left: 0,
                right: 0,
                bottom: SwipSpace.sm,
                child: IgnorePointer(
                  child: Text(
                    widget.squared
                        ? 'Tap to widen  ·  Double-tap for full screen'
                        : 'Tap to square up  ·  Double-tap for full screen',
                    textAlign: TextAlign.center,
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.textTertiary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The four gold corner brackets. Drawn rather than imaged so they scale with
/// the card and keep their stroke weight on every density.
class _GoldFrame extends StatelessWidget {
  const _GoldFrame();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(SwipSpace.lg),
          child: CustomPaint(painter: _BracketPainter()),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 500.ms)
          .then()
          .fade(begin: 1, end: .55, duration: 2200.ms, curve: Curves.easeInOut);
}

class _BracketPainter extends CustomPainter {
  static const _len = 30.0;
  static const _radius = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = SwipColors.gold500
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    void corner(double x, double y, double dx, double dy) {
      final path = Path()
        ..moveTo(x + dx * _len, y)
        ..lineTo(x + dx * _radius, y)
        ..quadraticBezierTo(x, y, x, y + dy * _radius)
        ..lineTo(x, y + dy * _len);
      canvas.drawPath(path, p);
    }

    corner(0, 0, 1, 1);
    corner(w, 0, -1, 1);
    corner(0, h, 1, -1);
    corner(w, h, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter oldDelegate) => false;
}

/// The gold sweep that says the camera is live. A still frame and a frozen one
/// look identical; this is the difference.
class _SweepLine extends StatelessWidget {
  const _SweepLine();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SwipSpace.xxl),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  SwipColors.gold500.withValues(alpha: 0),
                  SwipColors.gold300,
                  SwipColors.gold500.withValues(alpha: 0),
                ]),
                boxShadow: [
                  BoxShadow(
                    color: SwipColors.gold500.withValues(alpha: .55),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .moveY(
              begin: 28,
              end: 176,
              duration: 2400.ms,
              curve: Curves.easeInOutSine)
          .then()
          .moveY(
              begin: 176,
              end: 28,
              duration: 2400.ms,
              curve: Curves.easeInOutSine);
}

/// The first-run / no-permission face of the card.
class _Idle extends StatelessWidget {
  const _Idle({required this.refused});
  final bool refused;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              refused
                  ? Icons.no_photography_outlined
                  : Icons.qr_code_scanner_rounded,
              size: 38,
              color: SwipColors.gold500,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                    begin: 1,
                    end: 1.08,
                    duration: 1600.ms,
                    curve: Curves.easeInOut),
            const SizedBox(height: SwipSpace.md),
            Text(
              refused ? 'Camera access is off' : 'Tap to scan',
              style: SwipType.titleS.copyWith(color: SwipColors.textPrimary),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .moveY(begin: 8, curve: SwipMotion.captureCurve),
            const SizedBox(height: SwipSpace.xs),
            Text(
              refused
                  ? 'Allow it in Settings and the camera lives here'
                  : 'Point at any payment QR',
              style: SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
            ).animate().fadeIn(delay: 120.ms, duration: 400.ms),
          ],
        ),
      );
}

/// `F-68` — a gold ring expanding from the touch point, with a hand glyph.
///
/// Two rings for a double tap rather than a different colour: the count is the
/// information, and a second ring reads as "two" without anyone being taught a
/// legend.
class _TapRipple extends StatelessWidget {
  const _TapRipple({super.key, required this.at, required this.isDouble});

  final Offset at;
  final bool isDouble;

  @override
  Widget build(BuildContext context) => Positioned(
        left: at.dx - 40,
        top: at.dy - 40,
        child: IgnorePointer(
          child: SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var ring = 0; ring < (isDouble ? 2 : 1); ring++)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: SwipColors.gold500, width: 2),
                    ),
                  )
                      .animate()
                      .scaleXY(
                          begin: .25,
                          end: 1,
                          delay: (ring * 130).ms,
                          duration: 420.ms,
                          curve: Curves.easeOutCubic)
                      .fadeOut(
                          delay: (ring * 130).ms, duration: 420.ms),
                Icon(
                  isDouble
                      ? Icons.open_in_full_rounded
                      : Icons.touch_app_rounded,
                  size: 22,
                  color: SwipColors.gold300,
                )
                    .animate()
                    .fadeIn(duration: 120.ms)
                    .scaleXY(begin: .7, end: 1.05, duration: 220.ms)
                    .then()
                    .fadeOut(duration: 260.ms),
              ],
            ),
          ),
        ),
      );
}
