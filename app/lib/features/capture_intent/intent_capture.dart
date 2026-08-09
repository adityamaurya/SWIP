import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/swip_tokens.dart';
import '../../data/models/capture_event.dart';
import '../../data/repositories/capture_repository.dart';
import '../../data/sources/capture_resolver.dart';
import '../../widgets/capture_sheet.dart';

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

/// Watches for an incoming payment intent and shows the [CaptureSheet].
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
        builder: (ctx) => CaptureSheet(
          event: event,
          mcc: repo.lookup(event.mcc),
          sourceLabel: 'Pay-by-app · ${resolved.sourceLabel}',
          rawPayload: uri,
          // Without this, the payload sniffer would call a Swiggy or PVR
          // checkout "a personal UPI code, not a shop" — it is plainly a shop,
          // it just did not put a category in the intent.
          noCategoryTitle: 'This checkout did not send a category',
          noCategoryBody:
              'The app you are paying from left the category field out of the '
              'handover. SWIP has recorded the merchant, so scanning their QR '
              'or tapping their terminal once will fill this in everywhere.',
          primaryLabel: 'Continue to pay',
          onPrimary: () async {
            Navigator.of(ctx).pop();
            await IntentCapture.forward(uri);
          },
          details: {
            if (resolved.amount != null)
              'Amount': '${resolved.currency ?? ''} ${resolved.amount}'.trim(),
            if (resolved.merchantKey != null)
              'Merchant key': resolved.merchantKey!,
            'SWIP\'s part': 'Read the category only — no payment is made here',
          },
        ),
      );
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
