import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/onboarding/primers.dart';
import '../../core/settings/home_market.dart';
import '../../core/theme/swip_tokens.dart';
import '../../data/repositories/capture_repository.dart';
import '../../data/sources/capture_resolver.dart';
import '../../widgets/capture_sheet.dart';

/// `S-02` — Scan a QR.
///
/// Full-bleed camera under an Ink scrim, with a gold reticle. Works on any
/// merchant-presented QR anywhere in the world; see [CaptureResolver] for the
/// resolution order and for why an honest "Unknown" is a correct outcome.
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
    if (running != _running || refused != _refused) {
      setState(() {
        _running = running;
        _refused = refused;
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SwipColors.surfaceRaised,
      builder: (_) => CaptureSheet(
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
      ),
    );

    if (!mounted) return;
    setState(() => _handling = false);
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwipColors.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Scan a QR'),
        actions: [
          IconButton(
            tooltip: 'Torch',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
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
            child: Container(color: SwipColors.bg.withValues(alpha: .55)),
          ),

          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: SwipColors.gold500, width: 2),
                borderRadius: BorderRadius.circular(28),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fadeIn(duration: 400.ms)
                .then()
                .scaleXY(
                    begin: 1, end: 1.03, duration: 1400.ms, curve: Curves.easeInOut),
          ),

          Positioned(
            left: SwipSpace.xl,
            right: SwipSpace.xl,
            bottom: SwipSpace.giant,
            child: Text(
              'Point at any payment QR - UPI, BharatQR, PIX, QRIS,\n'
              'PayNow, PromptPay and thirty more.',
              textAlign: TextAlign.center,
              style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
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
              const Icon(Icons.no_photography_outlined,
                  size: 40, color: SwipColors.textTertiary),
              const SizedBox(height: SwipSpace.lg),
              Text(
                'SWIP needs the camera to read a QR',
                style: SwipType.titleS.copyWith(color: SwipColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SwipSpace.sm),
              Text(
                'Nothing is recorded or uploaded - the camera is used only to '
                'read the code in front of you.',
                style:
                    SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
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
