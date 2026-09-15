import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/onboarding/primers.dart';
import '../../core/settings/home_market.dart';
import '../../core/theme/swip_tokens.dart';
import '../../data/repositories/capture_repository.dart';
import '../../data/sources/capture_resolver.dart';
import '../../widgets/capture_result_page.dart';

/// `S-02` — Scan a QR.
///
/// Full-bleed camera under an Ink scrim, with a gold reticle. Works on any
/// merchant-presented QR anywhere in the world; see [CaptureResolver] for the
/// resolution order and for why an honest "Unknown" is a correct outcome.
/// `F-171` — how big the aiming square is on a surface [width] x [height].
///
/// A free function, and public, for one reason: **it is the only part of this
/// screen a test can reach.** Everything else here needs a camera, and a
/// widget test has no engine behind `MobileScanner`'s channel — see the
/// `MethodChannel` note in `CLAUDE.md`. The arithmetic is where the bug was,
/// so the arithmetic is what is asserted, in `scan_layout_test.dart`.
///
/// [reticleChrome] is what the screen reserves above and below: roughly 50 for
/// the mark and torch, 100 for the title and its explanation, 40 of air.
double scanReticleSide(double width, double height) => math
    .min(width - SwipSpace.xxxl * 2, height - reticleChrome)
    .clamp(120.0, 260.0);

/// Vertical space [scanReticleSide] keeps clear for the header and footer.
const reticleChrome = 190.0;

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  MobileScannerController _controller = _newController();

  static MobileScannerController _newController() => MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        // `F-126`. **Never `noDuplicates`.** It is a single-slot memory inside
        // the Android plugin:
        //
        //   private var lastScanned: List<String?>? = null
        //   if (newScannedBarcodes == lastScanned) return@addOnSuccessListener
        //
        // and it is cleared only by `stop()` or `dispose()`. So pointing at the
        // *same* code a second time emits nothing at all - no callback, no
        // error - until the camera is torn down. That is the whole reason a
        // force-quit "fixed" scanning: killing the app nulled the slot.
        //
        // `normal` throttles to one detection per `detectionTimeoutMs` instead,
        // and SWIP de-duplicates in Dart over a window it controls, so the same
        // sticker scanned again ten seconds later works the way anyone would
        // expect it to.
        detectionTimeoutMs: 300,
        // A small code in a big frame was the other half of the problem. The
        // default resolution is whatever the platform picks; 1920x1080 gives
        // ML Kit enough pixels on a counter-top sticker at arm's length.
        cameraResolution: const Size(1920, 1080),
        formats: const [BarcodeFormat.qrCode, BarcodeFormat.dataMatrix],
        // Started by hand once the widget is attached — see [_start].
        autoStart: false,
      );

  bool _handling = false;
  bool _refused = false;
  bool _running = false;

  /// `F-171`. Whether the torch is lit, as the **controller** reports it.
  ///
  /// Not a boolean this screen flips when the button is tapped. `CLAUDE.md`
  /// records why, from the floating bubble: *"a switch that stores its own
  /// state instead of asking the platform cannot be wrong on screen"* — it
  /// shows the value it just set, so it agrees with itself while disagreeing
  /// with the phone. `toggleTorch()` can fail (no torch on this lens, the
  /// camera not started yet, the front camera selected) and the icon has to
  /// follow what actually happened.
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
    // The explanation arrives ahead of the camera permission dialog, not on
    // top of it — a permission prompt with no context is how apps get denied.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await showPrimer(context, ref, SwipPrimer.scanQr);
      await _start();
    });
  }

  /// See the long note in `live_viewfinder.dart`: in 5.2.3 `start()` swallows
  /// its own failure into `value.error` rather than throwing, so the controller
  /// — not a `catch` block — is the only honest source of state.
  void _sync() {
    if (!mounted) return;
    final v = _controller.value;
    final running = v.isRunning && v.error == null;
    final refused =
        v.error?.errorCode == MobileScannerErrorCode.permissionDenied;
    final torchOn = v.torchState == TorchState.on;
    if (running != _running || refused != _refused || torchOn != _torchOn) {
      setState(() {
        _running = running;
        _refused = refused;
        _torchOn = torchOn;
      });
    }
  }

  /// Replace a controller that cannot be restarted. A `permissionDenied` error
  /// makes `start()` a no-op for ever, and `stop()` — the only thing that
  /// clears it — refuses to run because nothing is running.
  void _reset() {
    final old = _controller;
    old.removeListener(_sync);
    unawaited(old.dispose());
    _controller = _newController();
    _controller.addListener(_sync);
    _running = false;
    _refused = false;
    _torchOn = false;
  }

  /// Start the camera, retrying while the dashboard band still holds it.
  ///
  /// `MobileScannerPlatform.instance` is a process-wide singleton with a single
  /// texture, so this screen and the dashboard viewfinder compete for one slot
  /// and the loser gets `controllerAlreadyInitialized` until the other's
  /// asynchronous `dispose()` lands. It also matters that the primer sheet is
  /// on screen the first time this runs.
  Future<void> _start({int attempt = 0}) async {
    for (var i = attempt; i <= 5; i++) {
      if (!mounted) return;

      try {
        await _controller.start();
      } catch (_) {
        // controllerDisposed. Only a new controller answers that.
        if (!mounted) return;
        setState(_reset);
        continue;
      }

      if (!mounted) return;
      final code = _controller.value.error?.errorCode;

      if (_controller.value.error == null && _controller.value.isRunning) {
        _sync();
        return;
      }
      if (code == MobileScannerErrorCode.permissionDenied ||
          code == MobileScannerErrorCode.unsupported) {
        _sync();
        return;
      }

      await Future<void>.delayed(Duration(milliseconds: 180 + i * 160));
    }
    _sync();
  }

  Future<void> _requestPermission() async {
    setState(_reset);
    await _start();
    if (!mounted || _running) return;
    // Android has stopped prompting. Settings is the only way back.
    await const MethodChannel('in.swip.app/nfc')
        .invokeMethod<void>('openAppSettings')
        .catchError((_) {});
  }

  @override
  void dispose() {
    _controller.removeListener(_sync);
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _handling = true);
    await _controller.stop();

    final resolved = CaptureResolver.resolve(raw);
    final repo = await ref.read(captureRepositoryProvider.future);
    final home = ref.read(homeMarketProvider).valueOrNull;

    final event = await repo.record(
      vector: resolved.vector,
      mcc: resolved.mcc,
      merchantName: resolved.merchantName,
      merchantCity: resolved.merchantCity,
      countryCode: resolved.countryCode,
      merchantKey: resolved.merchantKey,
      amount: resolved.amount,
      currency: resolved.currency,
      terminalId: resolved.terminalId,
      acquirer: resolved.acquirer,
      rawPayload: resolved.rawPayload,
    );

    ref.read(ledgerRevisionProvider.notifier).state++;

    if (!mounted) return;
    // `F-144`. Full screen, not a sheet. The MCC is the product and a sheet
    // renders it at 60 px over a live camera feed; this gives it the page.
    await CaptureResultPage.open(
      context,
      event: event,
      mcc: repo.lookup(event.mcc),
      sourceLabel: resolved.sourceLabel,
      rawPayload: raw,
      verdict: home?.verdictFor(resolved.countryCode,
          deviceCountry: event.placeCountry),
      payeeKind: resolved.payeeKind,
      tier: resolved.tier,
      // `F-124`, `F-125`. The verdict and the routes travel with the capture.
      rupay: resolved.rupay,
      absence: resolved.absence,
      details: {
        // `F-42`. The payment company and the payee handle are listed as
        // what they are, so neither can be mistaken for the shop's name.
        if (resolved.acquirer != null) 'Payment company': resolved.acquirer!,
        if (resolved.merchantHandle != null)
          'Pays to': resolved.merchantHandle!,
        if (resolved.merchantCity != null) 'City': resolved.merchantCity!,
        if (resolved.countryCode != null) 'Country': resolved.countryCode!,
        if (resolved.amount != null)
          'Amount': '${resolved.currency ?? ''} ${resolved.amount}'.trim(),
        if (resolved.terminalId != null) 'Terminal': resolved.terminalId!,
      },
    );

    if (!mounted) return;
    setState(() => _handling = false);
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // `F-171`. The status-bar style used to ride on the `AppBar` that is no
      // longer here. It still has to be stated: this screen is a camera feed
      // under an ink scrim while the rest of SWIP is Paper, so inheriting the
      // app's dark status-bar icons would make them invisible on the one
      // screen nobody screenshots.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: SwipColors.onCameraScrim,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (!_refused)
              MobileScanner(
                // A swapped controller is invisible to `MobileScanner` without a
                // new key — it holds its controller in a `late final`.
                key: ObjectKey(_controller),
                controller: _controller,
                onDetect: _onDetect,
                // Only a refusal is a dead end worth a screen of copy. Contention
                // with the dashboard band resolves itself, and [_start] is
                // already retrying through it.
                errorBuilder: (context, error, child) => error.errorCode ==
                        MobileScannerErrorCode.permissionDenied
                    ? _CameraError(onAllow: _requestPermission)
                    : const SizedBox.shrink(),
              )
            else
              _CameraError(onAllow: _requestPermission),

            // Ink scrim — the camera feed is information, not decoration, so it
            // is dimmed rather than hidden.
            IgnorePointer(
              child: Container(color: SwipColors.onCameraScrim.withValues(alpha: .55)),
            ),

            // `F-171`. The reticle, sized to the surface rather than fixed at
            // 260 px.
            //
            // Fixed was fine while this was only ever full-screen. It is not
            // now: inside the hovering card the surface can be as short as
            // 320 px, and a 260 px square in a 320 px box leaves 30 px top and
            // bottom — so the mark above it and the two lines of copy below it
            // were drawn *on* the reticle. Nothing overflowed and nothing
            // threw, because a `Stack` is entitled to overlap its children;
            // it simply looked broken.
            //
            // `maxHeight - 190` is the chrome this screen actually reserves:
            // roughly 50 for the mark and torch at the top, 100 for the title
            // and its explanation at the bottom, and 40 of breathing room. The
            // clamp keeps it from collapsing to nothing on a very short card
            // and from growing past the size that was right all along.
            //
            // `LayoutBuilder`, not `MediaQuery.sizeOf` — inside the card the
            // MediaQuery still describes the whole phone, which is the same
            // mistake `removeTop` fixes in `hover_scan.dart`.
            LayoutBuilder(
              builder: (context, box) {
                final side = scanReticleSide(box.maxWidth, box.maxHeight);
                return Center(
                  child: Container(
                    width: side,
                    height: side,
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: SwipColors.onCameraAccent, width: 2),
                      borderRadius: BorderRadius.circular(28),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(duration: 400.ms)
                      .then()
                      .scaleXY(
                          begin: 1,
                          end: 1.03,
                          duration: 1400.ms,
                          curve: Curves.easeInOut),
                );
              },
            ),

            // `F-171`. **The mark and the torch, at the very top. Nothing else.**
            //
            // > *"the SWIP logo is not aligning, it's aligning with the scan the
            // > QR thing … keep the SWIP logo in the top but take it to the more
            // > top region, also the flashlight as well"*
            //
            // The old version put all three in an `AppBar`, which is a single
            // row: the mark, the title and the torch were vertically centred on
            // each other by construction, and an `AppBar`'s row is 56 px tall
            // with the title's cap-height sitting in the middle of it. So the
            // wordmark could never be *at the top* while the title was beside
            // it — those are contradictory requirements for one row, which is
            // why moving the title out is the fix rather than a padding tweak.
            //
            // Freed of the title, the row carries only the two things that are
            // chrome, and it sits directly under the status bar.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                // `AppBar` used to supply this inset. Nothing does now, so it is
                // asked for explicitly — and `hover_scan.dart` strips the top
                // inset before this widget ever sees it, because inside a card
                // floating at the bottom of the screen the phone's status-bar
                // height is a measurement of somewhere else entirely.
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      SwipSpace.lg, SwipSpace.sm, SwipSpace.sm, 0),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/brand/swip-slash-wordmark.svg',
                        height: 18,
                        semanticsLabel: 'SW/P',
                        // The white mark, not the ink one: this floats over a
                        // camera feed, which is an arbitrary image. Same rule as
                        // every other `onCamera*` colour in this file.
                        colorFilter: const ColorFilter.mode(
                            SwipColors.onCameraInk, BlendMode.srcIn),
                      ),
                      const Spacer(),
                      _TorchButton(
                        on: _torchOn,
                        onPressed: () => _controller.toggleTorch(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // `F-171`. The title, moved down to live with the line it belongs
            // to — *"get the scan QR at the below, near the below text lines"*.
            //
            // It reads better here than it did in the bar, and that is not a
            // coincidence: "Scan a QR" and "Point at any payment QR…" are a
            // heading and its explanation, and they were separated by the whole
            // height of the screen with a camera in between.
            Positioned(
              left: SwipSpace.xl,
              right: SwipSpace.xl,
              bottom: SwipSpace.xxxl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scan a QR',
                    textAlign: TextAlign.center,
                    style: SwipType.titleL
                        .copyWith(color: SwipColors.onCameraInk),
                  ),
                  const SizedBox(height: SwipSpace.sm),
                  Text(
                    'Point at any payment QR - UPI, BharatQR, PIX, QRIS,\n'
                    'PayNow, PromptPay and thirty more.',
                    textAlign: TextAlign.center,
                    style: SwipType.bodyM.copyWith(
                        color: SwipColors.onCameraInk.withValues(alpha: .72)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `F-171` — the torch, as a control that knows whether it is on.
///
/// ## Why it is a filled circle and not a bare `IconButton`
///
/// It sits on a camera feed, which is an arbitrary image SWIP did not draw. A
/// bare white icon is legible against a dark counter and invisible against a
/// lit menu board or a white-tiled wall — and this is the button somebody
/// reaches for *because* the light is bad, so the case where it fails is
/// exactly the case it exists for. A translucent disc gives it its own ground
/// without hiding what is underneath.
///
/// ## Why the icon changes
///
/// `Icons.flashlight_on_outlined` was drawn whether the torch was lit or not,
/// so the only way to find out was to look at the room. The lit state also
/// takes the gold, because [SwipColors.onCameraAccent] is already the
/// screen's "this is live" colour — it is what the reticle is drawn in.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.on, required this.onPressed});

  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: on ? 'Turn the torch off' : 'Turn the torch on',
        // Announced as a switch rather than a button, so a screen reader says
        // "on"/"off" instead of leaving the state to the icon alone.
        isSelected: on,
        icon: const Icon(Icons.flashlight_on_outlined),
        selectedIcon: const Icon(Icons.flashlight_on_rounded),
        style: IconButton.styleFrom(
          foregroundColor: on
              ? SwipColors.onCameraScrim
              : SwipColors.onCameraInk,
          backgroundColor: on
              ? SwipColors.onCameraAccent
              : SwipColors.onCameraInk.withValues(alpha: .14),
          // The Material 3 icon-button target, stated rather than inherited:
          // this button is not inside an `AppBar` any more, and `AppBar` was
          // where the 48 px minimum was coming from.
          minimumSize: const Size(44, 44),
          padding: EdgeInsets.zero,
        ),
      );
}

class _CameraError extends StatelessWidget {
  const _CameraError({this.onAllow});

  /// `F-69`. Never a dead end: asking again is one tap, and if Android has
  /// stopped prompting this opens app settings instead.
  final VoidCallback? onAllow;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(SwipSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Not `const`: `withValues` is a method call, so the whole
              // expression stops being a constant. The old `textTertiary` was
              // a plain constant, which is why this compiled before the
              // palette moved.
              Icon(Icons.no_photography_outlined,
                  size: 40,
                  color: SwipColors.onCameraInk.withValues(alpha: .55)),
              const SizedBox(height: SwipSpace.lg),
              Text(
                'SWIP needs the camera to read a QR',
                style: SwipType.titleS.copyWith(color: SwipColors.onCameraInk),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SwipSpace.sm),
              Text(
                'Nothing is recorded or uploaded - the camera is used only to '
                'read the code in front of you.',
                style:
                    SwipType.bodyM.copyWith(color: SwipColors.onCameraInk.withValues(alpha: .72)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SwipSpace.xl),
              FilledButton.icon(
                onPressed: onAllow,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Allow camera'),
              ),
            ],
          ),
        ),
      );
}
