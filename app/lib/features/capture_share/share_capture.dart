import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/settings/home_market.dart';
import '../../core/theme/swip_tokens.dart';
import '../../data/models/capture_event.dart';
import '../../data/repositories/capture_repository.dart';
import '../../data/sources/capture_resolver.dart';
import '../../widgets/capture_sheet.dart';

/// `S-24` — share-to-SWIP. The answer to `F-41`.
///
/// ## Why this replaced Vector 7 as the plan
///
/// SWIP registered `upi://pay`, was installed, and still did not appear in
/// Swiggy's UPI list. Those checkouts build their list from an allowlist their
/// payment SDK ships, not by asking Android who can handle the intent — so
/// there is no registering our way onto it. See
/// `docs/20-FEEDBACK-ROUND-2.md`.
///
/// The share sheet is the one list nobody curates. Every checkout screen has a
/// copy or a share action, every Android app can be a share target, and no
/// merchant, PSP or SDK vendor gets a veto. It costs one extra tap and it works
/// everywhere — which beats a zero-tap path that works nowhere.
///
/// ## Two shapes
///
///   * **text** — a payment link, or a `upi://pay?…` string copied off a
///     checkout. Resolved by exactly the same [CaptureResolver] as a scan, so
///     the two can never describe the same merchant differently.
///   * **image** — a screenshot of a payment screen. The QR is read out of the
///     picture. This is the case where the merchant never exposes the string at
///     all, and it is the only route left when they do not.
class ShareCapture {
  static const _channel = MethodChannel('in.swip.app/nfc');

  /// What SWIP was shared, or null. Reading it clears it on the host side, so
  /// a rebuild cannot replay the same share as a second ledger row.
  static Future<({String kind, String value})?> consume() async {
    try {
      final map =
          await _channel.invokeMapMethod<String, dynamic>('consumeSharedPayload');
      if (map == null) return null;
      final kind = map['kind'] as String?;
      final value = map['value'] as String?;
      if (kind == null || value == null) return null;
      return (kind: kind, value: value);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null; // iOS, or a debug build without the host attached.
    }
  }
}

/// Watches for an incoming share and turns it into a capture.
///
/// Wraps the shell rather than living on a screen, because a share can arrive
/// while SWIP is on any tab, or cold-start it outright — the same reason
/// `IntentCaptureListener` sits where it does.
class ShareCaptureListener extends ConsumerStatefulWidget {
  const ShareCaptureListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareCaptureListener> createState() =>
      _ShareCaptureListenerState();
}

class _ShareCaptureListenerState extends ConsumerState<ShareCaptureListener>
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
    // A second share arrives through onNewIntent, which resumes us.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_handling) return;
    final shared = await ShareCapture.consume();
    if (shared == null || !mounted) return;

    _handling = true;
    try {
      final raw = shared.kind == 'image'
          ? await _readQrFromImage(shared.value)
          : shared.value;

      if (!mounted) return;

      if (raw == null) {
        await _noCodeInImage();
        return;
      }

      await _record(raw, fromImage: shared.kind == 'image');
    } finally {
      _handling = false;
    }
  }

  /// Read a QR out of a shared screenshot.
  ///
  /// A fresh controller per image, disposed straight after: this runs at most
  /// once per share and holding a scanner alive between them would keep the
  /// camera pipeline warm for nothing.
  Future<String?> _readQrFromImage(String path) async {
    final controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode, BarcodeFormat.dataMatrix],
    );
    try {
      final result = await controller.analyzeImage(path);
      final barcodes = result?.barcodes ?? const <Barcode>[];
      for (final b in barcodes) {
        final v = b.rawValue;
        if (v != null && v.trim().isNotEmpty) return v;
      }
      return null;
    } catch (_) {
      // A HEIC, a screenshot with no code in it, a corrupt stream. All the
      // same outcome to the person holding the phone.
      return null;
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _record(String raw, {required bool fromImage}) async {
    final resolved = CaptureResolver.resolve(raw);
    final repo = await ref.read(captureRepositoryProvider.future);

    final event = await repo.record(
      // Force the vector. The resolver would call a pasted UPI string a QR
      // scan, but this arrived through the share sheet and the ledger has to
      // be able to tell those apart — that distinction is the whole point of
      // `D-02`.
      vector: CaptureVector.link,
      mcc: resolved.mcc,
      merchantName: resolved.merchantName,
      merchantCity: resolved.merchantCity,
      countryCode: resolved.countryCode,
      merchantKey: resolved.merchantKey,
      amount: resolved.amount,
      currency: resolved.currency,
      terminalId: resolved.terminalId,
      acquirer: resolved.acquirer,
      rawPayload: raw,
    );

    ref.read(ledgerRevisionProvider.notifier).state++;
    if (!mounted) return;

    final home = ref.read(homeMarketProvider).valueOrNull;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SwipColors.surfaceRaised,
      builder: (_) => CaptureSheet(
        event: event,
        mcc: repo.lookup(event.mcc),
        sourceLabel: fromImage
            ? 'Shared screenshot · ${resolved.sourceLabel}'
            : 'Shared · ${resolved.sourceLabel}',
        rawPayload: raw,
        verdict: home?.verdictFor(resolved.countryCode,
            deviceCountry: event.placeCountry),
        payeeKind: resolved.payeeKind,
        tier: resolved.tier,
        details: {
          if (resolved.acquirer != null) 'Payment company': resolved.acquirer!,
          if (resolved.merchantHandle != null)
            'Pays to': resolved.merchantHandle!,
          if (resolved.merchantCity != null) 'City': resolved.merchantCity!,
          if (resolved.countryCode != null) 'Country': resolved.countryCode!,
          if (resolved.amount != null)
            'Amount': '${resolved.currency ?? ''} ${resolved.amount}'.trim(),
          'How it got here':
              fromImage ? 'You shared a screenshot' : 'You shared this to SWIP',
        },
      ),
    );
  }

  /// The screenshot had no readable code. Says what to do next rather than
  /// just failing — a share that goes nowhere is worse than no share target.
  Future<void> _noCodeInImage() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: SwipColors.surfaceRaised,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(SwipSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.image_not_supported_outlined,
                    size: 32, color: SwipColors.textTertiary),
                const SizedBox(height: SwipSpace.lg),
                Text('No payment code in that picture',
                    style: SwipType.titleM
                        .copyWith(color: SwipColors.textPrimary)),
                const SizedBox(height: SwipSpace.sm),
                Text(
                  'SWIP looked for a QR and did not find one. If the checkout '
                  'showed a list of payment apps rather than a code, use the '
                  'screen\'s "copy link" or "share" action instead and share '
                  'the text to SWIP.',
                  style: SwipType.bodyM
                      .copyWith(color: SwipColors.textSecondary),
                ),
                const SizedBox(height: SwipSpace.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => widget.child;
}
