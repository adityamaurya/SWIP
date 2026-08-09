import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/onboarding/primers.dart';
import '../../core/theme/swip_tokens.dart';
import '../../data/models/capture_event.dart';
import '../../data/models/mcc.dart';
import '../../data/repositories/capture_repository.dart';
import '../../data/sources/capture_resolver.dart';
import '../../widgets/mcc_badge.dart';

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
      builder: (_) => CaptureResultSheet(
        event: event,
        mcc: repo.lookup(event.mcc),
        sourceLabel: resolved.sourceLabel,
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

/// The reveal.
///
/// The signature moment of the product: the digits land on a spring and a
/// specular band rakes across them once. It fires here, on the splash, and on a
/// coin transfer — nowhere else. Using it anywhere else destroys it.
class CaptureResultSheet extends StatelessWidget {
  const CaptureResultSheet({
    super.key,
    required this.event,
    required this.mcc,
    required this.sourceLabel,
  });

  final CaptureEvent event;
  final Mcc? mcc;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final known = event.hasMcc;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.xl, SwipSpace.sm, SwipSpace.xl, SwipSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sourceLabel.toUpperCase(),
                style: SwipType.labelS
                    .copyWith(color: SwipColors.textTertiary)),
            const SizedBox(height: SwipSpace.md),

            if (known)
              _FoilDigits(event.mcc!)
            else
              Text('No category',
                      style: SwipType.titleL
                          .copyWith(color: SwipColors.textSecondary))
                  .animate()
                  .fadeIn(duration: 300.ms),

            const SizedBox(height: SwipSpace.xs),

            Text(
              mcc?.displayName ??
                  (known
                      ? 'Not in the offline table yet'
                      : 'This code carried no category. SWIP will answer from '
                          'the merchant graph once anyone captures it another way.'),
              style: SwipType.bodyL.copyWith(color: SwipColors.textPrimary),
            )
                .animate()
                .fadeIn(delay: 260.ms, duration: 340.ms)
                .moveY(begin: 10, curve: SwipMotion.captureCurve),

            const SizedBox(height: SwipSpace.md),

            Row(children: [
              ConfidencePill(event.confidence),
              if (event.merchantName != null) ...[
                const SizedBox(width: SwipSpace.md),
                Flexible(
                  child: Text(event.merchantName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.textSecondary)),
                ),
              ],
            ])
                .animate()
                .fadeIn(delay: 340.ms, duration: 320.ms),

            if (mcc != null && mcc!.publications.isNotEmpty) ...[
              const SizedBox(height: SwipSpace.md),
              PublicationChips(mcc!.publications)
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 320.ms),
            ],

            const SizedBox(height: SwipSpace.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Saved to ledger'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four digits, gold, landing one after another with a foil rake across them.
class _FoilDigits extends StatelessWidget {
  const _FoilDigits(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    final digits = code.split('');

    return ShaderMask(
      // One shader across the whole run. Per-glyph gradients shatter the foil
      // into unrelated shards, which is the most common way a foil treatment
      // goes wrong — the same bug that hit the SVG wordmark.
      shaderCallback: (bounds) => SwipGradients.foil.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < digits.length; i++)
            Text(digits[i],
                    style: SwipType.mcc.copyWith(
                      fontSize: 64,
                      height: 68 / 64,
                      color: SwipColors.gold500,
                    ))
                .animate()
                .fadeIn(delay: (i * 50).ms, duration: 260.ms)
                .moveY(
                  begin: 26,
                  delay: (i * 50).ms,
                  duration: SwipMotion.capture,
                  curve: SwipMotion.captureCurve,
                )
                .scaleXY(
                  begin: .86,
                  delay: (i * 50).ms,
                  duration: SwipMotion.capture,
                  curve: SwipMotion.captureCurve,
                ),
        ],
      ),
    )
        .animate()
        .shimmer(
          delay: 340.ms,
          duration: SwipMotion.foilSweep,
          color: SwipColors.gold100,
        );
  }
}
