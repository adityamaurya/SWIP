import 'package:flutter/material.dart';
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
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode, BarcodeFormat.dataMatrix],
  );

  bool _handling = false;

  @override
  void initState() {
    super.initState();
    // The explanation arrives ahead of the camera permission dialog, not on
    // top of it — a permission prompt with no context is how apps get denied.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showPrimer(context, ref, SwipPrimer.scanQr);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
    await _controller.start();
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
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => _CameraError(error: error),
          ),

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
              'Point at any payment QR — UPI, BharatQR, PIX, QRIS,\n'
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
  const _CameraError({required this.error});
  final MobileScannerException error;

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
                'Allow camera access in your phone settings, then come back to '
                'this screen. Nothing is recorded or uploaded — the camera is '
                'used only to read the code in front of you.',
                style:
                    SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
