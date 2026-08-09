import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme/swip_tokens.dart';
import '../data/models/capture_event.dart';
import '../data/models/mcc.dart';
import '../data/sources/payload_kind.dart';
import 'mcc_badge.dart';

/// The one capture sheet. Every vector ends here — QR, POS tap, pay-by-app
/// intent, link, manual.
///
/// Hierarchy is fixed and deliberate (`F-10`–`F-13`):
///
///   1. the MCC
///   2. what the MCC means
///   3. the merchant
///   4. everything else, below a rule, labelled with the source's own names
///
/// It replaces the two near-identical sheets that had grown in scan_page and
/// intent_capture. One screen means one place to fix copy, one place to add a
/// field, and no chance of the QR path and the tap path disagreeing about how
/// a capture is described.
class CaptureSheet extends StatelessWidget {
  const CaptureSheet({
    super.key,
    required this.event,
    required this.mcc,
    required this.sourceLabel,
    this.details = const {},
    this.rawPayload,
    this.onPrimary,
    this.primaryLabel = 'Done',
  });

  final CaptureEvent event;
  final Mcc? mcc;

  /// Human provenance — "UPI QR", "POS terminal", "Razorpay payment link".
  final String sourceLabel;

  /// `F-13`. Whatever the source actually gave us, keyed by **its own field
  /// name**, in the order it should be read. Not a fixed schema: a POS tap and
  /// a QR return different things and both are shown as they came.
  final Map<String, String> details;

  final String? rawPayload;
  final VoidCallback? onPrimary;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    final known = event.hasMcc;
    final explanation = rawPayload == null
        ? null
        : PayloadExplanation.of(rawPayload!, hasMcc: known);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.xl, SwipSpace.md, SwipSpace.xl, SwipSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── source badge, top right — F-17 ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    sourceLabel.toUpperCase(),
                    style: SwipType.labelS
                        .copyWith(color: SwipColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _Badge(text: explanation?.badge ?? _vectorBadge(event.vector)),
              ],
            ),
            const SizedBox(height: SwipSpace.lg),

            if (known) ...[
              // 1 ── the code
              _FoilCode(event.mcc!),
              const SizedBox(height: SwipSpace.xs),

              // 2 ── what it means
              Text(
                mcc?.displayName ?? 'Not in the offline table yet',
                style: SwipType.bodyL.copyWith(color: SwipColors.textPrimary),
              )
                  .animate()
                  .fadeIn(delay: 240.ms, duration: 320.ms)
                  .moveY(begin: 10, curve: SwipMotion.captureCurve),
            ] else ...[
              // No category — say what this is instead, in plain words.
              Text(
                explanation?.title ?? 'No category in this code',
                style: SwipType.titleM.copyWith(color: SwipColors.textPrimary),
              ),
              const SizedBox(height: SwipSpace.sm),
              Text(
                explanation?.body ??
                    'This code carried no category. SWIP will fill it in if '
                        'anyone captures this merchant another way.',
                style: SwipType.bodyM
                    .copyWith(color: SwipColors.textSecondary),
              ),
            ],

            // 3 ── the merchant
            if (event.merchantName != null) ...[
              const SizedBox(height: SwipSpace.md),
              Row(
                children: [
                  const Icon(Icons.storefront_outlined,
                      size: 16, color: SwipColors.textTertiary),
                  const SizedBox(width: SwipSpace.sm),
                  Expanded(
                    child: Text(
                      [event.merchantName, event.merchantCity]
                          .whereType<String>()
                          .join(' · '),
                      style: SwipType.titleS
                          .copyWith(color: SwipColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            if (known) ...[
              const SizedBox(height: SwipSpace.md),
              Row(children: [
                ConfidencePill(event.confidence),
                if (mcc != null && mcc!.publications.isNotEmpty) ...[
                  const SizedBox(width: SwipSpace.md),
                  Flexible(child: PublicationChips(mcc!.publications)),
                ],
              ]),
            ],

            // 4 ── everything else, under a rule, with the source's own labels
            if (details.isNotEmpty) ...[
              const SizedBox(height: SwipSpace.lg),
              const Divider(height: 1),
              const SizedBox(height: SwipSpace.md),
              for (final entry in details.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: SwipSpace.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 132,
                        child: Text(entry.key,
                            style: SwipType.bodyS
                                .copyWith(color: SwipColors.textTertiary)),
                      ),
                      Expanded(
                        child: Text(entry.value,
                            style: SwipType.bodyS
                                .copyWith(color: SwipColors.textSecondary)),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: SwipSpace.xl),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    onPrimary ?? () => Navigator.of(context).maybePop(),
                child: Text(primaryLabel),
              ),
            ),

            // F-18 — the quiet confirmation under the button.
            const SizedBox(height: SwipSpace.sm),
            Center(
              child: Text(
                known
                    ? 'Saved to your ledger'
                    : 'Saved to your ledger as uncategorised',
                style:
                    SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
              ),
            ),

            // F-23 — technical detail, available but never in the way.
            if (rawPayload != null) ...[
              const SizedBox(height: SwipSpace.xs),
              Center(
                child: TextButton(
                  onPressed: () => _showRaw(context, rawPayload!),
                  child: Text('View technical details',
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.textSecondary)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _vectorBadge(CaptureVector v) => switch (v) {
        CaptureVector.qr => 'QR',
        CaptureVector.nfc => 'POS',
        CaptureVector.intent => 'APP',
        CaptureVector.link => 'LINK',
        CaptureVector.probe => 'PROBE',
        CaptureVector.manual => 'YOU',
        CaptureVector.graph => 'KNOWN',
      };

  static void _showRaw(BuildContext context, String raw) {
    showModalBottomSheet<void>(
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
              Text('Exactly what was read',
                  style: SwipType.titleS
                      .copyWith(color: SwipColors.textPrimary)),
              const SizedBox(height: SwipSpace.sm),
              Text(
                'This is the untouched payload. SWIP shows its working so you '
                'never have to take a category on trust.',
                style: SwipType.bodyS
                    .copyWith(color: SwipColors.textSecondary),
              ),
              const SizedBox(height: SwipSpace.lg),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(SwipSpace.md),
                decoration: BoxDecoration(
                  color: SwipColors.surfaceRaised2,
                  borderRadius: SwipRadius.inputAll,
                ),
                child: SingleChildScrollView(
                  child: SelectableText(raw, style: SwipType.mono
                      .copyWith(color: SwipColors.textSecondary)),
                ),
              ),
              const SizedBox(height: SwipSpace.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: raw));
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The four digits, gold, landing one by one under a single foil sweep.
class _FoilCode extends StatelessWidget {
  const _FoilCode(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    final digits = code.split('');
    return ShaderMask(
      // One shader across the whole run — per-glyph gradients shatter the foil.
      shaderCallback: (b) => SwipGradients.foil.createShader(b),
      blendMode: BlendMode.srcIn,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < digits.length; i++)
            Text(digits[i],
                    style: SwipType.mcc.copyWith(
                        fontSize: 60,
                        height: 64 / 60,
                        color: SwipColors.gold500))
                .animate()
                .fadeIn(delay: (i * 50).ms, duration: 240.ms)
                .moveY(
                    begin: 24,
                    delay: (i * 50).ms,
                    duration: SwipMotion.capture,
                    curve: SwipMotion.captureCurve),
        ],
      ),
    ).animate().shimmer(
        delay: 320.ms,
        duration: SwipMotion.foilSweep,
        color: SwipColors.gold100);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: SwipSpace.sm, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: SwipRadius.chipAll,
          border: Border.all(color: SwipColors.hairline),
        ),
        child: Text(text,
            style: SwipType.labelS
                .copyWith(color: SwipColors.textSecondary)),
      );
}
