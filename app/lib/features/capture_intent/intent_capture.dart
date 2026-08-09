import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/swip_tokens.dart';
import '../../data/models/capture_event.dart';
import '../../data/repositories/capture_repository.dart';
import '../../data/sources/capture_resolver.dart';
import '../../widgets/mcc_badge.dart';

/// Vector 7 — the pay-by-app intent.
///
/// NPCI requires merchants to offer "Pay by any UPI App" on Android, which
/// fires an **implicit** intent. Android lists everyone who can handle it, and
/// that list is the payment sheet at checkout. The intent carries `mc` — the
/// merchant category code — before any money moves.
///
/// SWIP registers as one of those handlers to **read that field and step out of
/// the way**. It renders no payment UI, holds no funds, and is not a PSP. The
/// user picks SWIP, sees the category for about a second, and is handed on to
/// the app they actually pay with.
///
/// See `docs/18-INTENT-CAPTURE-AND-TAP-TO-PHONE.md`.
class IntentCapture {
  static const _channel = MethodChannel('in.swip.app/nfc');

  /// The `upi://pay?...` SWIP was launched with, or null. Reading it clears it,
  /// so a rebuild cannot replay the same capture.
  static Future<String?> consume() async {
    try {
      return await _channel.invokeMethod<String>('consumeUpiIntent');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null; // iOS, or a debug build without the host attached.
    }
  }

  /// Hand the payment on to a real UPI app. SWIP excludes itself from the
  /// chooser, so this cannot loop back.
  static Future<bool> forward(String uri) async {
    try {
      final ok = await _channel
          .invokeMethod<bool>('forwardUpiIntent', {'uri': uri});
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Watches for an incoming payment intent and shows [IntentCaptureSheet].
///
/// Wraps the shell rather than living on a screen, because a checkout hand-off
/// can arrive while SWIP is on any tab, or cold-start it outright.
class IntentCaptureListener extends ConsumerStatefulWidget {
  const IntentCaptureListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IntentCaptureListener> createState() =>
      _IntentCaptureListenerState();
}

class _IntentCaptureListenerState extends ConsumerState<IntentCaptureListener>
    with WidgetsBindingObserver {
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A second checkout arrives through onNewIntent, which resumes us.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_handling) return;
    final uri = await IntentCapture.consume();
    if (uri == null || !mounted) return;

    _handling = true;
    try {
      final resolved = CaptureResolver.resolve(uri);
      final repo = await ref.read(captureRepositoryProvider.future);

      final event = await repo.record(
        // Force the vector: the resolver sees a UPI payload and would call it
        // a QR scan, but this arrived from a merchant checkout and the ledger
        // must be able to tell those apart.
        vector: CaptureVector.intent,
        mcc: resolved.mcc,
        merchantName: resolved.merchantName,
        merchantCity: resolved.merchantCity,
        countryCode: resolved.countryCode,
        merchantKey: resolved.merchantKey,
        amount: resolved.amount,
        currency: resolved.currency,
        rawPayload: uri,
      );

      ref.read(ledgerRevisionProvider.notifier).state++;

      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: SwipColors.surfaceRaised,
        builder: (_) => IntentCaptureSheet(
          event: event,
          categoryName: repo.lookup(event.mcc)?.displayName,
          uri: uri,
        ),
      );
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The hand-off sheet.
///
/// Deliberately spare and deliberately fast. Every element here is either the
/// category or a statement that SWIP is not taking the payment — anything else
/// would make a pass-through feel like an interception.
class IntentCaptureSheet extends StatelessWidget {
  const IntentCaptureSheet({
    super.key,
    required this.event,
    required this.categoryName,
    required this.uri,
  });

  final CaptureEvent event;
  final String? categoryName;
  final String uri;

  @override
  Widget build(BuildContext context) {
    final known = event.hasMcc;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.xl, SwipSpace.xl, SwipSpace.xl, SwipSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.merchantName?.toUpperCase() ?? 'THIS MERCHANT',
              style: SwipType.labelS.copyWith(color: SwipColors.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: SwipSpace.md),

            if (known)
              ShaderMask(
                shaderCallback: (b) => SwipGradients.foil.createShader(b),
                blendMode: BlendMode.srcIn,
                child: Text(
                  event.mcc!,
                  style: SwipType.mcc.copyWith(
                    fontSize: 56,
                    height: 60 / 56,
                    color: SwipColors.gold500,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 240.ms)
                  .moveY(begin: 18, curve: SwipMotion.captureCurve)
                  .shimmer(delay: 260.ms, duration: 700.ms,
                      color: SwipColors.gold100)
            else
              Text('No category in this request',
                  style: SwipType.titleM
                      .copyWith(color: SwipColors.textSecondary)),

            if (categoryName != null) ...[
              const SizedBox(height: SwipSpace.xs),
              Text(categoryName!,
                  style: SwipType.bodyL
                      .copyWith(color: SwipColors.textPrimary)),
            ],

            const SizedBox(height: SwipSpace.md),
            Row(children: [
              ConfidencePill(event.confidence),
              if (event.amount != null) ...[
                const SizedBox(width: SwipSpace.md),
                Text(
                  '${event.currency ?? ''} ${event.amount!.toStringAsFixed(2)}',
                  style: SwipType.bodyM
                      .copyWith(color: SwipColors.textSecondary),
                ),
              ],
            ]),

            const SizedBox(height: SwipSpace.xl),

            // The disclosure. Not fine print — it is the reason this screen is
            // allowed to exist between a merchant and a wallet.
            Container(
              padding: const EdgeInsets.all(SwipSpace.md),
              decoration: BoxDecoration(
                color: SwipColors.infoFill,
                borderRadius: SwipRadius.inputAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: SwipColors.infoOnInk),
                  const SizedBox(width: SwipSpace.sm),
                  Expanded(
                    child: Text(
                      'SWIP does not take payments. Saved to your ledger — '
                      'now choose the app you want to pay with.',
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.infoOnInk),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: SwipSpace.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await IntentCapture.forward(uri);
                },
                child: const Text('Continue to pay'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
