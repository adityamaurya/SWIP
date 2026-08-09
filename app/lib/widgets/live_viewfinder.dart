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
    this.height = 208,
  });

  /// True only when the dashboard is the visible tab and the app is resumed.
  final bool active;

  /// Fired once per code. The parent stops the camera while it handles it.
  final void Function(String raw) onDetect;

  /// `F-02` — tap the viewfinder for the full-screen scanner.
  final VoidCallback? onExpand;

  final double height;

  @override
  State<LiveViewfinder> createState() => _LiveViewfinderState();
}

class _LiveViewfinderState extends State<LiveViewfinder> {
  MobileScannerController? _controller;
  bool _refused = false;
  bool _handling = false;

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
      onTap: widget.onExpand,
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
