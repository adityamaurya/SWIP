import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/onboarding/primers.dart';
import '../../core/settings/home_market.dart';
import '../../core/theme/swip_tokens.dart';
import '../../data/repositories/capture_repository.dart';
import '../../data/sources/capture_resolver.dart';
import '../../widgets/capture_sheet.dart';

/// `S-08` — Check a payment link. Vector 3, `F-09`.
///
/// Paste a Razorpay/Stripe/PayPal link and SWIP works out who the merchant is.
///
/// **This vector can only ever infer.** An MCC is assigned by the acquiring
/// bank when a merchant is onboarded; it is not encoded anywhere in a URL. So
/// this screen never returns "Verified" — it identifies the PSP and merchant,
/// which is enough to key the merchant graph, and the graph answers properly
/// the second time anyone meets that merchant by any vector.
class LinkPage extends ConsumerStatefulWidget {
  const LinkPage({super.key});

  @override
  ConsumerState<LinkPage> createState() => _LinkPageState();
}

class _LinkPageState extends ConsumerState<LinkPage> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showPrimer(context, ref, SwipPrimer.checkLink);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _controller.text = text;
      setState(() {});
    }
  }

  Future<void> _check() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty || _busy) return;
    setState(() => _busy = true);

    try {
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
        acquirer: resolved.acquirer,
        rawPayload: raw,
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
          details: {
            if (resolved.acquirer != null)
              'Payment provider': resolved.acquirer!,
            if (resolved.merchantKey != null)
              'Merchant key': resolved.merchantKey!,
            if (!resolved.hasMcc)
              'Why no category':
                  'A category is set by the merchant\'s bank, not written into '
                      'the web address. SWIP will fill this in once this '
                      'merchant is captured by QR or by tapping a terminal.',
          },
        ),
      );

      if (mounted) _controller.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Check a link')),
        body: Padding(
          padding: const EdgeInsets.all(SwipSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste a payment link',
                style: SwipType.titleM.copyWith(color: SwipColors.textPrimary),
              ),
              const SizedBox(height: SwipSpace.sm),
              Text(
                'Razorpay, Stripe, PayPal, Cashfree, Paytm and the rest.',
                style:
                    SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
              ),
              const SizedBox(height: SwipSpace.xl),

              TextField(
                controller: _controller,
                autocorrect: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _check(),
                onChanged: (_) => setState(() {}),
                style:
                    SwipType.bodyM.copyWith(color: SwipColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'https://rzp.io/l/…',
                  suffixIcon: IconButton(
                    tooltip: 'Paste',
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded, size: 20),
                  ),
                ),
              ),

              const SizedBox(height: SwipSpace.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _controller.text.trim().isEmpty || _busy ? null : _check,
                  child: Text(_busy ? 'Checking…' : 'Check this link'),
                ),
              ),

              const SizedBox(height: SwipSpace.xxl),
              Container(
                padding: const EdgeInsets.all(SwipSpace.md),
                decoration: BoxDecoration(
                  color: SwipColors.warningFill,
                  borderRadius: SwipRadius.inputAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: SwipColors.warningOnInk),
                    const SizedBox(width: SwipSpace.sm),
                    Expanded(
                      child: Text(
                        'Links are the one place SWIP has to guess. A category '
                        'is set by the merchant\'s bank and is never written '
                        'into the web address — so these are never marked '
                        'Verified.',
                        style: SwipType.bodyS
                            .copyWith(color: SwipColors.warningOnInk),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
