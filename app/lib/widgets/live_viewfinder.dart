import 'dart:async';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  /// **One controller at a time, replaced only when it is unusable.**
  ///
  /// The version before this created a controller when the band became active
  /// and `dispose()`d it when it went inactive — and `active` flips on every
  /// capture. Disposing a camera and immediately re-acquiring it is a race
  /// nobody wins.
  ///
  /// It is not `final`, because 5.2.3 has one state a controller cannot be
  /// talked out of: once `value.error` is `permissionDenied`, `start()` returns
  /// immediately for ever and `stop()` — which is what clears the error — bails
  /// out because nothing is running. Granting permission afterwards changes
  /// nothing. The only way back is a new controller, so [_reset] makes one.
  MobileScannerController _controller = _newController();

  static MobileScannerController _newController() => MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode, BarcodeFormat.dataMatrix],
        // `autoStart: false` — start() is called by hand from a post-frame
        // callback, once the platform view exists to attach to.
        autoStart: false,
      );

  bool _running = false;
  bool _refused = false;
  bool _starting = false;
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
    _controller.addListener(_sync);
    // After the first frame, so the platform view exists to attach to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.active) _start();
    });
  }

  @override
  void didUpdateWidget(covariant LiveViewfinder old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;
    // Deferred to after this frame. `_start` and `_stop` both call `setState`,
    // and doing that synchronously inside `didUpdateWidget` is a build-phase
    // violation — which would turn a camera hand-off into a red screen.
    final resume = widget.active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (resume && widget.active) {
        _start();
      } else if (!resume && !widget.active) {
        _stop();
      }
    });
  }

  @override
  void dispose() {
    _blind?.cancel();
    _controller.removeListener(_sync);
    unawaited(_controller.dispose());
    super.dispose();
  }

  /// **The camera's state is the controller's state, not ours.**
  ///
  /// This is the correction to the bug that put "Camera access is off" on the
  /// dashboard after coming back from the full-screen scanner. In 5.2.3
  /// `start()` does **not** throw when it fails — it catches its own exception
  /// and parks it in `value.error`. So the old code's `catch (permissionDenied)`
  /// never ran, `_running` was set true on a start that had actually failed,
  /// and the only thing that noticed was `errorBuilder` — which treated *every*
  /// error as a refusal, including the perfectly ordinary
  /// `controllerAlreadyInitialized` you get while the other scanner is still
  /// letting go of the camera.
  ///
  /// Reading the controller instead means the card can only ever say what is
  /// actually true, and only `permissionDenied` reads as refused.
  void _sync() {
    if (!mounted) return;
    final v = _controller.value;
    final running = v.isRunning && v.error == null;
    final refused =
        v.error?.errorCode == MobileScannerErrorCode.permissionDenied;
    if (running != _running || refused != _refused) {
      setState(() {
        _running = running;
        _refused = refused;
      });
    }
  }

  /// Throw the wedged controller away and fit a new one.
  ///
  /// Only ever needed after a refusal — see the note on [_controller].
  void _reset() {
    final old = _controller;
    old.removeListener(_sync);
    unawaited(old.dispose());
    _controller = _newController();
    _controller.addListener(_sync);
    _running = false;
    _refused = false;
  }

  /// Start the camera, retrying while another scanner still holds it.
  ///
  /// The retry is not defensive padding. `MobileScannerPlatform.instance` is a
  /// **process-wide singleton with one texture id**, so the dashboard band and
  /// the full-screen scanner are contending for one slot. Whichever asks second
  /// gets `controllerAlreadyInitialized` until the first one's `dispose()`
  /// finishes — and `dispose()` is asynchronous and un-awaited by the
  /// Navigator. Waiting a few hundred milliseconds is the whole fix.
  Future<void> _start({int attempt = 0}) async {
    if (_starting || _running || !mounted) return;
    setState(() => _starting = true);

    try {
      for (var i = attempt; i <= 5; i++) {
        if (!mounted || !widget.active) return;

        try {
          await _controller.start();
        } catch (_) {
          // controllerDisposed is the only throw 5.2.3 has left. A new
          // controller is the only answer to it.
          if (!mounted) return;
          _reset();
          continue;
        }

        if (!mounted) return;
        final v = _controller.value;

        if (v.isRunning && v.error == null) {
          // The hand-off can flip `active` while we were awaiting a start. If
          // it did, give the camera straight back — otherwise the dashboard
          // would hold hardware the full-screen scanner is about to ask for.
          if (!widget.active) {
            unawaited(_stop());
            return;
          }
          _sync();
          _sawSomething(); // `F-96`. Arms the "nothing in view" watchdog.
          return;
        }

        final code = v.error?.errorCode;

        if (code == MobileScannerErrorCode.permissionDenied) {
          // Scenario 2: refused. Not an error to hide — a state with an action
          // attached, so the user can change their mind later.
          _sync();
          return;
        }

        if (code == MobileScannerErrorCode.unsupported) {
          _sync();
          return; // No camera on this device. Retrying cannot help.
        }

        // controllerAlreadyInitialized, or a generic failure. Both mean "not
        // yet" far more often than they mean "never". Back off and ask again.
        await Future<void>.delayed(Duration(milliseconds: 180 + i * 160));
      }
    } finally {
      _starting = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _stop() async {
    _running = false;
    _blind?.cancel();
    _cannotSee = false;
    try {
      // Unconditional: `stop()` guards itself, and skipping it when our own
      // flag says "not running" is how the platform's texture stayed claimed
      // while the full-screen scanner sat on a black rectangle.
      await _controller.stop();
    } catch (_) {
      // Already stopped, or disposed mid-flight. Nothing to recover.
    }
    if (mounted) setState(() {});
  }

  /// The tap on the refused card. `F-69`.
  ///
  /// On Android a denied permission can be asked for again, so the first move
  /// is simply to try. Only when Android silently refuses to prompt — the
  /// "don't ask again" state — is the user sent to app settings, because
  /// sending them there when a prompt would have worked is two extra screens
  /// for nothing.
  Future<void> _requestPermission() async {
    // A refused controller is a dead controller in 5.2.3, so the retry has to
    // happen on a fresh one or it is guaranteed to do nothing.
    setState(_reset);
    await _start();
    if (!mounted || _running) return;

    await const MethodChannel('in.swip.app/nfc')
        .invokeMethod<void>('openAppSettings')
        .catchError((_) {});
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _handling = true;
    _sawSomething();
    widget.onDetect(raw);
    // A short refractory period, not a lock: the parent may leave the camera
    // running while it shows a sheet, and re-firing on the same sticker while
    // the sheet is open would stack sheets.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    _handling = false;
  }

  /// `F-96` — the "I cannot see anything" hint.
  ///
  /// ## Why it is a timer and not a light meter
  ///
  /// Measuring how dark the frame is means reading the frame, and reading the
  /// frame means image buffers — `returnImage: true` hands back full-size bytes
  /// for every analysed frame. That is exactly the memory cost this was asked
  /// to avoid, and on the dashboard the camera is live the whole time the app
  /// is open.
  ///
  /// So the signal used is the one already there and free: **the scanner has
  /// been looking for a while and found nothing.** That covers the dark room,
  /// the lens under a thumb, the phone flat on a table and the code held too
  /// close, without allocating a single byte. It cannot name which of those it
  /// is — so the copy names the fixes rather than the cause, which is the part
  /// the person can act on anyway.
  ///
  /// One `Timer`, restarted on each detection. No polling, no frames, no state
  /// held between ticks.
  Timer? _blind;
  bool _cannotSee = false;

  static const _blindAfter = Duration(seconds: 7);

  void _sawSomething() {
    _blind?.cancel();
    if (_cannotSee && mounted) setState(() => _cannotSee = false);
    if (!_running) return;
    _blind = Timer(_blindAfter, () {
      if (mounted && _running && !_handling) {
        setState(() => _cannotSee = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // `F-66`, `F-67`. One tap reshapes, two taps go full screen.
      //
      // Flutter waits ~300 ms after a single tap before it can rule out a
      // double, so the ripple fires immediately on tap-down and the actions
      // follow. Without that the screen feels dead for a third of a second and
      // people tap again — which then registers as the double they did not
      // want.
      onTapDown: (d) => _ripple(d.localPosition, double_: false),
      // `F-69`. When the camera is refused, a tap is a request for it — not a
      // reshape. Nothing else on this card is worth tapping in that state.
      onTap: _refused ? _requestPermission : widget.onToggleShape,
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
            if (!_refused)
              MobileScanner(
                // `MobileScanner` reads its controller into a `late final`
                // field, so a swapped controller is invisible to it without a
                // new key — and [_reset] swaps one. Keying on the controller's
                // identity is what makes "allow the camera after refusing it"
                // actually reconnect.
                key: ObjectKey(_controller),
                controller: _controller,
                onDetect: _onDetect,
                // Purely visual. State comes from [_sync] reading the
                // controller, because this builder fires for transient
                // contention too — treating that as a refusal is exactly the
                // bug that put "Camera access is off" on a working camera.
                errorBuilder: (context, error, child) =>
                    const SizedBox.shrink(),
              ),

            // Ink scrim. The feed is information, not decoration — dimmed so
            // the gold clears AA over a moving, unpredictable background.
            IgnorePointer(
              child: Container(
                color: SwipColors.bg
                    .withValues(alpha: _running ? .58 : .92),
              ),
            ),

            const _GoldFrame(),

            if (_running && !_refused)
              const _SweepLine()
            else
              _Idle(refused: _refused, starting: _starting),

            // `F-68` — the tap acknowledgement.
            if (_tapAt != null)
              _TapRipple(
                key: ValueKey(_tapSeq),
                at: _tapAt!,
                isDouble: _tapWasDouble,
              ),

            // `F-96` — what to do when nothing is being found.
            if (_cannotSee && _running && !_handling)
              Positioned(
                left: SwipSpace.md,
                right: SwipSpace.md,
                top: SwipSpace.md,
                child: IgnorePointer(
                  child: _OnCameraText(
                    'NOTHING IN VIEW  ·  MORE LIGHT, OR MOVE BACK',
                    color: SwipColors.gold300,
                  ),
                ),
              ),

            // `F-97` — what the gestures do.
            //
            // Upper case and on a plate. This sits over a live camera feed, so
            // the background is whatever the shop counter happens to be:
            // white marble, a black terminal, a moving hand. Grey text at any
            // weight is unreadable against roughly half of those. Caps plus a
            // dark rounded plate makes it legible on all of them at a fixed
            // cost of one more container.
            if (!_handling && _running)
              Positioned(
                left: SwipSpace.md,
                right: SwipSpace.md,
                bottom: SwipSpace.sm,
                child: IgnorePointer(
                  child: _OnCameraText(
                    widget.squared
                        ? 'TAP TO WIDEN  ·  DOUBLE-TAP FOR FULL SCREEN'
                        : 'TAP TO SQUARE UP  ·  DOUBLE-TAP FOR FULL SCREEN',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `F-97` — text that has to stay readable over a live camera feed.
///
/// Three cheap things, in order of how much they do:
///
///   1. **A plate.** A translucent dark rounded rectangle. This is what makes
///      it work over white marble and shop lighting; nothing else comes close.
///   2. **Upper case, tracked out.** Short all-caps runs survive a busy,
///      moving background far better than mixed case, because the word shape
///      does not depend on ascenders that a bright patch can swallow.
///   3. **A shadow.** For the edge of the plate where it meets a bright frame.
///
/// No blur, no `BackdropFilter`: a backdrop blur over a live camera feed is a
/// full-screen shader every frame, which is exactly the kind of cost this card
/// cannot carry while it is also scanning.
class _OnCameraText extends StatelessWidget {
  const _OnCameraText(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: SwipSpace.sm, vertical: 3),
          decoration: BoxDecoration(
            color: SwipColors.bg.withValues(alpha: .62),
            borderRadius: SwipRadius.chipAll,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SwipType.labelS.copyWith(
              color: color ?? SwipColors.textPrimary,
              letterSpacing: .6,
              shadows: const [
                Shadow(color: Color(0xCC000000), blurRadius: 3),
              ],
            ),
          ),
        ),
      );
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
  const _Idle({required this.refused, this.starting = false});
  final bool refused;
  final bool starting;

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
              refused
                  ? 'Camera access is off'
                  : starting
                      ? 'Waking the camera…'
                      : 'Tap to scan',
              style: SwipType.titleS.copyWith(color: SwipColors.textPrimary),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .moveY(begin: 8, curve: SwipMotion.captureCurve),
            const SizedBox(height: SwipSpace.xs),
            Text(
              refused
                  ? 'Tap here to allow it - the camera lives on this card'
                  : starting
                      ? 'One moment'
                      : 'Point at any payment QR',
              style: SwipType.bodyS.copyWith(
                  color: refused
                      ? SwipColors.gold500
                      : SwipColors.textTertiary),
            ).animate().fadeIn(delay: 120.ms, duration: 400.ms),
          ],
        ),
      );
}

/// `F-104` — the tap acknowledgement: a dotted grid that breathes outward.
///
/// ## Why the hand glyph is gone
///
/// A ☝ icon on a tap is a tutorial drawn on top of the thing being used. It
/// tells you what you just did, which you already know, and it keeps telling
/// you for ever — a permanent hint is an admission that the gesture was never
/// discoverable. The gesture teaches itself through the *response*, not through
/// a picture of a hand.
///
/// ## The dots
///
/// A FigJam-style grid, clipped to a circle that expands from the touch point.
/// Each dot fades by its distance from the centre, so the ring reads as a
/// pressure wave passing through the canvas rather than an outline being drawn
/// on it. Two waves for a double tap: the count is the information.
///
/// Painted in a single `CustomPainter` — one `drawPoints` call, no per-dot
/// widgets, nothing allocated per frame. Over a live camera feed that matters:
/// this is the one animation that fires while the scanner is analysing.
class _TapRipple extends StatelessWidget {
  const _TapRipple({super.key, required this.at, required this.isDouble});

  final Offset at;
  final bool isDouble;

  /// The grid pitch. 9 px reads as texture at arm's length and as distinct dots
  /// up close, which is the FigJam trick.
  static const _pitch = 9.0;
  static const _reach = 92.0;

  @override
  Widget build(BuildContext context) => Positioned(
        left: at.dx - _reach,
        top: at.dy - _reach,
        child: IgnorePointer(
          child: SizedBox(
            width: _reach * 2,
            height: _reach * 2,
            child: Stack(
              children: [
                for (var wave = 0; wave < (isDouble ? 2 : 1); wave++)
                  _DottedWave(wave: wave, pitch: _pitch),
              ],
            ),
          ),
        ),
      );
}

/// One expanding wave. Split out so each has its own controller and the second
/// can start late without the first restarting.
class _DottedWave extends StatefulWidget {
  const _DottedWave({required this.wave, required this.pitch});

  final int wave;
  final double pitch;

  @override
  State<_DottedWave> createState() => _WaveState();
}

class _WaveState extends State<_DottedWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 620),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: widget.wave * 120), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _DottedWavePainter(
            // Eased so the wave leaves fast and settles slow, which is what a
            // real disturbance in a surface does.
            t: Curves.easeOutCubic.transform(_c.value),
            pitch: widget.pitch,
          ),
        ),
      );
}

class _DottedWavePainter extends CustomPainter {
  const _DottedWavePainter({required this.t, required this.pitch});

  /// 0 at the touch, 1 when the wave has reached the edge and faded out.
  final double t;
  final double pitch;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;

    final centre = size.center(Offset.zero);
    final radius = size.width / 2 * t;
    // The band the wave currently occupies. Dots outside it are not drawn at
    // all, which is what keeps this to one cheap pass.
    const band = 26.0;
    final inner = radius - band;

    final dots = <Offset>[];
    for (var x = pitch / 2; x < size.width; x += pitch) {
      for (var y = pitch / 2; y < size.height; y += pitch) {
        final p = Offset(x, y);
        final d = (p - centre).distance;
        if (d > radius || d < inner) continue;
        dots.add(p);
      }
    }
    if (dots.isEmpty) return;

    final paint = Paint()
      ..color = SwipColors.gold300.withValues(alpha: (1 - t) * 0.85)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPoints(PointMode.points, dots, paint);
  }

  @override
  bool shouldRepaint(covariant _DottedWavePainter old) =>
      old.t != t || old.pitch != pitch;
}
